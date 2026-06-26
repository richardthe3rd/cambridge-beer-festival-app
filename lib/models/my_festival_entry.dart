import 'user_drink_state.dart';
import 'drink.dart';

/// A queryable, catalogue-independent entry combining a drink's personal state
/// with its optional hydrated catalogue record.
class MyFestivalEntry {
  final String drinkId;
  final String festivalId;
  final UserDrinkState state;
  final Drink? drink;

  const MyFestivalEntry({
    required this.drinkId,
    required this.festivalId,
    required this.state,
    required this.drink,
  });

  bool get isCatalogueLoaded => drink != null;
  bool get isFavorite => state.wantToTry;
}

/// Two-section view of a user's My Festival entries for one festival.
class MyFestivalEntries {
  /// Want-to-try entries, sorted alphabetically by drink name (drinkId as tiebreak).
  final List<MyFestivalEntry> wantToTry;

  /// Tasted entries, sorted by lastTastedAt descending (drinkId as tiebreak).
  final List<MyFestivalEntry> tasted;

  const MyFestivalEntries({required this.wantToTry, required this.tasted});
}
