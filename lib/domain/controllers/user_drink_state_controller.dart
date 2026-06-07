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

  /// Apply a want-to-try toggle to [drinkId]. Creates a fresh record if none
  /// exists. Returns the updated [UserDrinkState], or null when the state
  /// became empty (all fields cleared) and was pruned.
  UserDrinkState? applyWantToTry(
    String drinkId, {
    required bool value,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final base = _states[drinkId] ?? UserDrinkState.initial(now: timestamp);
    return _apply(
      drinkId,
      base.copyWith(wantToTry: value, updatedAt: timestamp),
    );
  }

  /// Apply a rating change (1–5) or clear it (null) for [drinkId]. Creates a
  /// fresh record if none exists. Returns the updated [UserDrinkState], or
  /// null when the state became empty and was pruned.
  UserDrinkState? applyRating(
    String drinkId, {
    required int? rating,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final base = _states[drinkId] ?? UserDrinkState.initial(now: timestamp);
    return _apply(drinkId, base.copyWith(rating: rating, updatedAt: timestamp));
  }

  /// Record or clear a tasting event for [drinkId]. When [tasted] is true,
  /// sets the tasting list to `[now]` (binary toggle — replaces any previous
  /// list rather than appending). When false, clears tasting events entirely.
  /// Returns the updated [UserDrinkState], or null when the state became empty
  /// and was pruned.
  UserDrinkState? applyTasted(
    String drinkId, {
    required bool tasted,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final base = _states[drinkId] ?? UserDrinkState.initial(now: timestamp);
    return _apply(
      drinkId,
      base.copyWith(
        tastingEvents: tasted ? [timestamp] : const [],
        updatedAt: timestamp,
      ),
    );
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
