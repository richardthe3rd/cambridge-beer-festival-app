import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  List<Drink> _allDrinks = [];
  List<Drink> _filteredDrinks = [];
  List<Festival> _festivals = [];
  Festival? _currentFestival;
  bool _isLoading = false;
  bool _isFestivalsLoading = false;
  String? _error;
  String? _festivalsError;
  String? _selectedCategory;
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

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
  DrinkSort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get hasFestivals => _festivals.isNotEmpty;

  /// Get unique categories from loaded drinks
  List<String> get availableCategories {
    final categories = _allDrinks.map((d) => d.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Get drink count by category
  Map<String, int> get categoryCountsMap {
    final counts = <String, int>{};
    for (final drink in _allDrinks) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get favorite drinks
  List<Drink> get favoriteDrinks =>
      _allDrinks.where((d) => d.isFavorite).toList();

  /// Initialize with SharedPreferences and load festivals
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _favoritesService = FavoritesService(prefs);
    _ratingsService = RatingsService(prefs);
    
    // Load festivals dynamically
    await loadFestivals();
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
    _searchQuery = '';
    // Clear existing drinks and show loading state immediately
    _allDrinks = [];
    _filteredDrinks = [];
    _isLoading = true;
    _error = null;
    notifyListeners();
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
    } catch (e) {
      _error = _getUserFriendlyErrorMessage(e);
      _allDrinks = [];
      _filteredDrinks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Convert exceptions to user-friendly error messages
  String _getUserFriendlyErrorMessage(Object error) {
    if (error is BeerApiException) {
      if (error.statusCode == 404) {
        return 'Festival data not found. Please try a different festival.';
      } else if (error.statusCode == 500) {
        return 'Server error. Please try again later.';
      } else if (error.statusCode != null && error.statusCode! >= 400) {
        return 'Could not load drinks. Please try again.';
      } else {
        return 'Could not load drinks. Please check your connection.';
      }
    } else if (error is FestivalServiceException) {
      if (error.statusCode == 404) {
        return 'Festival list not found. Please try again later.';
      } else if (error.statusCode == 500) {
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

  /// Set rating for a drink
  Future<void> setRating(Drink drink, int rating) async {
    if (_ratingsService == null) return;

    await _ratingsService!.setRating(
      currentFestival.id,
      drink.id,
      rating,
    );
    drink.rating = rating;
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
