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
        sorted.sort((a, b) => b.abv.compareTo(a.abv));
        break;
      case domain.DrinkSort.abvLow:
        sorted.sort((a, b) => a.abv.compareTo(b.abv));
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
}
