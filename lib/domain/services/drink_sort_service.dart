import '../../models/models.dart';
import '../models/models.dart' as domain;

/// Service for sorting drinks based on different criteria
///
/// This service contains pure business logic for sorting drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkSortService {
  /// Sort drinks based on the given sort option
  ///
  /// Returns a new sorted list without modifying the original
  List<Drink> sortDrinks(List<Drink> drinks, domain.DrinkSort sortBy) {
    final sorted = List<Drink>.from(drinks);
    switch (sortBy) {
      case domain.DrinkSort.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case domain.DrinkSort.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case domain.DrinkSort.abvHigh:
        sorted.sort((a, b) => b.abv.compareTo(a.abv));
        break;
      case domain.DrinkSort.abvLow:
        sorted.sort((a, b) => a.abv.compareTo(b.abv));
        break;
      case domain.DrinkSort.brewery:
        sorted.sort((a, b) => a.breweryName.compareTo(b.breweryName));
        break;
      case domain.DrinkSort.style:
        sorted.sort((a, b) => (a.style ?? '').compareTo(b.style ?? ''));
        break;
    }
    return sorted;
  }
}
