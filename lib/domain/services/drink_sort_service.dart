import '../../models/models.dart';
import '../models/models.dart' as domain;

/// Service for sorting drinks based on different criteria
///
/// This service contains pure business logic for sorting drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkSortService {
  /// Sort drinks based on the given sort option
  ///
  /// Modifies the list in place and returns it for convenience
  List<Drink> sortDrinks(List<Drink> drinks, domain.DrinkSort sortBy) {
    switch (sortBy) {
      case domain.DrinkSort.nameAsc:
        drinks.sort((a, b) => a.name.compareTo(b.name));
        break;
      case domain.DrinkSort.nameDesc:
        drinks.sort((a, b) => b.name.compareTo(a.name));
        break;
      case domain.DrinkSort.abvHigh:
        drinks.sort((a, b) => b.abv.compareTo(a.abv));
        break;
      case domain.DrinkSort.abvLow:
        drinks.sort((a, b) => a.abv.compareTo(b.abv));
        break;
      case domain.DrinkSort.brewery:
        drinks.sort((a, b) => a.breweryName.compareTo(b.breweryName));
        break;
      case domain.DrinkSort.style:
        drinks.sort((a, b) => (a.style ?? '').compareTo(b.style ?? ''));
        break;
    }
    return drinks;
  }
}
