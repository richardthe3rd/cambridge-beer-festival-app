import '../../models/models.dart';
import '../../utils/string_comparison_helper.dart';
import '../models/models.dart' as domain;

/// Service for sorting drinks based on different criteria
///
/// This service contains pure business logic for sorting drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkSortService {
  /// Sort drinks based on the given sort option
  ///
  /// Returns a new sorted list without modifying the original.
  ///
  /// Text sorts are case-insensitive (via
  /// [StringComparisonHelper.compareCaseInsensitive]), matching how the style
  /// facet and the My Festival list already order themselves. A raw
  /// [String.compareTo] sorts every capitalised value ahead of every lowercase
  /// one, which put a brewery like `d'Achouffe` at the bottom of the list
  /// instead of alphabetically among the Cs and Ds.
  List<Drink> sortDrinks(List<Drink> drinks, domain.DrinkSort sortBy) {
    final sorted = List<Drink>.from(drinks);
    switch (sortBy) {
      case domain.DrinkSort.nameAsc:
        sorted.sort(
          (a, b) =>
              StringComparisonHelper.compareCaseInsensitive(a.name, b.name),
        );
        break;
      case domain.DrinkSort.nameDesc:
        sorted.sort(
          (a, b) =>
              StringComparisonHelper.compareCaseInsensitive(b.name, a.name),
        );
        break;
      case domain.DrinkSort.abvHigh:
        sorted.sort((a, b) => _compareAbv(a.abv, b.abv, descending: true));
        break;
      case domain.DrinkSort.abvLow:
        sorted.sort((a, b) => _compareAbv(a.abv, b.abv, descending: false));
        break;
      case domain.DrinkSort.brewery:
        sorted.sort(
          (a, b) => StringComparisonHelper.compareCaseInsensitive(
            a.breweryName,
            b.breweryName,
          ),
        );
        break;
      case domain.DrinkSort.style:
        sorted.sort(
          (a, b) => StringComparisonHelper.compareCaseInsensitive(
            a.style ?? '',
            b.style ?? '',
          ),
        );
        break;
    }
    return sorted;
  }

  /// Orders two ABVs, keeping drinks of unknown strength at the end of the
  /// list in *both* directions.
  ///
  /// A null ABV means the feed never told us how strong the drink is (#593),
  /// which is not a position on the scale. Sorting it as though it were 0.0
  /// would park every unknown drink at the top of "lowest ABV first",
  /// crowding out the genuinely weak drinks a user picked that sort to find.
  ///
  /// [descending] is a flag rather than the caller swapping the arguments,
  /// because swapping would flip the null branch along with the comparison and
  /// send the unknowns to the *front* of the descending sort.
  static int _compareAbv(double? a, double? b, {required bool descending}) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }
}
