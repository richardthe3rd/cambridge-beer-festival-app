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
  final AnalyticsService _analyticsService;

  ApiDrinkRepository({
    required BeerApiService apiService,
    required FavoritesService favoritesService,
    required RatingsService ratingsService,
    required TastingLogService tastingLogService,
    required DrinkCacheService cacheService,
    required AnalyticsService analyticsService,
  }) : _apiService = apiService,
       _favoritesService = favoritesService,
       _ratingsService = ratingsService,
       _tastingLogService = tastingLogService,
       _cacheService = cacheService,
       _analyticsService = analyticsService;

  @override
  Future<List<Drink>> getDrinks(Festival festival) async {
    final result = await _apiService.fetchDrinksByType(festival);

    // Nothing loaded at all — surface the error so the provider can keep
    // showing cached data or display an error.
    result.throwIfCompleteFailure();

    // Log partial failures (some types loaded, others didn't) to Crashlytics
    // so we have visibility into recurring per-type errors. Skip logging when
    // every failure is a connectivity issue — those are expected offline
    // behaviour and would only add noise. Also filter out connectivity failures
    // from the log message to avoid misleading reports that mix network timeouts
    // with real data errors.
    final nonConnectivityFailed = result.failedTypes.entries
        .where((e) => !isConnectivityFailure(e.value))
        .map((e) => e.key)
        .toList();
    if (nonConnectivityFailed.isNotEmpty) {
      unawaited(
        _analyticsService.logError(
          Exception('Partial beverage-type fetch failure'),
          null,
          reason: 'festival=${festival.id} failed=[$nonConnectivityFailed]',
        ),
      );
    }

    // Merge the types that succeeded over the cached snapshot, keeping the
    // last-good data for any type that failed to refresh this time. The cache
    // write happens in the background so it stays off the load critical path;
    // route persistence failures through analytics rather than letting them
    // surface as unhandled async errors.
    final update = _cacheService.merge(festival.id, result.drinksByType);
    unawaited(
      update.written.catchError((Object e, StackTrace s) {
        return _analyticsService.logError(
          e,
          s,
          reason: 'Drink cache write failed for festival: ${festival.id}',
        );
      }),
    );

    _applyUserState(update.drinks, festival.id);

    final unknownStatuses = update.drinks
        .where((d) => d.availabilityStatus == AvailabilityStatus.unknown)
        .map((d) => d.statusText)
        .whereType<String>()
        .toSet();
    if (unknownStatuses.isNotEmpty) {
      final sample = unknownStatuses.take(5).join(', ');
      final count = unknownStatuses.length;
      unawaited(
        _analyticsService.logError(
          Exception('Unknown availability status text'),
          null,
          reason: 'festival=${festival.id} count=$count sample=[$sample]',
        ),
      );
    }

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
    for (var i = 0; i < drinks.length; i++) {
      final drink = drinks[i];
      drinks[i] = drink.copyWith(
        isFavorite: favorites.contains(drink.id),
        rating: _ratingsService.getRating(festivalId, drink.id),
        isTasted: _tastingLogService.hasTasted(festivalId, drink.id),
      );
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

  void dispose() {
    _apiService.dispose();
  }
}
