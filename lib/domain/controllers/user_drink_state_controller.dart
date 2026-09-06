import '../../models/models.dart';

/// Owns in-memory personal state (want-to-try, rating, tasting) keyed by
/// drink ID and provides the mutation helpers used by [BeerProvider].
///
/// Pure application logic: no Flutter, persistence, async, or analytics
/// dependencies, so it can be unit-tested in isolation. [BeerProvider] composes
/// this controller, feeds it the loaded drinks via [setSource], and handles the
/// cross-cutting concerns (persistence, analytics, change notification) around
/// it.
///
/// All mutators are synchronous and side-effect free; callers are responsible
/// for persisting and broadcasting changes.
class UserDrinkStateController {
  final Map<String, UserDrinkState> _states = {};

  /// Replace the internal state map with the personal state from [drinks].
  /// Drinks with null [Drink.userState] are ignored; their entries are absent
  /// from the map (semantically: no user signal recorded).
  void setSource(List<Drink> drinks) {
    _states.clear();
    for (final drink in drinks) {
      if (drink.userState != null) {
        _states[drink.id] = drink.userState!;
      }
    }
  }

  /// Remove all tracked state (called when the user switches festivals or the
  /// catalogue is cleared).
  void clear() => _states.clear();

  // --- Read access ---

  /// Returns the current [UserDrinkState] for [drinkId], or null if there is
  /// no user signal for it.
  UserDrinkState? stateFor(String drinkId) => _states[drinkId];

  /// Whether the drink is flagged as "want to try". Returns false for unknown
  /// IDs.
  bool isFavorite(String drinkId) => _states[drinkId]?.wantToTry ?? false;

  /// The user's 1–5 rating, or null when unrated or for unknown IDs.
  int? ratingFor(String drinkId) => _states[drinkId]?.rating;

  /// Whether the user has at least one tasting event. Returns false for
  /// unknown IDs.
  bool isTasted(String drinkId) => _states[drinkId]?.isTasted ?? false;

  /// Number of tasting events. Returns 0 for unknown IDs.
  int tastingCountFor(String drinkId) => _states[drinkId]?.tastingCount ?? 0;

  // --- Mutators ---

  /// Store [state] directly under [drinkId], bypassing re-computation.
  ///
  /// If [state] is null or [state].isEmpty, the entry is pruned and null is
  /// returned. Use this to propagate state already persisted by the repository,
  /// avoiding a second `clock.now()` call.
  UserDrinkState? apply(String drinkId, UserDrinkState? state) {
    if (state == null) {
      _states.remove(drinkId);
      return null;
    }
    return _apply(drinkId, state);
  }

  // --- Internal helpers ---

  /// Stores [next] under [drinkId] when non-empty; removes the entry when
  /// empty (prune). Returns [next] or null when pruned.
  UserDrinkState? _apply(String drinkId, UserDrinkState next) {
    if (next.isEmpty) {
      _states.remove(drinkId);
      return null;
    }
    _states[drinkId] = next;
    return next;
  }
}
