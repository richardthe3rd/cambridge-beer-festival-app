import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/preference_keys.dart';
import '../models/models.dart';

/// Abstraction over personal-data persistence.
///
/// My Festival is a **timeline of [LogEntry] check-ins** (the diary) plus a
/// per-drink `wantToTry` intent (the plan). Entries are the storage unit
/// (ADR 0006); per-drink [UserDrinkState] views are **derived** from a drink's
/// tasting entries so existing consumers stay unchanged.
///
/// All access goes through this interface, so the backend is a constructor
/// swap: today a [SharedPreferencesUserDataStore] (local-first), later a synced
/// store (vision Phase 3) with the local store as the offline cache.
abstract class UserDataStore {
  /// The derived per-drink view for a drink, or null when the drink has no
  /// tasting entries and is not want-to-try.
  UserDrinkState? read(String festivalId, String drinkId);

  /// All derived per-drink views for a festival, keyed by drink ID. Drinks with
  /// no signal are absent.
  Map<String, UserDrinkState> readAll(String festivalId);

  /// Every stored log entry for a festival (the diary timeline, unordered).
  List<LogEntry> readEntries(String festivalId);

  /// Persist a single entry (create or edit — keyed by its stable id).
  Future<void> writeEntry(String festivalId, LogEntry entry);

  /// Remove a single entry by id.
  Future<void> removeEntry(String festivalId, String entryId);

  /// The set of drink IDs the user has flagged as "want to try" for a festival.
  Set<String> readWantToTry(String festivalId);

  /// Add or remove a drink from the festival's want-to-try set.
  Future<void> setWantToTry(
    String festivalId,
    String drinkId, {
    required bool value,
  });

  /// Clear every entry and the want-to-try set for a festival.
  Future<void> clearFestival(String festivalId);
}

/// [SharedPreferences]-backed [UserDataStore] (v2 LogEntry model, ADR 0006).
///
/// Storage layout:
/// - One JSON record per entry under `log_entry_{festivalId}_{id}`.
/// - One `StringList` per festival under `want_to_try_{festivalId}` (present
///   only while non-empty).
///
/// Each entry payload carries a [schemaKey] version. A payload newer than this
/// build is rejected on read (rollback fail-safe) and left untouched on disk.
/// The one-time v1 → v2 migration is [migrateToLogEntries]; the pre-#391 →
/// v1 fold is [migrateLegacyData].
class SharedPreferencesUserDataStore implements UserDataStore {
  /// Legacy v1 per-drink blob prefix (`user_state_{festivalId}_{drinkId}`).
  /// Read-only from v2: consumed and deleted by [migrateToLogEntries].
  static const String _legacyPrefix = PreferenceKeys.userStatePrefix;
  static const String _entryPrefix = PreferenceKeys.logEntryPrefix;
  static const String _wantToTryPrefix = PreferenceKeys.wantToTryPrefix;

  /// JSON key holding an entry payload's schema version.
  static const String schemaKey = 'version';

  /// The schema version written by this build.
  static const int currentSchemaVersion = 2;

  /// Deterministic namespace for migration-generated entry ids (see
  /// [_migrationEntryId]).
  static const Uuid _uuid = Uuid();

  final SharedPreferences _prefs;

  SharedPreferencesUserDataStore(this._prefs);

  String _entryFestivalPrefix(String festivalId) =>
      '$_entryPrefix${festivalId}_';

  String _entryKey(String festivalId, String id) =>
      '${_entryFestivalPrefix(festivalId)}$id';

  String _wantToTryKey(String festivalId) => '$_wantToTryPrefix$festivalId';

  // --- Entries (the diary) ---

  @override
  List<LogEntry> readEntries(String festivalId) {
    final prefix = _entryFestivalPrefix(festivalId);
    final result = <LogEntry>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final entry = _decodeEntry(_prefs.getString(key));
      if (entry != null) result.add(entry);
    }
    return result;
  }

  @override
  Future<void> writeEntry(String festivalId, LogEntry entry) async {
    final payload = entry.toJson()..[schemaKey] = currentSchemaVersion;
    await _prefs.setString(
      _entryKey(festivalId, entry.id),
      jsonEncode(payload),
    );
  }

  @override
  Future<void> removeEntry(String festivalId, String entryId) async {
    await _prefs.remove(_entryKey(festivalId, entryId));
  }

  // --- Want-to-try (the plan) ---

  @override
  Set<String> readWantToTry(String festivalId) =>
      (_prefs.getStringList(_wantToTryKey(festivalId)) ?? const <String>[])
          .toSet();

  @override
  Future<void> setWantToTry(
    String festivalId,
    String drinkId, {
    required bool value,
  }) async {
    final key = _wantToTryKey(festivalId);
    final set = (_prefs.getStringList(key) ?? const <String>[]).toSet();
    final changed = value ? set.add(drinkId) : set.remove(drinkId);
    if (!changed) return;
    // Present only while non-empty, so the key leaves no trace once empty.
    if (set.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setStringList(key, set.toList());
    }
  }

  // --- Derived per-drink views ---

  @override
  UserDrinkState? read(String festivalId, String drinkId) {
    final entries = readEntries(
      festivalId,
    ).where((e) => e.drinkId == drinkId).toList();
    final wantToTry = readWantToTry(festivalId).contains(drinkId);
    return _derive(entries, wantToTry: wantToTry);
  }

  @override
  Map<String, UserDrinkState> readAll(String festivalId) {
    // Single pass builds the memoised drinkId → entries index, keeping per-drink
    // derivations off the O(drinks × entries) path (ADR 0006).
    final byDrink = <String, List<LogEntry>>{};
    for (final entry in readEntries(festivalId)) {
      final drinkId = entry.drinkId;
      if (drinkId == null) continue; // non-drink entries have no per-drink view
      (byDrink[drinkId] ??= <LogEntry>[]).add(entry);
    }
    final wantToTry = readWantToTry(festivalId);

    final result = <String, UserDrinkState>{};
    for (final drinkEntry in byDrink.entries) {
      final state = _derive(
        drinkEntry.value,
        wantToTry: wantToTry.contains(drinkEntry.key),
      );
      if (state != null) result[drinkEntry.key] = state;
    }
    // Want-to-try drinks with no tasting entries still need a view.
    for (final drinkId in wantToTry) {
      if (result.containsKey(drinkId)) continue;
      final state = _derive(const <LogEntry>[], wantToTry: true);
      if (state != null) result[drinkId] = state;
    }
    return result;
  }

  /// Derives a drink's aggregate [UserDrinkState] from its tasting [entries]
  /// and want-to-try flag. Rating/notes/photos come from the **most recent**
  /// tasting ("your latest"); pours = tasting count (ADR 0006). Returns null
  /// when there is no signal at all.
  static UserDrinkState? _derive(
    List<LogEntry> entries, {
    required bool wantToTry,
  }) {
    if (entries.isEmpty && !wantToTry) return null;
    final sorted = [...entries]..sort((a, b) => a.when.compareTo(b.when));
    final latest = sorted.isEmpty ? null : sorted.last;
    final createdAt = sorted.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : sorted.first.when;
    final updatedAt = sorted.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : sorted.last.when;
    final state = UserDrinkState(
      wantToTry: wantToTry,
      tastingEvents: sorted.map((e) => e.when).toList(),
      rating: latest?.rating,
      notes: latest?.note,
      photoIds: latest?.photoIds ?? const [],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    return state.isEmpty ? null : state;
  }

  @override
  Future<void> clearFestival(String festivalId) async {
    final entryPrefix = _entryFestivalPrefix(festivalId);
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(entryPrefix))
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_wantToTryKey(festivalId));
  }

  /// Decodes a stored entry payload, upgrading/guarding by schema version.
  ///
  /// A corrupt/unparseable payload, or one newer than this build (a rollback
  /// meeting future-schema data), is treated as absent — the bytes on disk are
  /// left untouched for a build that understands them.
  LogEntry? _decodeEntry(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final version =
          (decoded[schemaKey] as num?)?.toInt() ?? currentSchemaVersion;
      if (version > currentSchemaVersion) return null; // rollback fail-safe
      return LogEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // --- Legacy (pre-#391) → v1 blob migration ---

  /// One-time migration of the pre-#391 per-service key schemes into unified
  /// v1 blobs (`user_state_*`), then deletion of the old keys.
  ///
  /// Folds `favorites_{festivalId}` (StringList → wantToTry),
  /// `ratings_{festivalId}_{drinkId}` (int → rating) and
  /// `tasting_log_{festivalId}|{drinkId}` (int millis → a tasting event) into
  /// the matching `user_state_*` blob, merging with any blob already there
  /// rather than overwriting. Idempotent: a persisted
  /// [PreferenceKeys.legacyMigrationComplete] flag short-circuits the method on
  /// every launch after the first successful run.
  ///
  /// Runs **before** [migrateToLogEntries] in [BeerProvider.initialize]: the
  /// blobs it produces are then folded into the v2 LogEntry model.
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
        final existing =
            _readV1Blob(festivalId, drinkId) ?? UserDrinkState.initial();
        final millis = tastings[(festivalId, drinkId)];
        final merged = existing.copyWith(
          wantToTry:
              existing.wantToTry ||
              (favourites[festivalId]?.contains(drinkId) ?? false),
          rating: existing.rating ?? ratings[(festivalId, drinkId)],
          // Only seed a tasting event when the new blob has none, so
          // re-running can't duplicate events.
          tastingEvents: millis != null && existing.tastingEvents.isEmpty
              ? [DateTime.fromMillisecondsSinceEpoch(millis)]
              : existing.tastingEvents,
          updatedAt: DateTime.now(),
        );
        await _writeV1Blob(festivalId, drinkId, merged);
      }

      for (final key in legacyKeys) {
        await _prefs.remove(key);
      }
    }

    await _prefs.setBool(PreferenceKeys.legacyMigrationComplete, true);
  }

  String _v1Key(String festivalId, String drinkId) =>
      '$_legacyPrefix${festivalId}_$drinkId';

  UserDrinkState? _readV1Blob(String festivalId, String drinkId) {
    final raw = _prefs.getString(_v1Key(festivalId, drinkId));
    if (raw == null) return null;
    try {
      return UserDrinkState.fromJson(
        migrate(jsonDecode(raw) as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeV1Blob(
    String festivalId,
    String drinkId,
    UserDrinkState state,
  ) async {
    final key = _v1Key(festivalId, drinkId);
    if (state.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    // Stamp v1 explicitly: the v2 build reads these blobs only via migration.
    final payload = state.toJson()..[schemaKey] = 1;
    await _prefs.setString(key, jsonEncode(payload));
  }

  // --- v1 blob → v2 LogEntry migration (ADR 0006) ---

  /// One-time structural migration of v1 per-drink [UserDrinkState] blobs
  /// (`user_state_{festivalId}_{drinkId}`) into the v2 model: per-drink
  /// [LogEntry] tasting records plus a per-festival want-to-try set.
  ///
  /// For each blob: `wantToTry` → the plan set; each tasting timestamp → a
  /// [LogEntry] (`when` preserved); the drink-level `rating`/`notes`/`photoIds`
  /// attach to the **most recent** tasting, or synthesise one at `updatedAt`
  /// if the drink was rated/noted but never tasted. No data is discarded.
  ///
  /// **Idempotent and crash-safe.** Entry ids are deterministic (UUID v5 over
  /// festival/drink/timestamp/ordinal), so re-processing the same blob
  /// overwrites rather than duplicates. The source blob is removed only after
  /// its entries are written, and the completion flag is set only after every
  /// blob is processed — so a crash mid-run leaves the flag unset and the next
  /// launch resumes without corrupting or duplicating data.
  ///
  /// **Fail-safe on rollback:** an unparseable blob, or one whose schema is
  /// newer than this build, is quarantined (left on disk, skipped) rather than
  /// crashing the migration.
  Future<void> migrateToLogEntries() async {
    if (_prefs.getBool(PreferenceKeys.logEntryMigrationComplete) == true) {
      return;
    }

    final blobKeys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_legacyPrefix))
        .toList();

    for (final key in blobKeys) {
      final rest = key.substring(
        _legacyPrefix.length,
      ); // {festivalId}_{drinkId}
      final sep = rest.indexOf('_');
      if (sep <= 0) continue; // malformed key; leave it
      final festivalId = rest.substring(0, sep);
      final drinkId = rest.substring(sep + 1);
      if (drinkId.isEmpty) continue;

      final UserDrinkState state;
      try {
        final raw = _prefs.getString(key);
        if (raw == null) continue;
        state = UserDrinkState.fromJson(
          migrate(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Corrupt, or newer-than-this-build: quarantine (leave the key), skip.
        continue;
      }

      await _migrateBlobToEntries(festivalId, drinkId, state);

      // Remove the source blob only after its entries are written.
      await _prefs.remove(key);
    }

    await _prefs.setBool(PreferenceKeys.logEntryMigrationComplete, true);
  }

  Future<void> _migrateBlobToEntries(
    String festivalId,
    String drinkId,
    UserDrinkState state,
  ) async {
    if (state.wantToTry) {
      await setWantToTry(festivalId, drinkId, value: true);
    }

    final events = [...state.tastingEvents]..sort((a, b) => a.compareTo(b));
    final hasDrinkLevel =
        state.rating != null ||
        (state.notes != null && state.notes!.isNotEmpty) ||
        state.photoIds.isNotEmpty;

    if (events.isEmpty) {
      // Rated/noted but never tasted → synthesise one tasting at updatedAt.
      if (hasDrinkLevel) {
        final millis = state.updatedAt.millisecondsSinceEpoch;
        await writeEntry(
          festivalId,
          LogEntry(
            id: _migrationEntryId(festivalId, drinkId, millis, 0),
            when: state.updatedAt,
            drinkId: drinkId,
            rating: state.rating,
            note: state.notes,
            photoIds: state.photoIds,
          ),
        );
      }
      return;
    }

    for (var i = 0; i < events.length; i++) {
      final isLatest = i == events.length - 1;
      final millis = events[i].millisecondsSinceEpoch;
      await writeEntry(
        festivalId,
        LogEntry(
          id: _migrationEntryId(festivalId, drinkId, millis, i),
          when: events[i],
          drinkId: drinkId,
          // Drink-level detail attaches to the most recent tasting only.
          rating: isLatest ? state.rating : null,
          note: isLatest ? state.notes : null,
          photoIds: isLatest ? state.photoIds : const [],
        ),
      );
    }
  }

  /// Deterministic entry id for a migrated tasting, so re-running the migration
  /// over the same blob overwrites the same records rather than duplicating.
  /// The [ordinal] disambiguates distinct pours sharing a timestamp.
  static String _migrationEntryId(
    String festivalId,
    String drinkId,
    int whenMillis,
    int ordinal,
  ) => _uuid.v5(
    Namespace.url.value,
    'cbf-myfestival-v2:$festivalId:$drinkId:$whenMillis:$ordinal',
  );

  /// Pure upgrade step for a stored **v1 blob** payload to a shape
  /// [UserDrinkState.fromJson] can read, guarding against a newer schema.
  ///
  /// Kept static and side-effect free so it can be unit-tested directly. A
  /// missing version is treated as v1 (the first shipped format). A payload
  /// newer than this build is rejected (rollback fail-safe); the caller treats
  /// the blob as absent and leaves it on disk.
  @visibleForTesting
  static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
    final version = (raw[schemaKey] as num?)?.toInt() ?? 1;
    if (version > currentSchemaVersion) {
      throw FormatException(
        'Stored user-data schema v$version is newer than this build '
        '(v$currentSchemaVersion); cannot safely downgrade.',
      );
    }
    // v1 and v2 blob payloads share the UserDrinkState field shape; no
    // per-field transform is needed to feed UserDrinkState.fromJson.
    return raw;
  }
}
