import 'dart:async';

import '../../models/models.dart';
import '../../services/services.dart';
import 'drink_repository.dart';

/// Implementation of DrinkRepository using API services
///
/// Delegates catalogue loading to [BeerApiService]/[DrinkCacheService] and all
/// personal state to a [UserDataStore]. Depending on the interface (not the
/// concrete SharedPreferences store) keeps a synced backend a constructor swap.
class ApiDrinkRepository implements DrinkRepository {
  final BeerApiService _apiService;
  final UserDataStore _userDataStore;
  final DrinkCacheService _cacheService;
  final AnalyticsService _analyticsService;

  ApiDrinkRepository({
    required BeerApiService apiService,
    required UserDataStore userDataStore,
    required DrinkCacheService cacheService,
    required AnalyticsService analyticsService,
  }) : _apiService = apiService,
       _userDataStore = userDataStore,
       _cacheService = cacheService,
       _analyticsService = analyticsService;

  /// The current record, or a fresh empty one, ready to be mutated and written.
  UserDrinkState _mutableState(String festivalId, String drinkId) =>
      _userDataStore.read(festivalId, drinkId) ?? UserDrinkState.initial();

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
          reason: 'festival=${festival.id} failed=$nonConnectivityFailed',
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

  /// Hydrate each drink with the user's stored record in a single pass. Reading
  /// the whole festival's state once is cheaper than a lookup per drink.
  void _applyUserState(List<Drink> drinks, String festivalId) {
    final states = _userDataStore.readAll(festivalId);
    for (var i = 0; i < drinks.length; i++) {
      final drink = drinks[i];
      drinks[i] = drink.copyWith(userState: states[drink.id]);
    }
  }

  @override
  Future<List<String>> getFavorites(String festivalId) async {
    return _userDataStore
        .readAll(festivalId)
        .entries
        .where((e) => e.value.wantToTry)
        .map((e) => e.key)
        .toList();
  }

  @override
  Future<UserDrinkState?> toggleFavorite(
    String festivalId,
    String drinkId,
  ) async {
    final current = _mutableState(festivalId, drinkId);
    final persisted = current.copyWith(
      wantToTry: !current.wantToTry,
      updatedAt: DateTime.now(),
    );
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<int?> getRating(String festivalId, String drinkId) async {
    return _userDataStore.read(festivalId, drinkId)?.rating;
  }

  @override
  Future<UserDrinkState?> setRating(
    String festivalId,
    String drinkId,
    int rating,
  ) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(
        rating,
        'rating',
        'Rating must be between 1 and 5 inclusive',
      );
    }
    final current = _mutableState(festivalId, drinkId);
    final persisted = current.copyWith(
      rating: rating,
      updatedAt: DateTime.now(),
    );
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<UserDrinkState?> removeRating(
    String festivalId,
    String drinkId,
  ) async {
    final current = _userDataStore.read(festivalId, drinkId);
    if (current == null) return null;
    final persisted = current.copyWith(rating: null, updatedAt: DateTime.now());
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<bool> hasTasted(String festivalId, String drinkId) async {
    return _userDataStore.read(festivalId, drinkId)?.isTasted ?? false;
  }

  @override
  Future<UserDrinkState?> toggleTasted(
    String festivalId,
    String drinkId,
  ) async {
    final current = _mutableState(festivalId, drinkId);
    final now = DateTime.now();
    // Binary toggle preserves the prior single-timestamp behaviour: tasting a
    // fresh drink records one event; toggling off clears the log. (Recording
    // multiple tastings is feature work tracked in #315.)
    final next = current.isTasted
        ? current.copyWith(tastingEvents: const [], updatedAt: now)
        : current.copyWith(tastingEvents: [now], updatedAt: now);
    await _userDataStore.write(festivalId, drinkId, next);
    return next.isEmpty ? null : next;
  }

  @override
  Future<UserDrinkState?> addTasting(
    String festivalId,
    String drinkId, {
    DateTime? now,
  }) async {
    final current = _mutableState(festivalId, drinkId);
    final timestamp = now ?? DateTime.now();
    // Consecutive rapid taps intentionally append duplicate events rather
    // than debouncing: v1 ships a per-timestamp delete UI to recover from
    // accidents, and a debounce would add hidden temporal state (#411).
    final persisted = current.copyWith(
      tastingEvents: [...current.tastingEvents, timestamp],
      updatedAt: timestamp,
    );
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<UserDrinkState?> removeTasting(
    String festivalId,
    String drinkId,
    DateTime event,
  ) async {
    final current = _userDataStore.read(festivalId, drinkId);
    if (current == null) return null;
    final updated = List<DateTime>.from(current.tastingEvents);
    final index = updated.indexOf(event);
    if (index == -1) return current;
    updated.removeAt(index);
    final persisted = current.copyWith(
      tastingEvents: updated,
      updatedAt: DateTime.now(),
    );
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<UserDrinkState?> setUserNotes(
    String festivalId,
    String drinkId,
    String? notes,
  ) async {
    final current = _mutableState(festivalId, drinkId);
    final persisted = current.copyWith(notes: notes, updatedAt: DateTime.now());
    await _userDataStore.write(festivalId, drinkId, persisted);
    return persisted.isEmpty ? null : persisted;
  }

  @override
  Future<List<String>> getTastedDrinks(String festivalId) async {
    return _userDataStore
        .readAll(festivalId)
        .entries
        .where((e) => e.value.isTasted)
        .map((e) => e.key)
        .toList();
  }

  @override
  Map<String, UserDrinkState> getPersonalEntries(String festivalId) =>
      _userDataStore.readAll(festivalId);

  void dispose() {
    _apiService.dispose();
  }
}
