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
  PreferenceKeys._();

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

  // --- FavoritesService ---

  /// Base key for favourite drink IDs. Festival-scoped as `${favorites}_$festivalId`.
  static const favorites = 'favorites';

  // --- RatingsService ---

  /// Base key for personal ratings. Scoped as `${ratings}_${festivalId}_$drinkId`.
  static const ratings = 'ratings';

  // --- FestivalStorageService ---

  /// The last selected festival ID. Stored with `setString`.
  static const selectedFestivalId = 'selected_festival_id';

  // --- TastingLogService ---

  /// Prefix for tasting-log entries. Scoped as `$tastingLogPrefix${festivalId}|$drinkId`.
  static const tastingLogPrefix = 'tasting_log_';

  // --- DrinkCacheService ---

  /// Prefix for the per-festival drinks cache. Scoped as `${drinksCachePrefix}_$festivalId`.
  static const drinksCachePrefix = 'drinks_cache';

  // --- FestivalCacheService ---

  /// The cached festival registry. Stored with `setString`.
  static const festivalsCache = 'festivals_cache';
}
