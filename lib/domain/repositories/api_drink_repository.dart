import '../../models/models.dart';
import '../../services/services.dart';
import 'drink_repository.dart';

/// Implementation of DrinkRepository using API services
///
/// Delegates to BeerApiService, FavoritesService, and RatingsService.
class ApiDrinkRepository implements DrinkRepository {
  final BeerApiService _apiService;
  final FavoritesService _favoritesService;
  final RatingsService _ratingsService;

  ApiDrinkRepository({
    required BeerApiService apiService,
    required FavoritesService favoritesService,
    required RatingsService ratingsService,
  })  : _apiService = apiService,
        _favoritesService = favoritesService,
        _ratingsService = ratingsService;

  @override
  Future<List<Drink>> getDrinks(Festival festival) async {
    final drinks = await _apiService.fetchAllDrinks(festival);

    // Populate favorite status and ratings in a single pass
    final favorites = _favoritesService.getFavorites(festival.id);
    for (final drink in drinks) {
      drink.isFavorite = favorites.contains(drink.id);
      drink.rating = _ratingsService.getRating(festival.id, drink.id);
    }

    return drinks;
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
}
