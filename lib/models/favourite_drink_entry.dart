import 'user_drink_state.dart';
import 'drink.dart';

/// A queryable, catalogue-independent entry combining a drink's personal state
/// with its optional hydrated catalogue record.
///
/// This view-model lets the Favourites screen (and, in future, a cross-festival
/// "My Festival" view — see #315) enumerate user-marked drinks regardless of
/// whether the catalogue has finished loading. When [drink] is null the entry
/// is a valid personal-state record that can be displayed as a placeholder;
/// once the catalogue loads, [drink] will be populated and the full card can
/// be rendered.
class FavouriteDrinkEntry {
  /// The drink's identifier within the festival.
  final String drinkId;

  /// The festival this entry belongs to.
  final String festivalId;

  /// The user's full personal state for this drink (favourite status, rating,
  /// tasting log, etc.).
  final UserDrinkState state;

  /// The hydrated catalogue record, or null when the catalogue is not yet
  /// loaded.
  final Drink? drink;

  const FavouriteDrinkEntry({
    required this.drinkId,
    required this.festivalId,
    required this.state,
    required this.drink,
  });

  /// True when the catalogue has been loaded and [drink] is populated.
  bool get isCatalogueLoaded => drink != null;

  /// True when the user has marked this drink as a favourite (want to try).
  bool get isFavorite => state.wantToTry;
}
