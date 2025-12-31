import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _isFestivalsLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _festivalsError;
  String? _selectedCategory;
  Set<String> _selectedStyles = {};
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  bool _hideUnavailable = false;
  ThemeMode _themeMode = ThemeMode.system;

  // Timestamp tracking for automatic refresh
  DateTime? _lastDrinksRefresh;
  DateTime? _lastFestivalsRefresh;

  // Staleness thresholds
  static const Duration _drinksStalenessThreshold = Duration(hours: 1);
  static const Duration _festivalsStalenessThreshold = Duration(hours: 24);

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
  Festival get currentFestival => _currentFestival ?? DefaultFestivals.cambridge2025;
  bool get isLoading => _isLoading;
  bool get isFestivalsLoading => _isFestivalsLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get festivalsError => _festivalsError;
  String? get selectedCategory => _selectedCategory;
  Set<String> get selectedStyles => _selectedStyles;
  DrinkSort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get hideUnavailable => _hideUnavailable;
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
    return DateTime.now().difference(_lastDrinksRefresh!) > _drinksStalenessThreshold;
  }

  /// Check if festivals data is stale and should be refreshed
  bool get isFestivalsDataStale {
    if (_lastFestivalsRefresh == null) return true;
    return DateTime.now().difference(_lastFestivalsRefresh!) > _festivalsStalenessThreshold;
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
      _drinkRepository = ApiDrinkRepository(
        apiService: apiService,
        favoritesService: favoritesService,
        ratingsService: ratingsService,
        tastingLogService: tastingLogService,
      );
    }

    if (_festivalRepository == null) {
      final festivalService = FestivalService();
      final festivalStorageService = FestivalStorageService(prefs);
      _festivalRepository = ApiFestivalRepository(
        festivalService: festivalService,
        festivalStorageService: festivalStorageService,
      );
    }

    // Load theme mode preference
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load hide unavailable preference
    _hideUnavailable = prefs.getBool('hideUnavailable') ?? false;

    // Load festivals dynamically
    await loadFestivals();

    // Restore previously selected festival if available
    final savedFestivalId = await _festivalRepository!.getSelectedFestivalId();
    if (savedFestivalId != null) {
      final savedFestival = _festivals.where((f) => f.id == savedFestivalId).firstOrNull;
      if (savedFestival != null) {
        _currentFestival = savedFestival;
      }
    }

    _isInitialized = true;
    notifyListeners();
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
      _festivalsError = _getUserFriendlyErrorMessage(e);
      // Don't fall back to hardcoded festivals - show error to user
      _festivals = [];
    } finally {
      _isFestivalsLoading = false;
      notifyListeners();
    }
  }

  /// Load drinks from the current festival
  Future<void> loadDrinks() async {
    if (_currentFestival == null) {
      // Wait for festivals to be loaded first
      if (_festivals.isEmpty) {
        await loadFestivals();
      }
      _currentFestival ??= DefaultFestivals.cambridge2025;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Repository returns drinks with favorites and ratings already populated
      _allDrinks = await _drinkRepository!.getDrinks(currentFestival);
      _applyFiltersAndSort();
      _error = null;
      _lastDrinksRefresh = DateTime.now();
    } catch (e, stackTrace) {
      _error = _getUserFriendlyErrorMessage(e);
      _allDrinks = [];
      _filteredDrinks = [];
      // Log error to Crashlytics
      await _analyticsService.logError(
        e,
        stackTrace,
        reason: 'Failed to load drinks for festival: ${currentFestival.id}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    // Clear existing drinks and show loading state immediately
    _allDrinks = [];
    _filteredDrinks = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Log analytics event
    await _analyticsService.logFestivalSelected(festival);

    // Persist festival selection only if requested
    if (persist) {
      await _festivalRepository?.setSelectedFestivalId(festival.id);
    }

    // Load drinks for the new festival (loadDrinks will call notifyListeners when done)
    await _loadDrinksInternal();
  }

  /// Internal method to load drinks without setting initial loading state
  Future<void> _loadDrinksInternal() async {
    try {
      // Repository returns drinks with favorites and ratings already populated
      _allDrinks = await _drinkRepository!.getDrinks(currentFestival);
      _applyFiltersAndSort();
      _error = null;
      _lastDrinksRefresh = DateTime.now();
    } catch (e, stackTrace) {
      _error = _getUserFriendlyErrorMessage(e);
      _allDrinks = [];
      _filteredDrinks = [];
      // Log error to Crashlytics
      await _analyticsService.logError(
        e,
        stackTrace,
        reason: 'Failed to load drinks internally for festival: ${currentFestival.id}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    } else if (error is SocketException) {
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
  Future<void> setHideUnavailable(bool value) async {
    _hideUnavailable = value;
    _applyFiltersAndSort();
    notifyListeners();

    // Persist the preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideUnavailable', value);
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

    notifyListeners();

    // TODO: Add analytics event for tasting log if needed
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
      hideUnavailable: _hideUnavailable,
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
