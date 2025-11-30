import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Sort options for the drinks list
enum DrinkSort {
  nameAsc,
  nameDesc,
  abvHigh,
  abvLow,
  brewery,
  style,
}

/// Provider for managing beer festival data and state
class BeerProvider extends ChangeNotifier {
  final BeerApiService _apiService;
  final FestivalService _festivalService;
  FavoritesService? _favoritesService;
  RatingsService? _ratingsService;
  FestivalStorageService? _festivalStorageService;

  List<Drink> _allDrinks = [];
  List<Drink> _filteredDrinks = [];
  List<Festival> _festivals = [];
  Festival? _currentFestival;
  bool _isLoading = false;
  bool _isFestivalsLoading = false;
  String? _error;
  String? _festivalsError;
  String? _selectedCategory;
  Set<String> _selectedStyles = {};
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  ThemeMode _themeMode = ThemeMode.system;

  // Timestamp tracking for automatic refresh
  DateTime? _lastDrinksRefresh;
  DateTime? _lastFestivalsRefresh;

  // Staleness thresholds
  static const Duration _drinksStalenessThreshold = Duration(hours: 1);
  static const Duration _festivalsStalenessThreshold = Duration(hours: 24);

  BeerProvider({BeerApiService? apiService, FestivalService? festivalService})
      : _apiService = apiService ?? BeerApiService(),
        _festivalService = festivalService ?? FestivalService();

  // Getters
  List<Drink> get drinks => _filteredDrinks;
  List<Drink> get allDrinks => _allDrinks;
  List<Festival> get festivals => _festivals;
  /// Get festivals sorted by date (live/upcoming first, then past in reverse chronological order)
  List<Festival> get sortedFestivals => Festival.sortByDate(_festivals);
  Festival get currentFestival => _currentFestival ?? DefaultFestivals.cambridge2025;
  bool get isLoading => _isLoading;
  bool get isFestivalsLoading => _isFestivalsLoading;
  String? get error => _error;
  String? get festivalsError => _festivalsError;
  String? get selectedCategory => _selectedCategory;
  Set<String> get selectedStyles => _selectedStyles;
  DrinkSort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get hasFestivals => _festivals.isNotEmpty;
  ThemeMode get themeMode => _themeMode;
  DateTime? get lastDrinksRefresh => _lastDrinksRefresh;

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
    _favoritesService = FavoritesService(prefs);
    _ratingsService = RatingsService(prefs);
    _festivalStorageService = FestivalStorageService(prefs);

    // Load theme mode preference
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load festivals dynamically
    await loadFestivals();

    // Restore previously selected festival if available
    final savedFestivalId = _festivalStorageService!.getSelectedFestivalId();
    if (savedFestivalId != null) {
      final savedFestival = _festivals.where((f) => f.id == savedFestivalId).firstOrNull;
      if (savedFestival != null) {
        _currentFestival = savedFestival;
      }
    }
  }

  /// Load festivals from the API
  Future<void> loadFestivals() async {
    _isFestivalsLoading = true;
    _festivalsError = null;
    notifyListeners();

    try {
      final response = await _festivalService.fetchFestivals();
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
      _allDrinks = await _apiService.fetchAllDrinks(currentFestival);
      _updateFavoriteStatus();
      _updateRatings();
      _applyFiltersAndSort();
      _error = null;
      _lastDrinksRefresh = DateTime.now();
    } catch (e) {
      _error = _getUserFriendlyErrorMessage(e);
      _allDrinks = [];
      _filteredDrinks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change the current festival (drinks loaded lazily on demand)
  Future<void> setFestival(Festival festival) async {
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

    // Persist festival selection
    await _festivalStorageService?.setSelectedFestivalId(festival.id);

    // Load drinks for the new festival (loadDrinks will call notifyListeners when done)
    await _loadDrinksInternal();
  }

  /// Internal method to load drinks without setting initial loading state
  Future<void> _loadDrinksInternal() async {
    try {
      _allDrinks = await _apiService.fetchAllDrinks(currentFestival);
      _updateFavoriteStatus();
      _updateRatings();
      _applyFiltersAndSort();
      _error = null;
      _lastDrinksRefresh = DateTime.now();
    } catch (e) {
      _error = _getUserFriendlyErrorMessage(e);
      _allDrinks = [];
      _filteredDrinks = [];
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
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Toggle showing favorites only
  void setShowFavoritesOnly(bool value) {
    _showFavoritesOnly = value;
    _applyFiltersAndSort();
    notifyListeners();
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
    if (_favoritesService == null) return;

    final newStatus = await _favoritesService!.toggleFavorite(
      currentFestival.id,
      drink.id,
    );
    drink.isFavorite = newStatus;
    
    if (_showFavoritesOnly) {
      _applyFiltersAndSort();
    }
    
    notifyListeners();
  }

  /// Set rating for a drink (1-5), or clear it with null
  Future<void> setRating(Drink drink, int? rating) async {
    if (_ratingsService == null) return;

    if (rating == null) {
      await _ratingsService!.removeRating(
        currentFestival.id,
        drink.id,
      );
      drink.rating = null;
    } else {
      await _ratingsService!.setRating(
        currentFestival.id,
        drink.id,
        rating,
      );
      drink.rating = rating;
    }
    notifyListeners();
  }

  /// Get a drink by ID
  Drink? getDrinkById(String id) {
    try {
      return _allDrinks.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  void _updateFavoriteStatus() {
    if (_favoritesService == null) return;

    final favorites = _favoritesService!.getFavorites(currentFestival.id);
    for (final drink in _allDrinks) {
      drink.isFavorite = favorites.contains(drink.id);
    }
  }

  void _updateRatings() {
    if (_ratingsService == null) return;

    for (final drink in _allDrinks) {
      drink.rating = _ratingsService!.getRating(currentFestival.id, drink.id);
    }
  }

  void _applyFiltersAndSort() {
    var drinks = List<Drink>.from(_allDrinks);

    // Apply category filter
    if (_selectedCategory != null) {
      drinks = drinks.where((d) => d.category == _selectedCategory).toList();
    }

    // Apply style filter (multiple styles with OR logic)
    if (_selectedStyles.isNotEmpty) {
      drinks = drinks.where((d) =>
        d.style != null && _selectedStyles.contains(d.style)
      ).toList();
    }

    // Apply favorites filter
    if (_showFavoritesOnly) {
      drinks = drinks.where((d) => d.isFavorite).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      drinks = drinks.where((d) {
        return d.name.toLowerCase().contains(_searchQuery) ||
            d.breweryName.toLowerCase().contains(_searchQuery) ||
            (d.style?.toLowerCase().contains(_searchQuery) ?? false) ||
            (d.notes?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply sort
    switch (_currentSort) {
      case DrinkSort.nameAsc:
        drinks.sort((a, b) => a.name.compareTo(b.name));
        break;
      case DrinkSort.nameDesc:
        drinks.sort((a, b) => b.name.compareTo(a.name));
        break;
      case DrinkSort.abvHigh:
        drinks.sort((a, b) => b.abv.compareTo(a.abv));
        break;
      case DrinkSort.abvLow:
        drinks.sort((a, b) => a.abv.compareTo(b.abv));
        break;
      case DrinkSort.brewery:
        drinks.sort((a, b) => a.breweryName.compareTo(b.breweryName));
        break;
      case DrinkSort.style:
        drinks.sort((a, b) =>
            (a.style ?? '').compareTo(b.style ?? ''));
        break;
    }

    _filteredDrinks = drinks;
  }

  @override
  void dispose() {
    _apiService.dispose();
    _festivalService.dispose();
    super.dispose();
  }
}
