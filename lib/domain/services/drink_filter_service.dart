import '../../models/models.dart';

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
  /// Optimized method that applies all filters in a single pass:
  /// 1. Category filter
  /// 2. Style filter
  /// 3. Favorites filter
  /// 4. Availability filter
  /// 5. Search filter
  ///
  /// Each filter is only applied if its criteria is active.
  /// Uses Iterable chaining to avoid intermediate list allocations.
  List<Drink> filterDrinks(
    List<Drink> drinks, {
    String? category,
    Set<String>? styles,
    bool favoritesOnly = false,
    bool hideUnavailable = false,
    String searchQuery = '',
  }) {
    Iterable<Drink> result = drinks;

    // Apply category filter
    if (category != null) {
      result = result.where((d) => d.category == category);
    }

    // Apply styles filter
    if (styles != null && styles.isNotEmpty) {
      result = result.where((d) => d.style != null && styles.contains(d.style));
    }

    // Apply favorites filter
    if (favoritesOnly) {
      result = result.where((d) => d.isFavorite);
    }

    // Apply availability filter
    if (hideUnavailable) {
      result = result.where((d) =>
          d.availabilityStatus != AvailabilityStatus.out &&
          d.availabilityStatus != AvailabilityStatus.notYetAvailable);
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      result = result.where((d) {
        return d.name.toLowerCase().contains(lowerQuery) ||
            d.breweryName.toLowerCase().contains(lowerQuery) ||
            (d.style?.toLowerCase().contains(lowerQuery) ?? false) ||
            (d.notes?.toLowerCase().contains(lowerQuery) ?? false);
      });
    }

    // Materialize the result only once at the end
    return result.toList();
  }
}
