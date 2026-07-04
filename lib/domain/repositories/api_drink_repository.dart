import 'dart:async';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

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

  static const Uuid _uuid = Uuid();

  ApiDrinkRepository({
    required BeerApiService apiService,
    required UserDataStore userDataStore,
    required DrinkCacheService cacheService,
    required AnalyticsService analyticsService,
  }) : _apiService = apiService,
       _userDataStore = userDataStore,
       _cacheService = cacheService,
       _analyticsService = analyticsService;

  /// The drink's tasting entries, oldest first. A tasting is an entry whose
  /// `drinkId` matches (ADR 0006).
  List<LogEntry> _tastingsFor(String festivalId, String drinkId) =>
      _userDataStore
          .readEntries(festivalId)
          .where((e) => e.drinkId == drinkId)
          .toList()
        ..sort((a, b) => a.when.compareTo(b.when));

  /// The drink's most recent tasting, or null when it has none. Drink-level
  /// rating/notes attach here ("your latest").
  LogEntry? _latestTasting(String festivalId, String drinkId) {
    final tastings = _tastingsFor(festivalId, drinkId);
    return tastings.isEmpty ? null : tastings.last;
  }

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
    final want = _userDataStore.readWantToTry(festivalId).contains(drinkId);
    await _userDataStore.setWantToTry(festivalId, drinkId, value: !want);
    return _userDataStore.read(festivalId, drinkId);
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
    // Rating attaches to the most recent tasting ("your latest"); if the drink
    // was never tasted, synthesise a tasting to carry it (ADR 0006).
    final latest = _latestTasting(festivalId, drinkId);
    final entry = latest != null
        ? latest.copyWith(rating: rating)
        : LogEntry(
            id: _uuid.v4(),
            when: DateTime.now(),
            drinkId: drinkId,
            rating: rating,
          );
    await _userDataStore.writeEntry(festivalId, entry);
    return _userDataStore.read(festivalId, drinkId);
  }

  @override
  Future<UserDrinkState?> removeRating(
    String festivalId,
    String drinkId,
  ) async {
    final latest = _latestTasting(festivalId, drinkId);
    // No tasting carries a rating — nothing to clear. The tasting stays; a
    // tasting is a real event, removed only by an explicit delete (ADR 0006).
    if (latest != null) {
      await _userDataStore.writeEntry(
        festivalId,
        latest.copyWith(rating: null),
      );
    }
    return _userDataStore.read(festivalId, drinkId);
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
    // Binary toggle preserves the prior single-timestamp behaviour: tasting a
    // fresh drink records one event; toggling off clears the tasting log.
    // (Multi-tasting capture is #415, built on addTasting/removeTasting.)
    final tastings = _tastingsFor(festivalId, drinkId);
    if (tastings.isEmpty) {
      await _userDataStore.writeEntry(
        festivalId,
        LogEntry(id: _uuid.v4(), when: DateTime.now(), drinkId: drinkId),
      );
    } else {
      for (final tasting in tastings) {
        await _userDataStore.removeEntry(festivalId, tasting.id);
      }
    }
    return _userDataStore.read(festivalId, drinkId);
  }

  @override
  Future<UserDrinkState?> addTasting(
    String festivalId,
    String drinkId, {
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    // Consecutive rapid taps intentionally append duplicate events rather than
    // debouncing: v1 ships a per-timestamp delete UI to recover from accidents,
    // and a debounce would add hidden temporal state (#411). Each tasting is a
    // distinct entry with its own id, so identical timestamps stay distinct.
    await _userDataStore.writeEntry(
      festivalId,
      LogEntry(id: _uuid.v4(), when: timestamp, drinkId: drinkId),
    );
    return _userDataStore.read(festivalId, drinkId);
  }

  @override
  Future<UserDrinkState?> removeTasting(
    String festivalId,
    String drinkId,
    DateTime event,
  ) async {
    final tastings = _tastingsFor(festivalId, drinkId);
    if (tastings.isEmpty) return null;
    // Removes the first matching pour; identical timestamps are distinct pours,
    // so only one goes. Leaves the state untouched when the event is absent.
    final match = tastings.firstWhereOrNull((e) => e.when == event);
    if (match != null) {
      await _userDataStore.removeEntry(festivalId, match.id);
    }
    return _userDataStore.read(festivalId, drinkId);
  }

  @override
  Future<UserDrinkState?> setUserNotes(
    String festivalId,
    String drinkId,
    String? notes,
  ) async {
    // Blank is not a distinct signal from "no note": store it as null so the
    // null-means-unset convention holds.
    final normalised = (notes == null || notes.isEmpty) ? null : notes;
    final latest = _latestTasting(festivalId, drinkId);
    if (latest != null) {
      // Notes attach to the most recent tasting ("your latest", ADR 0006).
      await _userDataStore.writeEntry(
        festivalId,
        latest.copyWith(note: normalised),
      );
    } else if (normalised != null) {
      // Noting a never-tasted drink synthesises a tasting to carry the note.
      await _userDataStore.writeEntry(
        festivalId,
        LogEntry(
          id: _uuid.v4(),
          when: DateTime.now(),
          drinkId: drinkId,
          note: normalised,
        ),
      );
    }
    return _userDataStore.read(festivalId, drinkId);
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
