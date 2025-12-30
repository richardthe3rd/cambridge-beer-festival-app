import '../../models/models.dart';
import '../../providers/beer_provider.dart';

/// Service for sorting drinks based on different criteria
///
/// This service contains pure business logic for sorting drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkSortService {
  /// Sort drinks based on the given sort option
  ///
  /// Modifies the list in place and returns it for convenience
  List<Drink> sortDrinks(List<Drink> drinks, DrinkSort sortBy) {
    switch (sortBy) {
      case DrinkSort.nameAsc:
        drinks.sort((a, b) => a.name.compareTo(b.name));
        break;
      case DrinkSort.nameDesc:
        drinks.sort((a, b) => b.name.compareTo(a.name));
        break;
      case DrinkSort.abvHigh:
        drinks.sort((a, b) => b.abv.compareTo(a.abv));
        break;
      case DrinkSort.abvLow:
        drinks.sort((a, b) => a.abv.compareTo(b.abv));
        break;
      case DrinkSort.brewery:
        drinks.sort((a, b) => a.breweryName.compareTo(b.breweryName));
        break;
      case DrinkSort.style:
        drinks.sort((a, b) => (a.style ?? '').compareTo(b.style ?? ''));
        break;
    }
    return drinks;
  }

  /// Sort drinks by name in ascending order (A-Z)
  List<Drink> sortByNameAsc(List<Drink> drinks) {
    drinks.sort((a, b) => a.name.compareTo(b.name));
    return drinks;
  }

  /// Sort drinks by name in descending order (Z-A)
  List<Drink> sortByNameDesc(List<Drink> drinks) {
    drinks.sort((a, b) => b.name.compareTo(a.name));
    return drinks;
  }

  /// Sort drinks by ABV from highest to lowest
  List<Drink> sortByAbvHigh(List<Drink> drinks) {
    drinks.sort((a, b) => b.abv.compareTo(a.abv));
    return drinks;
  }

  /// Sort drinks by ABV from lowest to highest
  List<Drink> sortByAbvLow(List<Drink> drinks) {
    drinks.sort((a, b) => a.abv.compareTo(b.abv));
    return drinks;
  }

  /// Sort drinks by brewery name alphabetically
  List<Drink> sortByBrewery(List<Drink> drinks) {
    drinks.sort((a, b) => a.breweryName.compareTo(b.breweryName));
    return drinks;
  }

  /// Sort drinks by style alphabetically
  ///
  /// Drinks without a style are sorted to the end
  List<Drink> sortByStyle(List<Drink> drinks) {
    drinks.sort((a, b) => (a.style ?? '').compareTo(b.style ?? ''));
    return drinks;
  }
}
