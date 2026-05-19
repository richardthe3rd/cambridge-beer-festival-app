import '../../models/models.dart';
import '../models/models.dart';

/// Service for filtering drinks based on various criteria
///
/// This service contains pure business logic for filtering drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkFilterService {
  /// Filter drinks by category
  ///
  /// Returns all drinks if [category] is null
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByCategory(
    Iterable<Drink> drinks,
    String? category,
  ) {
    if (category == null) return drinks;
    return drinks.where((d) => d.category == category);
  }

  /// Filter drinks by styles (multi-select with OR logic)
  ///
  /// Returns all drinks if [styles] is empty
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByStyles(
    Iterable<Drink> drinks,
    Set<String> styles,
  ) {
    if (styles.isEmpty) return drinks;
    return drinks.where((d) => d.style != null && styles.contains(d.style));
  }

  /// Filter drinks to show only favorites
  ///
  /// Returns all drinks if [favoritesOnly] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByFavorites(
    Iterable<Drink> drinks,
    bool favoritesOnly,
  ) {
    if (!favoritesOnly) return drinks;
    return drinks.where((d) => d.isFavorite);
  }

  /// Filter drinks to hide unavailable ones
  ///
  /// Excludes drinks with status 'out' or 'not yet available'
  /// Returns all drinks if [hideUnavailable] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByAvailability(
    Iterable<Drink> drinks,
    bool hideUnavailable,
  ) {
    if (!hideUnavailable) return drinks;
    return drinks.where((d) =>
        d.availabilityStatus != AvailabilityStatus.out &&
        d.availabilityStatus != AvailabilityStatus.notYetAvailable);
  }

  /// Filter drinks to hide ones already tasted
  ///
  /// Returns all drinks if [notTastedOnly] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByNotTasted(
    Iterable<Drink> drinks,
    bool notTastedOnly,
  ) {
    if (!notTastedOnly) return drinks;
    return drinks.where((d) => !d.isTasted);
  }

  /// Filter drinks to show only vegan ones
  ///
  /// A drink is included if its [Drink.isVegan] flag is explicitly true.
  /// Drinks with null (unknown) vegan status are excluded.
  /// Returns all drinks if [veganOnly] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByVegan(
    Iterable<Drink> drinks,
    bool veganOnly,
  ) {
    if (!veganOnly) return drinks;
    return drinks.where((d) => d.isVegan == true);
  }

  /// Filter drinks to exclude those containing any of the specified allergens
  ///
  /// A drink is excluded if any of the [excludedAllergens] keys maps to a
  /// non-zero value in the drink's allergens map. A missing key or value of 0
  /// means the allergen is absent — the drink passes.
  /// Returns all drinks when [excludedAllergens] is empty.
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByExcludedAllergens(
    Iterable<Drink> drinks,
    Set<String> excludedAllergens,
  ) {
    if (excludedAllergens.isEmpty) return drinks;
    return drinks.where(
        (d) => excludedAllergens.every((a) => (d.allergens[a] ?? 0) == 0));
  }

  /// Filter drinks by search query
  ///
  /// Searches across drink name, brewery name, style, and notes
  /// Case-insensitive search
  /// Returns all drinks if [query] is empty
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterBySearch(
    Iterable<Drink> drinks,
    String query,
  ) {
    if (query.isEmpty) return drinks;
    final lowerQuery = query.toLowerCase();
    return drinks.where((d) {
      return d.name.toLowerCase().contains(lowerQuery) ||
          d.breweryName.toLowerCase().contains(lowerQuery) ||
          (d.style?.toLowerCase().contains(lowerQuery) ?? false) ||
          (d.notes?.toLowerCase().contains(lowerQuery) ?? false);
    });
  }

  /// Filter drinks with multiple criteria
  ///
  /// Applies filters in sequence:
  /// 1. Category filter
  /// 2. Style filter
  /// 3. Favorites filter
  /// 4. Visibility filters (availability, not-tasted, vegan)
  /// 5. Allergen exclusions
  /// 6. Search filter
  ///
  /// Each filter is only applied if its criteria is active.
  /// Uses Iterable chaining to avoid intermediate list allocations.
  List<Drink> filterDrinks(
    List<Drink> drinks, {
    String? category,
    Set<String>? styles,
    bool favoritesOnly = false,
    Set<DrinkVisibilityFilter> visibilityFilters = const {},
    Set<String> excludedAllergens = const {},
    String searchQuery = '',
  }) {
    Iterable<Drink> result = drinks;

    if (category != null) {
      result = result.where((d) => d.category == category);
    }

    if (styles != null && styles.isNotEmpty) {
      result = result.where((d) => d.style != null && styles.contains(d.style));
    }

    if (favoritesOnly) {
      result = result.where((d) => d.isFavorite);
    }

    if (visibilityFilters.contains(DrinkVisibilityFilter.availableOnly)) {
      result = result.where((d) =>
          d.availabilityStatus != AvailabilityStatus.out &&
          d.availabilityStatus != AvailabilityStatus.notYetAvailable);
    }
    if (visibilityFilters.contains(DrinkVisibilityFilter.notTasted)) {
      result = result.where((d) => !d.isTasted);
    }
    if (visibilityFilters.contains(DrinkVisibilityFilter.veganOnly)) {
      result = result.where((d) => d.isVegan == true);
    }

    if (excludedAllergens.isNotEmpty) {
      result = result.where(
          (d) => excludedAllergens.every((a) => (d.allergens[a] ?? 0) == 0));
    }

    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      result = result.where((d) {
        return d.name.toLowerCase().contains(lowerQuery) ||
            d.breweryName.toLowerCase().contains(lowerQuery) ||
            (d.style?.toLowerCase().contains(lowerQuery) ?? false) ||
            (d.notes?.toLowerCase().contains(lowerQuery) ?? false);
      });
    }

    return result.toList();
  }
}
