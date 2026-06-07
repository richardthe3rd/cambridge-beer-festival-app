import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preference_keys.dart';
import '../models/models.dart';

/// Abstraction over personal-data persistence ([UserDrinkState]).
///
/// All access to the user's per-drink records goes through this interface, so
/// the backend is a constructor swap: today a [SharedPreferencesUserDataStore]
/// (local-first), later a synced store (vision Phase 3) with the local store as
/// the offline cache. It also lets personal data be enumerated for a festival
/// ([readAll]) without the catalogue being loaded.
abstract class UserDataStore {
  /// The stored record for a drink, or null if none exists.
  UserDrinkState? read(String festivalId, String drinkId);

  /// Persist a record, or remove the entry entirely when it is empty.
  Future<void> write(String festivalId, String drinkId, UserDrinkState state);

  /// Remove a drink's record.
  Future<void> remove(String festivalId, String drinkId);

  /// All records for a festival, keyed by drink ID.
  Map<String, UserDrinkState> readAll(String festivalId);

  /// Clear every record for a festival.
  Future<void> clearFestival(String festivalId);
}

/// [SharedPreferences]-backed [UserDataStore].
///
/// One structured JSON entry per drink-per-festival, replacing the three
/// separate key schemes previously hand-rolled by `FavoritesService`,
/// `RatingsService`, and `TastingLogService`. Empty records ([UserDrinkState]
/// `.isEmpty`) are pruned so they leave no key behind.
///
/// Each persisted payload carries a [schemaKey] version. Reads route every
/// payload through [migrate] — the single place future user-data format
/// changes are handled — before deserialising, so a stored record can always
/// be upgraded to the current shape.
class SharedPreferencesUserDataStore implements UserDataStore {
  static const String _prefix = PreferenceKeys.userStatePrefix;

  /// JSON key holding the payload's schema version.
  static const String schemaKey = 'version';

  /// The schema version written by this build.
  static const int currentSchemaVersion = 1;

  final SharedPreferences _prefs;

  SharedPreferencesUserDataStore(this._prefs);

  String _key(String festivalId, String drinkId) =>
      '$_prefix${festivalId}_$drinkId';

  String _festivalPrefix(String festivalId) => '$_prefix${festivalId}_';

  @override
  UserDrinkState? read(String festivalId, String drinkId) {
    return _decode(_prefs.getString(_key(festivalId, drinkId)));
  }

  @override
  Future<void> write(
    String festivalId,
    String drinkId,
    UserDrinkState state,
  ) async {
    final key = _key(festivalId, drinkId);
    if (state.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final payload = state.toJson()..[schemaKey] = currentSchemaVersion;
    await _prefs.setString(key, jsonEncode(payload));
  }

  @override
  Future<void> remove(String festivalId, String drinkId) async {
    await _prefs.remove(_key(festivalId, drinkId));
  }

  @override
  Map<String, UserDrinkState> readAll(String festivalId) {
    final prefix = _festivalPrefix(festivalId);
    final result = <String, UserDrinkState>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final state = _decode(_prefs.getString(key));
      if (state != null) result[key.substring(prefix.length)] = state;
    }
    return result;
  }

  @override
  Future<void> clearFestival(String festivalId) async {
    final prefix = _festivalPrefix(festivalId);
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// One-time migration of the pre-#391 per-service key schemes into unified
  /// records, then deletion of the old keys.
  ///
  /// Folds `favorites_{festivalId}` (StringList → wantToTry),
  /// `ratings_{festivalId}_{drinkId}` (int → rating) and
  /// `tasting_log_{festivalId}|{drinkId}` (int millis → a tasting event) into
  /// the matching `user_state_*` record, merging with any record already there
  /// rather than overwriting. Idempotent: a persisted
  /// [PreferenceKeys.legacyMigrationComplete] flag short-circuits the method
  /// on every launch after the first successful run, so no key scan occurs.
  Future<void> migrateLegacyData() async {
    if (_prefs.getBool(PreferenceKeys.legacyMigrationComplete) == true) return;

    const favKey = PreferenceKeys.favoritesLegacy;
    const ratingsKey = PreferenceKeys.ratingsLegacy;
    const tastingKey = PreferenceKeys.tastingLogLegacyPrefix;

    final legacyKeys = <String>[];
    final favourites = <String, Set<String>>{}; // festivalId -> drink IDs
    final ratings = <(String, String), int>{}; // (festival, drink) -> rating
    final tastings = <(String, String), int>{}; // (festival, drink) -> millis

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${favKey}_')) {
        final festivalId = key.substring(favKey.length + 1);
        favourites[festivalId] = (_prefs.getStringList(key) ?? const [])
            .toSet();
        legacyKeys.add(key);
      } else if (key.startsWith('${ratingsKey}_')) {
        final rest = key.substring(ratingsKey.length + 1);
        final sep = rest.indexOf('_');
        if (sep <= 0) continue;
        final value = _prefs.getInt(key);
        if (value != null) {
          ratings[(rest.substring(0, sep), rest.substring(sep + 1))] = value;
        }
        legacyKeys.add(key);
      } else if (key.startsWith(tastingKey)) {
        final rest = key.substring(tastingKey.length);
        final sep = rest.indexOf('|');
        if (sep <= 0) continue;
        final value = _prefs.getInt(key);
        if (value != null) {
          tastings[(rest.substring(0, sep), rest.substring(sep + 1))] = value;
        }
        legacyKeys.add(key);
      }
    }

    if (legacyKeys.isNotEmpty) {
      final touched = <(String, String)>{
        for (final entry in favourites.entries)
          for (final drinkId in entry.value) (entry.key, drinkId),
        ...ratings.keys,
        ...tastings.keys,
      };

      for (final (festivalId, drinkId) in touched) {
        final existing = read(festivalId, drinkId) ?? UserDrinkState.initial();
        final millis = tastings[(festivalId, drinkId)];
        final merged = existing.copyWith(
          wantToTry:
              existing.wantToTry ||
              (favourites[festivalId]?.contains(drinkId) ?? false),
          rating: existing.rating ?? ratings[(festivalId, drinkId)],
          // Only seed a tasting event when the new record has none, so
          // re-running can't duplicate events.
          tastingEvents: millis != null && existing.tastingEvents.isEmpty
              ? [DateTime.fromMillisecondsSinceEpoch(millis)]
              : existing.tastingEvents,
          updatedAt: DateTime.now(),
        );
        await write(festivalId, drinkId, merged);
      }

      for (final key in legacyKeys) {
        await _prefs.remove(key);
      }
    }

    await _prefs.setBool(PreferenceKeys.legacyMigrationComplete, true);
  }

  /// Upgrade a raw persisted payload to the current schema, then deserialise.
  ///
  /// The single point every user-data format change is routed through. A
  /// corrupt or unparseable entry is treated as absent rather than crashing
  /// the load.
  UserDrinkState? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserDrinkState.fromJson(migrate(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Pure upgrade step from any stored schema version to the current one.
  ///
  /// Kept static and side-effect free so it can be unit-tested directly. A
  /// missing version is treated as v1 (the first shipped format). Add a
  /// `if (version < N)` branch here for each future format change — never
  /// migrate inline at a call site.
  @visibleForTesting
  static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
    final version = (raw[schemaKey] as num?)?.toInt() ?? 1;
    // Fail safe in release too (an assert would be stripped): a payload newer
    // than this build can't be safely down-converted, so reject it rather than
    // mis-parse. _decode catches this and treats the record as absent, leaving
    // the stored data untouched for a future build that understands it.
    if (version > currentSchemaVersion) {
      throw FormatException(
        'Stored user-data schema v$version is newer than this build '
        '(v$currentSchemaVersion); cannot safely downgrade.',
      );
    }
    // v1 is the current schema; no transforms yet. Future versions slot in
    // here, each upgrading `data` one step.
    return raw;
  }
}
