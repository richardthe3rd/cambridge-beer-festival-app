/// Centralized SharedPreferences key definitions.
///
/// Every persisted value in the app must reference a key from this class rather
/// than an inline string literal. A mistyped key reads back `null` and silently
/// loses the user's data, so keeping the producer and consumer of each key in
/// one place removes that class of bug.
///
/// **These string values are part of the on-disk format.** Changing one orphans
/// every value already stored under the old key. Don't edit a value here unless
/// you also migrate existing data. [PreferenceKeys] is guarded by a test that
/// pins the literals.
class PreferenceKeys {
  PreferenceKeys._(); // coverage:ignore-line

  // --- BeerProvider ---

  /// Persisted [ThemeMode] index. Stored with `setInt`.
  static const themeMode = 'themeMode';

  /// Active drink visibility filters. Stored as a string list of enum names.
  static const visibilityFilters = 'visibilityFilters';

  /// Legacy boolean preference superseded by [visibilityFilters]. Read-only:
  /// migrated on load (see `BeerProvider.initialize`) and never written again.
  static const hideUnavailableLegacy = 'hideUnavailable';

  /// Allergens the user has excluded. Stored as a string list.
  static const excludedAllergens = 'excludedAllergens';

  // --- UserDataStore ---

  /// Prefix for the **legacy v1** unified per-drink personal record
  /// (favourite/want-to-try, ratings, tasting events, notes, photos). One
  /// structured JSON blob per drink-per-festival, scoped as
  /// `$userStatePrefix${festivalId}_$drinkId`.
  ///
  /// Unified the former `favorites`, `ratings`, and `tasting_log_` key schemes
  /// (#391). Superseded by the v2 [logEntryPrefix] / [wantToTryPrefix] model
  /// (ADR 0006): [SharedPreferencesUserDataStore.migrateToLogEntries] reads any
  /// blob stored under this prefix, folds it into the v2 model, then deletes it.
  /// Read-only from v2 onward; never written again.
  static const userStatePrefix = 'user_state_';

  /// Prefix for a single **My Festival log entry** (check-in) in the v2 schema
  /// (ADR 0006). Scoped as `$logEntryPrefix${festivalId}_$entryId`, where
  /// `entryId` is a UUID. One JSON record per entry; edit/delete key off the
  /// id. A tasting is an entry whose `drinkId` is non-null.
  static const logEntryPrefix = 'log_entry_';

  /// Per-festival "want to try" plan set in the v2 schema (ADR 0006). Scoped as
  /// `$wantToTryPrefix$festivalId` → a `StringList` of drink IDs. Present only
  /// while non-empty (the key is removed when the set empties).
  static const wantToTryPrefix = 'want_to_try_';

  // --- Legacy personal-state keys (read-only; migration only) ---

  /// Legacy favourites key: `${favoritesLegacy}_$festivalId` → `StringList` of
  /// drink IDs. Read once by the user-data migration, then deleted. Never
  /// written.
  static const favoritesLegacy = 'favorites';

  /// Legacy ratings key: `${ratingsLegacy}_${festivalId}_$drinkId` → `int`.
  /// Read once by the user-data migration, then deleted. Never written.
  static const ratingsLegacy = 'ratings';

  /// Legacy tasting-log key prefix: `$tastingLogLegacyPrefix${festivalId}|$drinkId`
  /// → `int` (millis). Read once by the user-data migration, then deleted.
  /// Never written.
  static const tastingLogLegacyPrefix = 'tasting_log_';

  /// Flag set to `true` after the one-time migration of pre-#391 personal-state
  /// keys into the unified [userStatePrefix] format. When present and true the
  /// migration is skipped on startup, avoiding a full key-scan every launch.
  ///
  /// Intentionally does NOT share the `user_state_` prefix so it cannot
  /// collide with a per-drink record key (`user_state_{festivalId}_{drinkId}`).
  static const legacyMigrationComplete = 'personal_state_migration_v1';

  /// Flag set to `true` after the one-time v1 → v2 migration of per-drink
  /// [userStatePrefix] blobs into the v2 LogEntry model
  /// ([logEntryPrefix] + [wantToTryPrefix], ADR 0006). When present and true the
  /// key-scan is skipped on every launch after the first successful run.
  ///
  /// Like [legacyMigrationComplete], deliberately does NOT share the v2 prefixes
  /// so it cannot collide with an entry or want-to-try record.
  static const logEntryMigrationComplete = 'my_festival_migration_v2';

  // --- FestivalStorageService ---

  /// The last selected festival ID. Stored with `setString`.
  static const selectedFestivalId = 'selected_festival_id';

  // --- DrinkCacheService ---

  /// Prefix for the per-festival drinks cache. Scoped as `${drinksCachePrefix}_$festivalId`.
  static const drinksCachePrefix = 'drinks_cache';

  // --- FestivalCacheService ---

  /// The cached festival registry. Stored with `setString`.
  static const festivalsCache = 'festivals_cache';
}
