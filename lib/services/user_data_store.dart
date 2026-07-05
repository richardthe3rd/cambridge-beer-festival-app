import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/preference_keys.dart';
import '../models/models.dart';

/// A drink's user-set detail, independent of the tasting timeline: rating,
/// notes, and photo IDs. Stored per drink so a drink can be rated/noted
/// **without** being marked tasted (a rating is personal tracking, not a claim
/// that the drink was drunk).
typedef DrinkDetail = ({int? rating, String? notes, List<String> photoIds});

/// Abstraction over personal-data persistence.
///
/// My Festival has three orthogonal axes (ADR 0006, refined so rating is
/// independent of tasting):
/// - a **timeline of [LogEntry] check-ins** (the diary; a tasting is an entry
///   whose `drinkId` is set),
/// - a per-drink `wantToTry` **plan** intent, and
/// - a per-drink **detail** (rating / notes / photos).
///
/// Per-drink [UserDrinkState] views are **derived** from these so existing
/// consumers stay unchanged. All access goes through this interface, so the
/// backend is a constructor swap (local-first today, a synced store later).
abstract class UserDataStore {
  /// The derived per-drink view for a drink, or null when it has no signal on
  /// any axis.
  UserDrinkState? read(String festivalId, String drinkId);

  /// All derived per-drink views for a festival, keyed by drink ID.
  Map<String, UserDrinkState> readAll(String festivalId);

  /// Every stored log entry for a festival (the diary timeline, unordered).
  List<LogEntry> readEntries(String festivalId);

  /// Persist a single entry (create or edit — keyed by its stable id).
  Future<void> writeEntry(String festivalId, LogEntry entry);

  /// Remove a single entry by id.
  Future<void> removeEntry(String festivalId, String entryId);

  /// The set of drink IDs the user has flagged as "want to try".
  Set<String> readWantToTry(String festivalId);

  /// Add or remove a drink from the festival's want-to-try set.
  Future<void> setWantToTry(
    String festivalId,
    String drinkId, {
    required bool value,
  });

  /// Set or clear (null) the drink-level rating, independent of tastings.
  Future<void> setDrinkRating(
    String festivalId,
    String drinkId, {
    required int? rating,
  });

  /// Set or clear (null) the drink-level notes, independent of tastings.
  Future<void> setDrinkNotes(
    String festivalId,
    String drinkId, {
    required String? notes,
  });

  /// Clear every entry, want-to-try flag, and detail record for a festival.
  Future<void> clearFestival(String festivalId);
}

/// [SharedPreferences]-backed [UserDataStore] (v2 model, ADR 0006).
///
/// Storage layout:
/// - One JSON record per entry under `log_entry_{festivalId}_{id}`.
/// - One `StringList` per festival under `want_to_try_{festivalId}`.
/// - One JSON detail record per drink under `drink_detail_{festivalId}_{drinkId}`.
///
/// The want-to-try key and each detail record are present only while they carry
/// a signal (pruned when empty). Entries are pruned only by explicit delete (a
/// check-in is a real event). Each entry / detail payload carries a [schemaKey]
/// version; a payload newer than this build is rejected on read (rollback
/// fail-safe) and left untouched on disk. The one-time v1 → v2 migration is
/// [migrateToLogEntries]; the pre-#391 → v1 fold is [migrateLegacyData].
class SharedPreferencesUserDataStore implements UserDataStore {
  /// Legacy v1 per-drink blob prefix (`user_state_{festivalId}_{drinkId}`).
  /// Read-only from v2: consumed and deleted by [migrateToLogEntries].
  static const String _legacyPrefix = PreferenceKeys.userStatePrefix;
  static const String _entryPrefix = PreferenceKeys.logEntryPrefix;
  static const String _wantToTryPrefix = PreferenceKeys.wantToTryPrefix;
  static const String _detailPrefix = PreferenceKeys.drinkDetailPrefix;

  /// JSON key holding an entry/detail payload's schema version.
  static const String schemaKey = 'version';

  /// The schema version written by this build.
  static const int currentSchemaVersion = 2;

  static const Uuid _uuid = Uuid();

  final SharedPreferences _prefs;

  SharedPreferencesUserDataStore(this._prefs);

  String _entryFestivalPrefix(String festivalId) =>
      '$_entryPrefix${festivalId}_';

  String _entryKey(String festivalId, String id) =>
      '${_entryFestivalPrefix(festivalId)}$id';

  String _wantToTryKey(String festivalId) => '$_wantToTryPrefix$festivalId';

  String _detailFestivalPrefix(String festivalId) =>
      '$_detailPrefix${festivalId}_';

  String _detailKey(String festivalId, String drinkId) =>
      '${_detailFestivalPrefix(festivalId)}$drinkId';

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

  // --- Drink-level detail (rating / notes / photos, independent of tastings) ---

  DrinkDetail? _readDetail(String festivalId, String drinkId) =>
      _decodeDetail(_prefs.getString(_detailKey(festivalId, drinkId)));

  Future<void> _writeDetail(
    String festivalId,
    String drinkId,
    DrinkDetail detail,
  ) async {
    final key = _detailKey(festivalId, drinkId);
    // Prune when the record carries no signal, so it leaves no key behind.
    if (detail.rating == null &&
        (detail.notes == null || detail.notes!.isEmpty) &&
        detail.photoIds.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final payload = <String, dynamic>{
      'rating': detail.rating,
      'notes': detail.notes,
      'photoIds': detail.photoIds,
      schemaKey: currentSchemaVersion,
    };
    await _prefs.setString(key, jsonEncode(payload));
  }

  @override
  Future<void> setDrinkRating(
    String festivalId,
    String drinkId, {
    required int? rating,
  }) async {
    final current = _readDetail(festivalId, drinkId);
    await _writeDetail(festivalId, drinkId, (
      rating: rating,
      notes: current?.notes,
      photoIds: current?.photoIds ?? const [],
    ));
  }

  @override
  Future<void> setDrinkNotes(
    String festivalId,
    String drinkId, {
    required String? notes,
  }) async {
    final current = _readDetail(festivalId, drinkId);
    await _writeDetail(festivalId, drinkId, (
      rating: current?.rating,
      notes: notes,
      photoIds: current?.photoIds ?? const [],
    ));
  }

  Map<String, DrinkDetail> _readAllDetails(String festivalId) {
    final prefix = _detailFestivalPrefix(festivalId);
    final result = <String, DrinkDetail>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final detail = _decodeDetail(_prefs.getString(key));
      if (detail != null) result[key.substring(prefix.length)] = detail;
    }
    return result;
  }

  // --- Derived per-drink views ---

  @override
  UserDrinkState? read(String festivalId, String drinkId) {
    final entries = readEntries(
      festivalId,
    ).where((e) => e.drinkId == drinkId).toList();
    return _derive(
      entries,
      wantToTry: readWantToTry(festivalId).contains(drinkId),
      detail: _readDetail(festivalId, drinkId),
    );
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
    final details = _readAllDetails(festivalId);

    // Every drink with a signal on any axis needs a view.
    final drinkIds = <String>{...byDrink.keys, ...wantToTry, ...details.keys};
    final result = <String, UserDrinkState>{};
    for (final drinkId in drinkIds) {
      final state = _derive(
        byDrink[drinkId] ?? const <LogEntry>[],
        wantToTry: wantToTry.contains(drinkId),
        detail: details[drinkId],
      );
      if (state != null) result[drinkId] = state;
    }
    return result;
  }

  /// Derives a drink's aggregate [UserDrinkState] from its tasting [entries],
  /// want-to-try flag, and drink-level [detail]. Rating/notes/photos come from
  /// the detail record (independent of tastings); pours = tasting count.
  /// Returns null when there is no signal at all.
  static UserDrinkState? _derive(
    List<LogEntry> entries, {
    required bool wantToTry,
    required DrinkDetail? detail,
  }) {
    if (entries.isEmpty && !wantToTry && detail == null) return null;
    final sorted = [...entries]..sort((a, b) => a.when.compareTo(b.when));
    final createdAt = sorted.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : sorted.first.when;
    final updatedAt = sorted.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : sorted.last.when;
    final state = UserDrinkState(
      wantToTry: wantToTry,
      tastingEvents: sorted.map((e) => e.when).toList(),
      rating: detail?.rating,
      notes: detail?.notes,
      photoIds: detail?.photoIds ?? const [],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    return state.isEmpty ? null : state;
  }

  @override
  Future<void> clearFestival(String festivalId) async {
    final prefixes = [
      _entryFestivalPrefix(festivalId),
      _detailFestivalPrefix(festivalId),
    ];
    final keys = _prefs
        .getKeys()
        .where((k) => prefixes.any(k.startsWith))
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_wantToTryKey(festivalId));
  }

  /// Decodes a stored entry payload, guarding by schema version (a payload
  /// newer than this build is treated as absent — quarantined on disk).
  LogEntry? _decodeEntry(String? raw) {
    final decoded = _decodeVersioned(raw);
    if (decoded == null) return null;
    try {
      return LogEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Decodes a stored detail payload, guarding by schema version.
  DrinkDetail? _decodeDetail(String? raw) {
    final decoded = _decodeVersioned(raw);
    if (decoded == null) return null;
    try {
      return (
        rating: (decoded['rating'] as num?)?.toInt(),
        notes: decoded['notes'] as String?,
        photoIds:
            (decoded['photoIds'] as List?)?.map((e) => e as String).toList() ??
            const [],
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses a versioned JSON payload, returning null when absent, unparseable,
  /// or newer than this build (rollback fail-safe — the bytes on disk are left
  /// untouched for a build that understands them).
  Map<String, dynamic>? _decodeVersioned(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final version =
          (decoded[schemaKey] as num?)?.toInt() ?? currentSchemaVersion;
      if (version > currentSchemaVersion) return null;
      return decoded;
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
  /// rather than overwriting. Idempotent via a persisted
  /// [PreferenceKeys.legacyMigrationComplete] flag.
  ///
  /// Runs **before** [migrateToLogEntries] in [BeerProvider.initialize]: the
  /// blobs it produces are then folded into the v2 model.
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

  // --- v1 blob → v2 migration (ADR 0006) ---

  /// One-time structural migration of v1 per-drink [UserDrinkState] blobs
  /// (`user_state_{festivalId}_{drinkId}`) into the v2 model: `wantToTry` → the
  /// plan set; each tasting timestamp → a [LogEntry] pour (`when` preserved);
  /// `rating`/`notes`/`photoIds` → the drink **detail** record.
  ///
  /// Lossless and behaviour-preserving: a rated-but-never-tasted drink keeps
  /// `isTasted == false` (its rating lives in the detail record, not a
  /// synthesised tasting).
  ///
  /// **Idempotent and crash-safe.** Entry ids are deterministic (UUID v5 over
  /// festival/drink/timestamp/ordinal) and the detail record is keyed by drink,
  /// so re-processing a blob overwrites rather than duplicates. The source blob
  /// is removed only after its v2 records are written, and the completion flag
  /// is set only after every blob is processed — a crash mid-run resumes on the
  /// next launch. **Fail-safe on rollback:** an unparseable blob, or one whose
  /// schema is newer than this build, is quarantined (left on disk, skipped).
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

      await _migrateBlob(festivalId, drinkId, state);

      // Remove the source blob only after its v2 records are written.
      await _prefs.remove(key);
    }

    await _prefs.setBool(PreferenceKeys.logEntryMigrationComplete, true);
  }

  Future<void> _migrateBlob(
    String festivalId,
    String drinkId,
    UserDrinkState state,
  ) async {
    if (state.wantToTry) {
      await setWantToTry(festivalId, drinkId, value: true);
    }

    // Drink-level rating/notes/photos → detail record (independent of tastings).
    if (state.rating != null ||
        (state.notes != null && state.notes!.isNotEmpty) ||
        state.photoIds.isNotEmpty) {
      await _writeDetail(festivalId, drinkId, (
        rating: state.rating,
        notes: state.notes,
        photoIds: state.photoIds,
      ));
    }

    // Each tasting timestamp → a pour entry.
    final events = [...state.tastingEvents]..sort((a, b) => a.compareTo(b));
    for (var i = 0; i < events.length; i++) {
      await writeEntry(
        festivalId,
        LogEntry(
          id: _migrationEntryId(
            festivalId,
            drinkId,
            events[i].millisecondsSinceEpoch,
            i,
          ),
          when: events[i],
          drinkId: drinkId,
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
  /// missing version is treated as v1. A payload newer than this build is
  /// rejected (rollback fail-safe); the caller treats the blob as absent.
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
