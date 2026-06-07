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

  /// Prefix for the unified per-drink personal record (favourite/want-to-try,
  /// ratings, tasting events, notes, photos). One structured JSON entry per
  /// drink-per-festival, scoped as `$userStatePrefix${festivalId}_$drinkId`.
  ///
  /// Unifies the former `favorites`, `ratings`, and `tasting_log_` key schemes
  /// (#391). A one-time migration folds any data stored under those legacy keys
  /// into this format on first launch (see [legacy keys] below).
  static const userStatePrefix = 'user_state_';

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
  static const legacyMigrationComplete = 'user_state_migration_v1';

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
