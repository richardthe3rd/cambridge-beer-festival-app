import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/string_comparison_helper.dart';
import '../domain/controllers/controllers.dart';
import '../domain/services/services.dart';
import '../domain/repositories/repositories.dart';
import '../domain/models/models.dart';

/// Provider for managing beer festival data and state
class BeerProvider extends ChangeNotifier {
  final AnalyticsService _analyticsService;

  /// Owns all filtering/sorting/search state and the derived views. This
  /// provider feeds it the loaded drinks and handles persistence, analytics,
  /// and change notification around it.
  final DrinkFilterController _filter;

  /// Owns in-memory personal state (want-to-try, rating, tasting) keyed by
  /// drink ID. This provider feeds it the loaded drinks and handles
  /// persistence, analytics, and change notification around it.
  final UserDrinkStateController _personalState = UserDrinkStateController();

  /// Owns in-memory festival registry state: the festivals list, the current
  /// selection, staleness timestamps, and beverage-type comparison.
  final FestivalController _festivalController = FestivalController();

  /// Owns SharedPreferences I/O for theme mode, visibility filters, and
  /// allergen exclusions. Initialised in [initialize] once the preferences
  /// store is open; null before that point.
  UserPreferencesController? _userPrefs;

  DrinkRepository? _drinkRepository;
  FestivalRepository? _festivalRepository;
  ApiDrinkRepository? _ownedDrinkRepository;
  ApiFestivalRepository? _ownedFestivalRepository;

  List<Drink> _allDrinks = [];

  // Memoised backing for [myFestivalEntries]. The personal-data store iterates
  // an unordered key set and re-decodes JSON on every read, so the result is
  // both sorted and cached. Invalidation uses two independent revision counters:
  // [_personalStateRevision] is bumped by [_replaceDrink] (personal-state
  // writes), and [_catalogueRevision] is bumped by [_setAllDrinks] (catalogue
  // loads/reloads). The festival id is also checked so a festival switch
  // immediately invalidates without either counter changing.
  MyFestivalEntries? _myFestivalEntriesCache;
  int _personalStateRevision = 0;
  int _catalogueRevision = 0;
  int _myFestivalEntriesCacheRevision = -1;
  int _myFestivalEntriesCacheCatalogueRevision = -1;
  String? _myFestivalEntriesCacheFestivalId;

  // Theme mode preference; updated in-memory by setThemeMode and restored
  // from SharedPreferences during initialize().
  ThemeMode _themeMode = ThemeMode.system;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isFestivalsLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _refreshNotice;
  String? _festivalsError;

  // Timestamp tracking for automatic refresh
  DateTime? _lastDrinksRefresh;

  // Per-attempt timestamps — set on every call regardless of success/failure.
  // Used by refreshIfStale to rate-limit retries without suppressing the
  // staleness window for a successfully recovered network.
  DateTime? _lastDrinksRefreshAttempt;

  // Staleness thresholds
  static const Duration _drinksStalenessThreshold = Duration(hours: 1);

  // Minimum interval between refresh attempts (covers failed refreshes so the
  // app doesn't hammer the network on every resume when offline).
  static const Duration _refreshRetryThreshold = Duration(minutes: 1);

  // Token incremented on every new drinks load; stale responses check against it
  int _drinksLoadToken = 0;

  BeerProvider({
    AnalyticsService? analyticsService,
    DrinkFilterService? filterService,
    DrinkSortService? sortService,
    DrinkRepository? drinkRepository,
    FestivalRepository? festivalRepository,
  }) : _analyticsService = analyticsService ?? AnalyticsService(),
       _filter = DrinkFilterController(
         filterService: filterService,
         sortService: sortService,
       ),
       _drinkRepository = drinkRepository,
       _festivalRepository = festivalRepository;

  // Getters
  List<Drink> get drinks => _filter.filteredDrinks;
  List<Drink> get allDrinks => _allDrinks;
  List<Festival> get festivals => _festivalController.festivals;

  /// Get festivals sorted by date (live/upcoming first, then past in reverse chronological order)
  List<Festival> get sortedFestivals => _festivalController.sortedFestivals;
  Festival get currentFestival => _festivalController.currentFestival;
  bool get isLoading => _isLoading;

  /// True while a background refresh runs with data already on screen.
  bool get isRefreshing => _isRefreshing;
  bool get isFestivalsLoading => _isFestivalsLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Non-null when a background refresh failed but cached drinks remain shown.
  String? get refreshNotice => _refreshNotice;
  String? get festivalsError => _festivalsError;
  String? get selectedCategory => _filter.selectedCategory;
  Set<String> get selectedStyles => _filter.selectedStyles;
  DrinkSort get currentSort => _filter.currentSort;
  String get searchQuery => _filter.searchQuery;
  bool get showFavoritesOnly => _filter.showFavoritesOnly;
  bool get hideUnavailable => _filter.hideUnavailable;
  Set<DrinkVisibilityFilter> get visibilityFilters => _filter.visibilityFilters;
  Set<String> get excludedAllergens => _filter.excludedAllergens;
  Set<String> get availableAllergens => _filter.availableAllergens;

  bool get hasFestivals => _festivalController.hasFestivals;
  ThemeMode get themeMode => _themeMode;
  DateTime? get lastDrinksRefresh => _lastDrinksRefresh;
  @visibleForTesting
  set lastDrinksRefresh(DateTime? value) => _lastDrinksRefresh = value;
  @visibleForTesting
  DateTime? get lastDrinksRefreshAttempt => _lastDrinksRefreshAttempt;
  @visibleForTesting
  set lastDrinksRefreshAttempt(DateTime? value) =>
      _lastDrinksRefreshAttempt = value;
  @visibleForTesting
  DateTime? get lastFestivalsRefreshAttempt =>
      _festivalController.lastFestivalsRefreshAttempt;
  @visibleForTesting
  set lastFestivalsRefreshAttempt(DateTime? value) =>
      _festivalController.lastFestivalsRefreshAttempt = value;
  AnalyticsService get analyticsService => _analyticsService;

  /// Get unique categories from loaded drinks
  List<String> get availableCategories => _filter.availableCategories;

  /// Get unique styles from loaded drinks (filtered by category if selected)
  List<String> get availableStyles => _filter.availableStyles;

  /// Get drink count by category
  Map<String, int> get categoryCountsMap => _filter.categoryCountsMap;

  /// Get drink count by style
  Map<String, int> get styleCountsMap => _filter.styleCountsMap;

  /// Returns My Festival entries for the current festival: every entry where
  /// the user has marked the drink as want-to-try OR has recorded a tasting.
  ///
  /// [MyFestivalEntries.wantToTry] — entries with wantToTry == true, sorted
  /// alphabetically by drink name (drinkId as tiebreak for placeholders).
  ///
  /// [MyFestivalEntries.tasted] — entries with isTasted == true, sorted by
  /// lastTastedAt descending (drinkId as tiebreak).
  ///
  /// The computed value is memoised; see the _myFestivalEntries* cache fields.
  MyFestivalEntries get myFestivalEntries {
    if (_drinkRepository == null) {
      return const MyFestivalEntries(wantToTry: [], tasted: []);
    }
    final festivalId = currentFestival.id;
    if (_myFestivalEntriesCache != null &&
        _myFestivalEntriesCacheRevision == _personalStateRevision &&
        _myFestivalEntriesCacheCatalogueRevision == _catalogueRevision &&
        _myFestivalEntriesCacheFestivalId == festivalId) {
      return _myFestivalEntriesCache!;
    }

    final entries = _drinkRepository!.getPersonalEntries(festivalId);
    final wantToTryResult = <MyFestivalEntry>[];
    final tastedResult = <MyFestivalEntry>[];
    for (final entry in entries.entries) {
      if (!entry.value.wantToTry && !entry.value.isTasted) continue;
      final drinkId = entry.key;
      final found = _allDrinks.firstWhereOrNull(
        (d) => d.id == drinkId && d.festivalId == festivalId,
      );
      final festivalEntry = MyFestivalEntry(
        drinkId: drinkId,
        festivalId: festivalId,
        state: entry.value,
        drink: found,
      );
      if (entry.value.wantToTry) wantToTryResult.add(festivalEntry);
      if (entry.value.isTasted) tastedResult.add(festivalEntry);
    }

    wantToTryResult.sort((a, b) {
      // Unloaded placeholders (drink == null) sort after all named entries.
      if (a.drink == null && b.drink != null) return 1;
      if (a.drink != null && b.drink == null) return -1;
      final byName = StringComparisonHelper.compareLocaleAware(
        a.drink?.name ?? a.drinkId,
        b.drink?.name ?? b.drinkId,
      );
      return byName != 0 ? byName : a.drinkId.compareTo(b.drinkId);
    });
    // isTasted ⟹ tastingEvents.isNotEmpty ⟹ lastTastedAt != null.
    tastedResult.sort((a, b) {
      final byClock = b.state.lastTastedAt!.compareTo(a.state.lastTastedAt!);
      return byClock != 0 ? byClock : a.drinkId.compareTo(b.drinkId);
    });

    final cached = MyFestivalEntries(
      wantToTry: List.unmodifiable(wantToTryResult),
      tasted: List.unmodifiable(tastedResult),
    );
    _myFestivalEntriesCache = cached;
    _myFestivalEntriesCacheRevision = _personalStateRevision;
    _myFestivalEntriesCacheCatalogueRevision = _catalogueRevision;
    _myFestivalEntriesCacheFestivalId = festivalId;
    return cached;
  }

  /// Thin view: want-to-try entries only. Kept for [FavoritesScreen] until it
  /// is replaced by the My Festival screen (see #315).
  List<MyFestivalEntry> get favoriteEntries => myFestivalEntries.wantToTry;

  /// Check if a festival ID is valid (exists in the registry)
  bool isValidFestivalId(String? festivalId) =>
      _festivalController.isValidFestivalId(festivalId);

  /// Get a festival by ID, or null if not found
  Festival? getFestivalById(String festivalId) =>
      _festivalController.getFestivalById(festivalId);

  /// Check if drinks data is stale and should be refreshed
  bool get isDrinksDataStale {
    if (_lastDrinksRefresh == null) return true;
    return DateTime.now().difference(_lastDrinksRefresh!) >
        _drinksStalenessThreshold;
  }

  /// Check if festivals data is stale and should be refreshed
  bool get isFestivalsDataStale => _festivalController.isFestivalsDataStale;

  /// Initialize with SharedPreferences and load festivals
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Create repositories if not provided. These blocks run only in production
    // (tests inject repositories via the constructor) so their lines are excluded
    // from coverage rather than requiring a network-capable test environment.
    if (_drinkRepository == null) {
      // coverage:ignore-start
      final userDataStore = SharedPreferencesUserDataStore(prefs);
      // Fold any pre-#391 favourites/ratings/tasting data into the unified
      // store on first launch, then forget the old keys.
      await userDataStore.migrateLegacyData();
      final apiService = BeerApiService();
      final drinkCacheService = DrinkCacheService(prefs);
      final owned = ApiDrinkRepository(
        apiService: apiService,
        userDataStore: userDataStore,
        cacheService: drinkCacheService,
        analyticsService: _analyticsService,
      );
      _drinkRepository = owned;
      _ownedDrinkRepository = owned;
      // coverage:ignore-end
    }

    if (_festivalRepository == null) {
      // coverage:ignore-start
      final festivalService = FestivalService();
      final festivalStorageService = FestivalStorageService(prefs);
      final festivalCacheService = FestivalCacheService(prefs);
      final owned = ApiFestivalRepository(
        festivalService: festivalService,
        festivalStorageService: festivalStorageService,
        cacheService: festivalCacheService,
        analyticsService: _analyticsService,
      );
      _festivalRepository = owned;
      _ownedFestivalRepository = owned;
      // coverage:ignore-end
    }

    _userPrefs = UserPreferencesController(prefs);
    final hydratedPrefs = _userPrefs!.hydrate();
    _themeMode =
        ThemeMode.values[hydratedPrefs
            .themeIndex]; // already bounds-checked by controller
    _filter.hydrate(
      visibilityFilters: hydratedPrefs.visibilityFilters,
      excludedAllergens: hydratedPrefs.excludedAllergens,
    );

    // Populate festivals from cache so the switcher works offline and we can
    // resolve the saved selection without waiting on the network.
    final cachedFestivals = await _festivalRepository!.getCachedFestivals();
    if (cachedFestivals != null) {
      _festivalController.setCachedFestivals(cachedFestivals.festivals);
    } else {
      // First launch (nothing cached): we have nothing to show until the
      // registry loads, so block on it as before.
      await loadFestivals();
    }

    // Restore previously selected festival if it still exists in the (cached
    // or freshly loaded) registry. We deliberately do NOT fall back to the
    // hard-coded DefaultFestivals here: an id that has been retired from the
    // registry should let the registry's defaultFestival take over rather
    // than resurrect a defunct selection whose dataBaseUrl would 404. Only
    // overwrite _currentFestival when the saved id matches an active entry
    // so we don't clobber a default already set by loadFestivals above.
    final savedFestivalId = await _festivalRepository!.getSelectedFestivalId();
    _festivalController.restoreSelection(savedFestivalId);
    if (cachedFestivals != null) {
      _festivalController.applyFallback(
        defaultFestival: cachedFestivals.defaultFestival,
      );
    }

    _isInitialized = true;
    notifyListeners();

    // When cached festivals were shown, refresh the registry in the background
    // so drinks loading is never blocked on the network.
    if (cachedFestivals != null) {
      unawaited(loadFestivals());
    }
  }

  /// Load festivals from the API
  Future<void> loadFestivals() async {
    _isFestivalsLoading = true;
    _festivalsError = null;
    notifyListeners();

    try {
      final response = await _festivalRepository!.getFestivals();
      final beverageTypesChanged = _festivalController.setSource(
        response.festivals,
        defaultFestival: response.defaultFestival,
      );

      if (beverageTypesChanged) {
        unawaited(loadDrinks());
      }

      _festivalsError = null;
    } catch (e) {
      // Fall back to cached festivals so the switcher keeps working offline
      // instead of emptying the list and blocking the app.
      final cached = await _festivalRepository?.getCachedFestivals();
      if (cached != null && cached.festivals.isNotEmpty) {
        _festivalController.setFallbackFestivals(
          cached.festivals,
          defaultFestival: cached.defaultFestival,
        );
        _festivalsError = null;
      } else {
        _festivalsError = _getUserFriendlyErrorMessage(e);
        _festivalController.clearFestivals();
      }
    } finally {
      _festivalController.recordAttempt();
      _isFestivalsLoading = false;
      notifyListeners();
    }
  }

  /// Load drinks for the current festival.
  ///
  /// Stale-while-revalidate: if nothing is loaded yet, cached drinks are shown
  /// immediately, then a fresh copy is fetched from the network in the
  /// background. A failed refresh keeps any cached data on screen rather than
  /// blanking to an error.
  Future<void> loadDrinks() async {
    if (!_festivalController.hasFestivals) {
      // Wait for festivals to be loaded first
      await loadFestivals();
    }
    // Apply a hard-coded fallback if the controller still has no selection
    // (loadFestivals may have failed).
    if (!_festivalController.hasFestivals) {
      _festivalController.applyFallback(
        defaultFestival: DefaultFestivals.all.firstWhere(
          (f) => f.isActive,
          orElse: () => DefaultFestivals.all.first,
        ),
      );
    }

    final festival = currentFestival;
    final token = ++_drinksLoadToken;

    // Phase 1: render cached data instantly when we have nothing in memory.
    if (_allDrinks.isEmpty) {
      final cached = await _drinkRepository!.getCachedDrinks(festival);
      if (token != _drinksLoadToken) return;
      if (cached != null) {
        _setAllDrinks(cached);
        _error = null;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
    }
    // Keep any pre-existing _refreshNotice in place — it'll be cleared on a
    // successful refresh, so the banner doesn't flicker on every resume when
    // refreshes keep failing.
    _isRefreshing = true;
    notifyListeners();

    // Phase 2: refresh from the network.
    await _refreshDrinksFromNetwork(token, festival);
  }

  /// Change the current festival (drinks loaded lazily on demand)
  ///
  /// If [persist] is true (default), saves the festival selection to local storage.
  /// Set to false for temporary festival viewing (e.g., deep links to old festivals).
  Future<void> setFestival(Festival festival, {bool persist = true}) async {
    // Tapping the current festival is a no-op unless a refresh notice is
    // up — in which case treat it as a retry so the switcher offers an
    // obvious way back to a fresh load.
    if (currentFestival.id == festival.id) {
      if (_refreshNotice != null) await loadDrinks();
      return;
    }
    _festivalController.selectFestival(festival);
    _filter.clearCategoryStyleSearch();
    // Clear existing drinks and signal the switch immediately so the UI rebuilds
    // against the new festival id; the new festival's cached drinks (if any)
    // replace them below, otherwise the spinner stays up.
    _setAllDrinks([]);
    _error = null;
    _refreshNotice = null;
    _isLoading = true;
    _isRefreshing = true;
    final token = ++_drinksLoadToken;
    notifyListeners();

    final cached = await _drinkRepository?.getCachedDrinks(festival);
    if (token != _drinksLoadToken) return;
    if (cached != null) {
      _setAllDrinks(cached);
      _isLoading = false;
      notifyListeners();
    }

    unawaited(_analyticsService.logFestivalSelected(festival));

    if (persist) {
      await _festivalRepository?.setSelectedFestivalId(festival.id);
    }

    await _refreshDrinksFromNetwork(token, festival);
  }

  /// Fetch fresh drinks from the network and reconcile with what's on screen.
  ///
  /// [token] must match [_drinksLoadToken] for results to be applied; a
  /// mismatch means a newer load has started and this response is stale.
  /// [festival] is captured at call time to avoid reading the live
  /// [currentFestival] getter after intervening awaits may have changed it.
  ///
  /// On failure, cached drinks already on screen are kept (with a quiet
  /// [refreshNotice]); only a fully blocked load (no data) surfaces an [error].
  Future<void> _refreshDrinksFromNetwork(int token, Festival festival) async {
    try {
      // Repository returns drinks with favorites and ratings already populated.
      final drinks = await _drinkRepository!.getDrinks(festival);
      if (token != _drinksLoadToken) return;
      _setAllDrinks(drinks);
      _error = null;
      _refreshNotice = null;
      // Only mark drinks as freshly fetched when the festival had types to
      // request. If availableBeverageTypes is empty, Future.wait([]) succeeds
      // trivially with no network contact; reset the timestamp so that
      // isDrinksDataStale stays true and refreshIfStale can retry once the
      // rate-limit window passes (e.g. after switching from a loaded festival).
      if (festival.availableBeverageTypes.isNotEmpty) {
        _lastDrinksRefresh = DateTime.now();
      } else {
        _lastDrinksRefresh = null;
      }
    } catch (e, stackTrace) {
      if (token != _drinksLoadToken) return;
      final haveData = _allDrinks.isNotEmpty;
      if (haveData) {
        // Keep showing cached data; surface a quiet, dismissible notice.
        _refreshNotice = 'Showing saved data — couldn\'t refresh.';
        _error = null;
      } else {
        _error = _getUserFriendlyErrorMessage(e);
        _setAllDrinks([]);
      }
      // Log to Crashlytics unless this is an expected offline failure that we
      // already covered with cached data. Always log when fully blocked, and
      // always log non-connectivity failures so a silent never-load bug
      // (e.g. a server or parsing error masked by the cache) still surfaces.
      if (!haveData || !_isConnectivityError(e)) {
        unawaited(
          _analyticsService.logError(
            e,
            stackTrace,
            reason: 'Failed to load drinks for festival: ${festival.id}',
          ),
        );
      }
    } finally {
      if (token == _drinksLoadToken) {
        _lastDrinksRefreshAttempt = DateTime.now();
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /// Whether [error] represents a connectivity failure (offline / timeout)
  /// rather than a server or data error. Recognises [BeerApiException]
  /// wrappers that carry an underlying connectivity error as [cause].
  bool _isConnectivityError(Object error) {
    if (isConnectivityFailure(error)) return true;
    if (error is BeerApiException && error.cause != null) {
      return isConnectivityFailure(error.cause!);
    }
    return false;
  }

  /// Dismiss the "showing saved data" notice (e.g. when the user taps it away).
  void dismissRefreshNotice() {
    if (_refreshNotice == null) return;
    _refreshNotice = null;
    notifyListeners();
  }

  /// Refresh data if it's stale (called when app resumes from background)
  Future<void> refreshIfStale() async {
    // Don't refresh if a load (foreground spinner or background SWR refresh)
    // is already in flight; otherwise a resume could kick a duplicate fetch
    // and the older response gets discarded via the token.
    if (_isLoading || _isRefreshing || _isFestivalsLoading) return;

    // Rate-limit retries: skip if an attempt was made recently (e.g. last call
    // failed with the network offline but cached data kept the app usable).
    // This prevents hammering the network on every app-resume while offline.
    // DateTime.now() is evaluated separately for each check so that a slow
    // loadFestivals() await doesn't cause the drinks check to use a stale time.
    final lastFestivalsAttempt =
        _festivalController.lastFestivalsRefreshAttempt;
    final festivalsRetryReady =
        lastFestivalsAttempt == null ||
        DateTime.now().difference(lastFestivalsAttempt) >
            _refreshRetryThreshold;
    if (isFestivalsDataStale && festivalsRetryReady) {
      await loadFestivals();
    }

    final drinksRetryReady =
        _lastDrinksRefreshAttempt == null ||
        DateTime.now().difference(_lastDrinksRefreshAttempt!) >
            _refreshRetryThreshold;
    if (isDrinksDataStale && drinksRetryReady) {
      await loadDrinks();
    }
  }

  /// Convert exceptions to user-friendly error messages
  String _getUserFriendlyErrorMessage(Object error) {
    if (error is BeerApiException) {
      if (error.statusCode == 404) {
        return 'Festival data not found. Please try a different festival.';
      } else if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Server error. Please try again later.';
      } else if (error.statusCode != null && error.statusCode! >= 400) {
        return 'Could not load drinks. Please try again.';
      } else {
        return 'Could not load drinks. Please check your connection.';
      }
    } else if (error is FestivalServiceException) {
      if (error.statusCode == 404) {
        return 'Festival list not found. Please try again later.';
      } else if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Server error. Please try again later.';
      } else {
        return 'Could not load festivals. Please check your connection.';
      }
    } else if (error is http.ClientException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Set category filter
  void setCategory(String? category) {
    // The controller clears the style filter when the category changes, since
    // styles are category-dependent.
    _filter.setCategory(category);
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logCategoryFilter(category));
  }

  /// Toggle a style filter (supports multiple style selection)
  void toggleStyle(String style) {
    _filter.toggleStyle(style);
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logStyleFilter(_filter.selectedStyles));
  }

  /// Clear all style filters
  void clearStyles() {
    _filter.clearStyles();
    notifyListeners();
  }

  /// Set sort option
  void setSort(DrinkSort sort) {
    _filter.setSort(sort);
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logSortChange(sort.name));
  }

  /// Set search query
  void setSearchQuery(String query) {
    _filter.setSearchQuery(query);
    notifyListeners();
    // Log analytics event if query is not empty (fire and forget)
    if (query.trim().isNotEmpty) {
      unawaited(_analyticsService.logSearch(query));
    }
  }

  /// Toggle showing favorites only
  void setShowFavoritesOnly({required bool value}) {
    _filter.setShowFavoritesOnly(value: value);
    notifyListeners();
  }

  /// Toggle hiding unavailable drinks and persist preference
  ///
  /// Convenience wrapper around [setVisibilityFilter] for backward compatibility.
  Future<void> setHideUnavailable({required bool value}) =>
      setVisibilityFilter(DrinkVisibilityFilter.availableOnly, active: value);

  /// Set a visibility filter on or off and persist the preference
  Future<void> setVisibilityFilter(
    DrinkVisibilityFilter filter, {
    required bool active,
  }) async {
    _filter.setVisibilityFilter(filter, active: active);
    notifyListeners();
    await _persistVisibilityFilters();
  }

  /// Clear all visibility filters and persist
  Future<void> clearVisibilityFilters() async {
    _filter.clearVisibilityFilters();
    notifyListeners();
    await _persistVisibilityFilters();
  }

  /// Toggle a per-allergen exclusion filter and persist
  Future<void> setAllergenFilter(
    String allergen, {
    required bool active,
  }) async {
    _filter.setAllergenFilter(allergen, active: active);
    notifyListeners();
    await _persistExcludedAllergens();
  }

  /// Clear all allergen exclusion filters and persist
  Future<void> clearAllergenFilters() async {
    _filter.clearAllergenFilters();
    notifyListeners();
    await _persistExcludedAllergens();
  }

  /// Persist the full set of active visibility filters.
  Future<void> _persistVisibilityFilters() async {
    await _userPrefs?.persistVisibilityFilters(_filter.visibilityFilters);
  }

  /// Persist the full set of excluded allergens.
  Future<void> _persistExcludedAllergens() async {
    await _userPrefs?.persistAllergens(_filter.excludedAllergens);
  }

  /// Set theme mode and persist preference
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _userPrefs?.persistThemeMode(mode.index);
  }

  /// Assign [drinks] as the active catalogue and propagate to both controllers.
  ///
  /// Single call site ensures [_allDrinks], [_filter], and [_personalState]
  /// are never updated independently.
  void _setAllDrinks(List<Drink> drinks) {
    _allDrinks = drinks;
    _catalogueRevision++;
    _filter.setSource(drinks);
    _personalState.setSource(drinks);
  }

  /// Replace a drink in [_allDrinks] with [updated] and recompute filters.
  ///
  /// Returns [updated] for convenience.
  Drink _replaceDrink(Drink old, Drink updated) {
    final idx = _allDrinks.indexWhere(
      (d) => d.id == old.id && d.festivalId == old.festivalId,
    );
    if (idx != -1) {
      _allDrinks[idx] = updated;
    }
    // Personal state changed — invalidate the memoised favourites list.
    _personalStateRevision++;
    _filter.recompute();
    return updated;
  }

  /// Toggle favorite status for a drink
  Future<void> toggleFavorite(Drink drink) async {
    if (_drinkRepository == null) return;

    final newState = _personalState.apply(
      drink.id,
      await _drinkRepository!.toggleFavorite(currentFestival.id, drink.id),
    );
    _replaceDrink(drink, drink.copyWith(userState: newState));

    notifyListeners();

    // Log analytics event (fire and forget)
    if (newState?.wantToTry ?? false) {
      unawaited(_analyticsService.logFavoriteAdded(drink));
    } else {
      unawaited(_analyticsService.logFavoriteRemoved(drink));
    }
  }

  /// Set rating for a drink (1-5), or clear it with null
  Future<void> setRating(Drink drink, int? rating) async {
    if (_drinkRepository == null) return;

    final UserDrinkState? persisted;
    if (rating == null) {
      persisted = await _drinkRepository!.removeRating(
        currentFestival.id,
        drink.id,
      );
    } else {
      persisted = await _drinkRepository!.setRating(
        currentFestival.id,
        drink.id,
        rating,
      );
      // Log analytics event for rating (fire and forget)
      unawaited(_analyticsService.logRatingGiven(drink, rating));
    }
    final newState = _personalState.apply(drink.id, persisted);
    _replaceDrink(drink, drink.copyWith(userState: newState));
    notifyListeners();
  }

  /// Toggle tasted status for a drink
  Future<void> toggleTasted(Drink drink) async {
    if (_drinkRepository == null) return;

    final newState = _personalState.apply(
      drink.id,
      await _drinkRepository!.toggleTasted(currentFestival.id, drink.id),
    );
    _replaceDrink(drink, drink.copyWith(userState: newState));

    notifyListeners();

    // Log analytics event
    if (newState?.isTasted ?? false) {
      unawaited(analyticsService.logTastedAdded(drink));
    } else {
      unawaited(analyticsService.logTastedRemoved(drink));
    }
  }

  /// Get a drink by ID
  Drink? getDrinkById(String id) {
    return _allDrinks.firstWhereOrNull((d) => d.id == id);
  }

  @override
  void dispose() {
    try {
      _ownedDrinkRepository?.dispose(); // coverage:ignore-line
      _ownedFestivalRepository?.dispose(); // coverage:ignore-line
    } finally {
      super.dispose();
    }
  }
}
