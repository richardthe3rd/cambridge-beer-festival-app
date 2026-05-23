import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../domain/services/services.dart';
import '../domain/repositories/repositories.dart';
import '../domain/models/models.dart';

/// Provider for managing beer festival data and state
class BeerProvider extends ChangeNotifier {
  final AnalyticsService _analyticsService;
  final DrinkFilterService _filterService;
  final DrinkSortService _sortService;
  DrinkRepository? _drinkRepository;
  FestivalRepository? _festivalRepository;

  List<Drink> _allDrinks = [];
  List<Drink> _filteredDrinks = [];
  List<Festival> _festivals = [];
  Festival? _currentFestival;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isFestivalsLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _refreshNotice;
  String? _festivalsError;
  String? _selectedCategory;
  Set<String> _selectedStyles = {};
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  Set<DrinkVisibilityFilter> _visibilityFilters = {};
  Set<String> _excludedAllergens = {};
  ThemeMode _themeMode = ThemeMode.system;

  // Timestamp tracking for automatic refresh
  DateTime? _lastDrinksRefresh;
  DateTime? _lastFestivalsRefresh;

  // Staleness thresholds
  static const Duration _drinksStalenessThreshold = Duration(hours: 1);
  static const Duration _festivalsStalenessThreshold = Duration(hours: 24);

  // Token incremented on every new drinks load; stale responses check against it
  int _drinksLoadToken = 0;

  BeerProvider({
    AnalyticsService? analyticsService,
    DrinkFilterService? filterService,
    DrinkSortService? sortService,
    DrinkRepository? drinkRepository,
    FestivalRepository? festivalRepository,
  })  : _analyticsService = analyticsService ?? AnalyticsService(),
        _filterService = filterService ?? DrinkFilterService(),
        _sortService = sortService ?? DrinkSortService(),
        _drinkRepository = drinkRepository,
        _festivalRepository = festivalRepository;

  // Getters
  List<Drink> get drinks => _filteredDrinks;
  List<Drink> get allDrinks => _allDrinks;
  List<Festival> get festivals => _festivals;

  /// Get festivals sorted by date (live/upcoming first, then past in reverse chronological order)
  List<Festival> get sortedFestivals => Festival.sortByDate(_festivals);
  Festival get currentFestival =>
      _currentFestival ??
      DefaultFestivals.all.firstWhere((f) => f.isActive,
          orElse: () => DefaultFestivals.all.first);
  bool get isLoading => _isLoading;

  /// True while a background refresh runs with data already on screen.
  bool get isRefreshing => _isRefreshing;
  bool get isFestivalsLoading => _isFestivalsLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Non-null when a background refresh failed but cached drinks remain shown.
  String? get refreshNotice => _refreshNotice;
  String? get festivalsError => _festivalsError;
  String? get selectedCategory => _selectedCategory;
  Set<String> get selectedStyles => _selectedStyles;
  DrinkSort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get hideUnavailable =>
      _visibilityFilters.contains(DrinkVisibilityFilter.availableOnly);
  Set<DrinkVisibilityFilter> get visibilityFilters =>
      Set.unmodifiable(_visibilityFilters);
  Set<String> get excludedAllergens => Set.unmodifiable(_excludedAllergens);
  Set<String> get availableAllergens {
    final allergens = <String>{};
    for (final drink in _allDrinks) {
      allergens.addAll(drink.allergens.keys);
    }
    return allergens;
  }

  bool get hasFestivals => _festivals.isNotEmpty;
  ThemeMode get themeMode => _themeMode;
  DateTime? get lastDrinksRefresh => _lastDrinksRefresh;
  AnalyticsService get analyticsService => _analyticsService;

  /// Get unique categories from loaded drinks
  List<String> get availableCategories {
    final categories = _allDrinks.map((d) => d.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Get unique styles from loaded drinks (filtered by category if selected)
  List<String> get availableStyles {
    var drinks = _allDrinks;

    // If a category is selected, only show styles from that category
    if (_selectedCategory != null) {
      drinks = drinks.where((d) => d.category == _selectedCategory).toList();
    }

    final styles = drinks
        .where((d) => d.style != null && d.style!.isNotEmpty)
        .map((d) => d.style!)
        .toSet()
        .toList();
    styles.sort();
    return styles;
  }

  /// Get drink count by category
  Map<String, int> get categoryCountsMap {
    final counts = <String, int>{};
    for (final drink in _allDrinks) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get drink count by style
  Map<String, int> get styleCountsMap {
    var drinks = _allDrinks;

    // If a category is selected, only count styles from that category
    if (_selectedCategory != null) {
      drinks = drinks.where((d) => d.category == _selectedCategory).toList();
    }

    final counts = <String, int>{};
    for (final drink in drinks) {
      if (drink.style != null && drink.style!.isNotEmpty) {
        counts[drink.style!] = (counts[drink.style!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Get favorite drinks
  List<Drink> get favoriteDrinks =>
      _allDrinks.where((d) => d.isFavorite).toList();

  /// Check if a festival ID is valid (exists in the registry)
  bool isValidFestivalId(String? festivalId) {
    if (festivalId == null || festivalId.isEmpty) return false;
    return _festivals.any((f) => f.id == festivalId);
  }

  /// Get a festival by ID, or null if not found
  Festival? getFestivalById(String festivalId) {
    try {
      return _festivals.firstWhere((f) => f.id == festivalId);
    } catch (e) {
      return null;
    }
  }

  /// Check if drinks data is stale and should be refreshed
  bool get isDrinksDataStale {
    if (_lastDrinksRefresh == null) return true;
    return DateTime.now().difference(_lastDrinksRefresh!) >
        _drinksStalenessThreshold;
  }

  /// Check if festivals data is stale and should be refreshed
  bool get isFestivalsDataStale {
    if (_lastFestivalsRefresh == null) return true;
    return DateTime.now().difference(_lastFestivalsRefresh!) >
        _festivalsStalenessThreshold;
  }

  /// Initialize with SharedPreferences and load festivals
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Create repositories if not provided
    if (_drinkRepository == null) {
      final favoritesService = FavoritesService(prefs);
      final ratingsService = RatingsService(prefs);
      final tastingLogService = TastingLogService(prefs);
      final apiService = BeerApiService();
      final drinkCacheService = DrinkCacheService(prefs);
      _drinkRepository = ApiDrinkRepository(
        apiService: apiService,
        favoritesService: favoritesService,
        ratingsService: ratingsService,
        tastingLogService: tastingLogService,
        cacheService: drinkCacheService,
        analyticsService: _analyticsService,
      );
    }

    if (_festivalRepository == null) {
      final festivalService = FestivalService();
      final festivalStorageService = FestivalStorageService(prefs);
      final festivalCacheService = FestivalCacheService(prefs);
      _festivalRepository = ApiFestivalRepository(
        festivalService: festivalService,
        festivalStorageService: festivalStorageService,
        cacheService: festivalCacheService,
        analyticsService: _analyticsService,
      );
    }

    // Load theme mode preference
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load visibility filter preferences (with migration from legacy hideUnavailable key)
    _visibilityFilters = {};
    final savedFilters = prefs.getStringList('visibilityFilters');
    if (savedFilters != null) {
      for (final name in savedFilters) {
        final filter = DrinkVisibilityFilter.values
            .where((f) => f.name == name)
            .firstOrNull;
        if (filter != null) _visibilityFilters.add(filter);
      }
    } else {
      // Migrate from legacy 'hideUnavailable' boolean preference
      if (prefs.getBool('hideUnavailable') ?? false) {
        _visibilityFilters.add(DrinkVisibilityFilter.availableOnly);
      }
    }

    // Load excluded allergens preference
    _excludedAllergens =
        Set.from(prefs.getStringList('excludedAllergens') ?? []);

    // Populate festivals from cache so the switcher works offline and we can
    // resolve the saved selection without waiting on the network.
    final cachedFestivals = await _festivalRepository!.getCachedFestivals();
    if (cachedFestivals != null) {
      _festivals = cachedFestivals.festivals;
    } else {
      // First launch (nothing cached): we have nothing to show until the
      // registry loads, so block on it as before.
      await loadFestivals();
    }

    // Restore previously selected festival if available, matching against the
    // (cached or freshly loaded) registry first, then the built-in defaults.
    final savedFestivalId = await _festivalRepository!.getSelectedFestivalId();
    if (savedFestivalId != null) {
      _currentFestival =
          _festivals.where((f) => f.id == savedFestivalId).firstOrNull ??
              DefaultFestivals.all
                  .where((f) => f.id == savedFestivalId)
                  .firstOrNull;
    }
    if (_currentFestival == null && cachedFestivals?.defaultFestival != null) {
      _currentFestival = cachedFestivals!.defaultFestival;
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
      _festivals = response.festivals;

      // Set default festival if not already set
      if (_currentFestival == null && response.defaultFestival != null) {
        _currentFestival = response.defaultFestival;
      }

      _festivalsError = null;
      _lastFestivalsRefresh = DateTime.now();
    } catch (e) {
      // Fall back to cached festivals so the switcher keeps working offline
      // instead of emptying the list and blocking the app.
      final cached = await _festivalRepository?.getCachedFestivals();
      if (cached != null && cached.festivals.isNotEmpty) {
        _festivals = cached.festivals;
        if (_currentFestival == null && cached.defaultFestival != null) {
          _currentFestival = cached.defaultFestival;
        }
        _festivalsError = null;
      } else {
        _festivalsError = _getUserFriendlyErrorMessage(e);
        _festivals = [];
      }
    } finally {
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
    if (_currentFestival == null) {
      // Wait for festivals to be loaded first
      if (_festivals.isEmpty) {
        await loadFestivals();
      }
      _currentFestival ??= DefaultFestivals.all.firstWhere((f) => f.isActive,
          orElse: () => DefaultFestivals.all.first);
    }

    final festival = currentFestival;
    final token = ++_drinksLoadToken;

    // Phase 1: render cached data instantly when we have nothing in memory.
    if (_allDrinks.isEmpty) {
      final cached = await _drinkRepository!.getCachedDrinks(festival);
      if (token != _drinksLoadToken) return;
      if (cached != null) {
        _allDrinks = cached;
        _applyFiltersAndSort();
        _error = null;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
    }
    _refreshNotice = null;
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
    if (_currentFestival?.id == festival.id) return;
    _currentFestival = festival;
    _selectedCategory = null;
    _selectedStyles = {};
    _searchQuery = '';
    // Clear existing drinks and signal the switch immediately so the UI rebuilds
    // against the new festival id; the new festival's cached drinks (if any)
    // replace them below, otherwise the spinner stays up.
    _allDrinks = [];
    _filteredDrinks = [];
    _error = null;
    _refreshNotice = null;
    _isLoading = true;
    _isRefreshing = true;
    final token = ++_drinksLoadToken;
    notifyListeners();

    final cached = await _drinkRepository?.getCachedDrinks(festival);
    if (token != _drinksLoadToken) return;
    if (cached != null) {
      _allDrinks = cached;
      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    }

    await _analyticsService.logFestivalSelected(festival);

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
      _allDrinks = drinks;
      _applyFiltersAndSort();
      _error = null;
      _refreshNotice = null;
      _lastDrinksRefresh = DateTime.now();
    } catch (e, stackTrace) {
      if (token != _drinksLoadToken) return;
      final haveData = _allDrinks.isNotEmpty;
      if (haveData) {
        // Keep showing cached data; surface a quiet, dismissible notice.
        _refreshNotice = 'Showing saved data — couldn\'t refresh.';
        _error = null;
      } else {
        _error = _getUserFriendlyErrorMessage(e);
        _allDrinks = [];
        _filteredDrinks = [];
      }
      // Log to Crashlytics unless this is an expected offline failure that we
      // already covered with cached data. Always log when fully blocked, and
      // always log non-connectivity failures so a silent never-load bug
      // (e.g. a server or parsing error masked by the cache) still surfaces.
      if (!haveData || !_isConnectivityError(e)) {
        await _analyticsService.logError(
          e,
          stackTrace,
          reason: 'Failed to load drinks for festival: ${festival.id}',
        );
      }
    } finally {
      if (token == _drinksLoadToken) {
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
    // Don't refresh if already loading
    if (_isLoading || _isFestivalsLoading) return;

    // Refresh festivals if stale
    if (isFestivalsDataStale) {
      await loadFestivals();
    }

    // Refresh drinks if stale
    if (isDrinksDataStale) {
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
    _selectedCategory = category;
    // Clear style filter when changing category since styles are category-dependent
    if (_selectedStyles.isNotEmpty) {
      _selectedStyles = {};
    }
    _applyFiltersAndSort();
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logCategoryFilter(category));
  }

  /// Toggle a style filter (supports multiple style selection)
  void toggleStyle(String style) {
    if (_selectedStyles.contains(style)) {
      _selectedStyles = Set.from(_selectedStyles)..remove(style);
    } else {
      _selectedStyles = Set.from(_selectedStyles)..add(style);
    }
    _applyFiltersAndSort();
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logStyleFilter(_selectedStyles));
  }

  /// Clear all style filters
  void clearStyles() {
    _selectedStyles = {};
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Set sort option
  void setSort(DrinkSort sort) {
    _currentSort = sort;
    _applyFiltersAndSort();
    notifyListeners();
    // Log analytics event (fire and forget)
    unawaited(_analyticsService.logSortChange(sort.name));
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFiltersAndSort();
    notifyListeners();
    // Log analytics event if query is not empty (fire and forget)
    if (query.trim().isNotEmpty) {
      unawaited(_analyticsService.logSearch(query));
    }
  }

  /// Toggle showing favorites only
  void setShowFavoritesOnly(bool value) {
    _showFavoritesOnly = value;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Toggle hiding unavailable drinks and persist preference
  ///
  /// Convenience wrapper around [setVisibilityFilter] for backward compatibility.
  Future<void> setHideUnavailable(bool value) =>
      setVisibilityFilter(DrinkVisibilityFilter.availableOnly, value);

  /// Set a visibility filter on or off and persist the preference
  Future<void> setVisibilityFilter(
      DrinkVisibilityFilter filter, bool active) async {
    if (active) {
      _visibilityFilters = Set.from(_visibilityFilters)..add(filter);
    } else {
      _visibilityFilters = Set.from(_visibilityFilters)..remove(filter);
    }
    _applyFiltersAndSort();
    notifyListeners();

    // Persist the full set of active filters
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'visibilityFilters',
      _visibilityFilters.map((f) => f.name).toList(),
    );
  }

  /// Clear all visibility filters and persist
  Future<void> clearVisibilityFilters() async {
    _visibilityFilters = {};
    _applyFiltersAndSort();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visibilityFilters', []);
  }

  /// Toggle a per-allergen exclusion filter and persist
  Future<void> setAllergenFilter(String allergen, bool active) async {
    if (active) {
      _excludedAllergens = Set.from(_excludedAllergens)..add(allergen);
    } else {
      _excludedAllergens = Set.from(_excludedAllergens)..remove(allergen);
    }
    _applyFiltersAndSort();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('excludedAllergens', _excludedAllergens.toList());
  }

  /// Clear all allergen exclusion filters and persist
  Future<void> clearAllergenFilters() async {
    _excludedAllergens = {};
    _applyFiltersAndSort();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('excludedAllergens', []);
  }

  /// Set theme mode and persist preference
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    // Persist the preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  /// Toggle favorite status for a drink
  Future<void> toggleFavorite(Drink drink) async {
    if (_drinkRepository == null) return;

    final newStatus = await _drinkRepository!.toggleFavorite(
      currentFestival.id,
      drink.id,
    );
    drink.isFavorite = newStatus;

    if (_showFavoritesOnly) {
      _applyFiltersAndSort();
    }

    notifyListeners();

    // Log analytics event (fire and forget)
    if (newStatus) {
      unawaited(_analyticsService.logFavoriteAdded(drink));
    } else {
      unawaited(_analyticsService.logFavoriteRemoved(drink));
    }
  }

  /// Set rating for a drink (1-5), or clear it with null
  Future<void> setRating(Drink drink, int? rating) async {
    if (_drinkRepository == null) return;

    if (rating == null) {
      await _drinkRepository!.removeRating(
        currentFestival.id,
        drink.id,
      );
      drink.rating = null;
    } else {
      await _drinkRepository!.setRating(
        currentFestival.id,
        drink.id,
        rating,
      );
      drink.rating = rating;
      // Log analytics event for rating (fire and forget)
      unawaited(_analyticsService.logRatingGiven(drink, rating));
    }
    notifyListeners();
  }

  /// Toggle tasted status for a drink
  Future<void> toggleTasted(Drink drink) async {
    if (_drinkRepository == null) return;

    final newStatus = await _drinkRepository!.toggleTasted(
      currentFestival.id,
      drink.id,
    );
    drink.isTasted = newStatus;

    // Re-filter so the drink appears/disappears immediately when the
    // not-tasted visibility filter is active.
    if (_visibilityFilters.contains(DrinkVisibilityFilter.notTasted)) {
      _applyFiltersAndSort();
    }

    notifyListeners();

    // Log analytics event
    if (newStatus) {
      unawaited(analyticsService.logTastedAdded(drink));
    } else {
      unawaited(analyticsService.logTastedRemoved(drink));
    }
  }

  /// Get a drink by ID
  Drink? getDrinkById(String id) {
    try {
      return _allDrinks.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  void _applyFiltersAndSort() {
    // Apply all filters using domain service (returns new list)
    final filtered = _filterService.filterDrinks(
      _allDrinks,
      category: _selectedCategory,
      styles: _selectedStyles,
      favoritesOnly: _showFavoritesOnly,
      visibilityFilters: _visibilityFilters,
      excludedAllergens: _excludedAllergens,
      searchQuery: _searchQuery,
    );

    // Apply sort using domain service (returns new sorted list)
    _filteredDrinks = _sortService.sortDrinks(filtered, _currentSort);
  }

  @override
  void dispose() {
    // Note: Repositories own their services and manage lifecycle
    super.dispose();
  }
}
