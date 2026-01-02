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

  ApiDrinkRepository({
    required BeerApiService apiService,
    required FavoritesService favoritesService,
    required RatingsService ratingsService,
    required TastingLogService tastingLogService,
  })  : _apiService = apiService,
        _favoritesService = favoritesService,
        _ratingsService = ratingsService,
        _tastingLogService = tastingLogService;

  @override
  Future<List<Drink>> getDrinks(Festival festival) async {
    final drinks = await _apiService.fetchAllDrinks(festival);

    // Populate favorite status, ratings, and tasted status in a single pass
    final favorites = _favoritesService.getFavorites(festival.id);
    for (final drink in drinks) {
      drink.isFavorite = favorites.containsKey(drink.id);
      drink.rating = _ratingsService.getRating(festival.id, drink.id);
      drink.isTasted = _tastingLogService.hasTasted(festival.id, drink.id);
    }

    return drinks;
  }

  @override
  Future<List<String>> getFavorites(String festivalId) async {
    return _favoritesService.getFavorites(festivalId).keys.toList();
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

  @override
  Future<String?> getFavoriteStatus(String festivalId, String drinkId) {
    final item = _favoritesService.getFavoriteItem(festivalId, drinkId);
    return Future.value(item?.status.value);
  }

  @override
  Future<void> markAsTasted(String festivalId, String drinkId) {
    return _favoritesService.markAsTasted(festivalId, drinkId);
  }

  @override
  Future<void> deleteTry(String festivalId, String drinkId, DateTime timestamp) {
    return _favoritesService.deleteTry(festivalId, drinkId, timestamp);
  }

  @override
  Future<int> getTryCount(String festivalId, String drinkId) {
    final item = _favoritesService.getFavoriteItem(festivalId, drinkId);
    return Future.value(item?.tries.length ?? 0);
  }
}
