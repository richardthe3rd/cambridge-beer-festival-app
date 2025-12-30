import '../../models/models.dart';

/// Service for filtering drinks based on various criteria
///
/// This service contains pure business logic for filtering drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkFilterService {
  /// Filter drinks by category
  ///
  /// Returns all drinks if [category] is null
  List<Drink> filterByCategory(
    List<Drink> drinks,
    String? category,
  ) {
    if (category == null) return drinks;
    return drinks.where((d) => d.category == category).toList();
  }

  /// Filter drinks by styles (multi-select with OR logic)
  ///
  /// Returns all drinks if [styles] is empty
  List<Drink> filterByStyles(
    List<Drink> drinks,
    Set<String> styles,
  ) {
    if (styles.isEmpty) return drinks;
    return drinks
        .where((d) => d.style != null && styles.contains(d.style))
        .toList();
  }

  /// Filter drinks to show only favorites
  ///
  /// Returns all drinks if [favoritesOnly] is false
  List<Drink> filterByFavorites(
    List<Drink> drinks,
    bool favoritesOnly,
  ) {
    if (!favoritesOnly) return drinks;
    return drinks.where((d) => d.isFavorite).toList();
  }

  /// Filter drinks to hide unavailable ones
  ///
  /// Excludes drinks with status 'out' or 'not yet available'
  /// Returns all drinks if [hideUnavailable] is false
  List<Drink> filterByAvailability(
    List<Drink> drinks,
    bool hideUnavailable,
  ) {
    if (!hideUnavailable) return drinks;
    return drinks
        .where((d) =>
            d.availabilityStatus != AvailabilityStatus.out &&
            d.availabilityStatus != AvailabilityStatus.notYetAvailable)
        .toList();
  }

  /// Filter drinks by search query
  ///
  /// Searches across drink name, brewery name, style, and notes
  /// Case-insensitive search
  /// Returns all drinks if [query] is empty
  List<Drink> filterBySearch(
    List<Drink> drinks,
    String query,
  ) {
    if (query.isEmpty) return drinks;
    final lowerQuery = query.toLowerCase();
    return drinks.where((d) {
      return d.name.toLowerCase().contains(lowerQuery) ||
          d.breweryName.toLowerCase().contains(lowerQuery) ||
          (d.style?.toLowerCase().contains(lowerQuery) ?? false) ||
          (d.notes?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Apply all filters to drinks
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
  List<Drink> applyAllFilters(
    List<Drink> drinks, {
    String? category,
    Set<String>? styles,
    bool favoritesOnly = false,
    bool hideUnavailable = false,
    String searchQuery = '',
  }) {
    Iterable<Drink> filtered = drinks;

    // Apply category filter
    if (category != null) {
      filtered = filtered.where((d) => d.category == category);
    }

    // Apply styles filter
    if (styles != null && styles.isNotEmpty) {
      filtered = filtered.where((d) => d.style != null && styles.contains(d.style));
    }

    // Apply favorites filter
    if (favoritesOnly) {
      filtered = filtered.where((d) => d.isFavorite);
    }

    // Apply availability filter
    if (hideUnavailable) {
      filtered = filtered.where((d) =>
          d.availabilityStatus != AvailabilityStatus.out &&
          d.availabilityStatus != AvailabilityStatus.notYetAvailable);
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.name.toLowerCase().contains(lowerQuery) ||
            d.breweryName.toLowerCase().contains(lowerQuery) ||
            (d.style?.toLowerCase().contains(lowerQuery) ?? false) ||
            (d.notes?.toLowerCase().contains(lowerQuery) ?? false);
      });
    }

    // Materialize the result only once at the end
    return filtered.toList();
  }
}
