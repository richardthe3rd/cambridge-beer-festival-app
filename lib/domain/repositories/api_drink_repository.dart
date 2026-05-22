import 'dart:async';

import '../../models/models.dart';
import '../../services/services.dart';
import 'drink_repository.dart';

/// Implementation of DrinkRepository using API services
///
/// Delegates to BeerApiService, FavoritesService, RatingsService, and TastingLogService.
class ApiDrinkRepository implements DrinkRepository {
  final BeerApiService _apiService;
  final FavoritesService _favoritesService;
  final RatingsService _ratingsService;
  final TastingLogService _tastingLogService;
  final DrinkCacheService _cacheService;

  ApiDrinkRepository({
    required BeerApiService apiService,
    required FavoritesService favoritesService,
    required RatingsService ratingsService,
    required TastingLogService tastingLogService,
    required DrinkCacheService cacheService,
  })  : _apiService = apiService,
        _favoritesService = favoritesService,
        _ratingsService = ratingsService,
        _tastingLogService = tastingLogService,
        _cacheService = cacheService;

  @override
  Future<List<Drink>> getDrinks(Festival festival) async {
    final result = await _apiService.fetchDrinksByType(festival);

    // Nothing loaded at all — surface the error so the provider can keep
    // showing cached data or display an error.
    result.throwIfCompleteFailure();

    // Merge the types that succeeded over the cached snapshot, keeping the
    // last-good data for any type that failed to refresh this time. The cache
    // write happens in the background so it stays off the load critical path.
    final update = _cacheService.merge(festival.id, result.drinksByType);
    unawaited(update.written);

    _applyUserState(update.drinks, festival.id);
    return update.drinks;
  }

  @override
  Future<List<Drink>?> getCachedDrinks(Festival festival) async {
    final drinks = _cacheService.read(festival.id);
    if (drinks == null) return null;

    _applyUserState(drinks, festival.id);
    return drinks;
  }

  /// Populate favorite status, ratings, and tasted status in a single pass.
  void _applyUserState(List<Drink> drinks, String festivalId) {
    final favorites = _favoritesService.getFavorites(festivalId);
    for (final drink in drinks) {
      drink.isFavorite = favorites.contains(drink.id);
      drink.rating = _ratingsService.getRating(festivalId, drink.id);
      drink.isTasted = _tastingLogService.hasTasted(festivalId, drink.id);
    }
  }

  @override
  Future<List<String>> getFavorites(String festivalId) async {
    return _favoritesService.getFavorites(festivalId).toList();
  }

  @override
  Future<bool> toggleFavorite(String festivalId, String drinkId) {
    return _favoritesService.toggleFavorite(festivalId, drinkId);
  }

  @override
  Future<int?> getRating(String festivalId, String drinkId) {
    return Future.value(_ratingsService.getRating(festivalId, drinkId));
  }

  @override
  Future<void> setRating(String festivalId, String drinkId, int rating) {
    return _ratingsService.setRating(festivalId, drinkId, rating);
  }

  @override
  Future<void> removeRating(String festivalId, String drinkId) {
    return _ratingsService.removeRating(festivalId, drinkId);
  }

  @override
  Future<bool> hasTasted(String festivalId, String drinkId) {
    return Future.value(_tastingLogService.hasTasted(festivalId, drinkId));
  }

  @override
  Future<bool> toggleTasted(String festivalId, String drinkId) async {
    await _tastingLogService.toggleTasted(festivalId, drinkId);
    return _tastingLogService.hasTasted(festivalId, drinkId);
  }

  @override
  Future<List<String>> getTastedDrinks(String festivalId) {
    return Future.value(_tastingLogService.getTastedDrinkIds(festivalId));
  }
}
