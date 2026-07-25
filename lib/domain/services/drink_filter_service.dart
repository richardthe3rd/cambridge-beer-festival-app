import '../../models/models.dart';
import '../models/models.dart';
import 'search_match_service.dart';

/// Service for filtering drinks based on various criteria
///
/// This service contains pure business logic for filtering drinks.
/// It is independent of UI frameworks and can be tested in isolation.
class DrinkFilterService {
  /// Shared source of truth for which fields free-text search covers.
  static const SearchMatchService _searchMatcher = SearchMatchService();

  /// Filter drinks by category
  ///
  /// Returns all drinks if [category] is null
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByCategory(Iterable<Drink> drinks, String? category) {
    if (category == null) return drinks;
    return drinks.where((d) => d.category == category);
  }

  /// Filter drinks by styles (multi-select with OR logic)
  ///
  /// Returns all drinks if [styles] is empty
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByStyles(Iterable<Drink> drinks, Set<String> styles) {
    if (styles.isEmpty) return drinks;
    return drinks.where((d) => d.style != null && styles.contains(d.style));
  }

  /// Filter drinks to show only favorites
  ///
  /// Returns all drinks if [favoritesOnly] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByFavorites(
    Iterable<Drink> drinks, {
    required bool favoritesOnly,
  }) {
    if (!favoritesOnly) return drinks;
    return drinks.where((d) => d.isFavorite);
  }

  /// Filter drinks to hide unavailable ones
  ///
  /// Excludes drinks that are sold out (AvailabilityStatus.out).
  /// Returns all drinks if [hideUnavailable] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByAvailability(
    Iterable<Drink> drinks, {
    required bool hideUnavailable,
  }) {
    if (!hideUnavailable) return drinks;
    return drinks.where((d) => d.availabilityStatus != AvailabilityStatus.out);
  }

  /// Filter drinks to hide ones already tasted
  ///
  /// Returns all drinks if [notTastedOnly] is false
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterByNotTasted(
    Iterable<Drink> drinks, {
    required bool notTastedOnly,
  }) {
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
    Iterable<Drink> drinks, {
    required bool veganOnly,
  }) {
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
      (d) => excludedAllergens.every((a) => (d.allergens[a] ?? 0) == 0),
    );
  }

  /// Filter drinks by search query
  ///
  /// Searches across drink name, brewery name, style, and notes
  /// Case-insensitive search
  /// Returns all drinks if [query] is empty
  /// Uses lazy evaluation - call .toList() to materialize
  Iterable<Drink> filterBySearch(Iterable<Drink> drinks, String query) {
    if (query.isEmpty) return drinks;
    final lowerQuery = query.toLowerCase();
    return drinks.where((d) => _matchesSearch(d, lowerQuery));
  }

  /// Whether a drink matches an already-lowercased search query. Covers the
  /// catalogue fields (name, brewery, style, description) and the user's own
  /// note, so a personal marker like a friend's name finds the drink again.
  ///
  /// Delegates to [SearchMatchService] so the set of searched fields stays in
  /// lock-step with the excerpt/highlighting the UI derives from the same
  /// service.
  bool _matchesSearch(Drink d, String lowerQuery) =>
      _searchMatcher.matches(d, lowerQuery);

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
  /// Each filter is only applied if its criteria is active (each `filterByX`
  /// short-circuits on an inactive criterion).
  ///
  /// Composed from the single-purpose filters above rather than re-testing each
  /// predicate inline: there is exactly one copy of every rule, so a fix to
  /// `filterByAvailability` (say) cannot pass its own unit test while leaving
  /// the list the app actually renders unchanged. Still lazy — the `Iterable`
  /// chain materialises once at the end.
  List<Drink> filterDrinks(
    List<Drink> drinks, {
    String? category,
    Set<String>? styles,
    bool favoritesOnly = false,
    Set<DrinkVisibilityFilter> visibilityFilters = const {},
    Set<String> excludedAllergens = const {},
    String searchQuery = '',
  }) {
    Iterable<Drink> result = filterByCategory(drinks, category);
    result = filterByStyles(result, styles ?? const {});
    result = filterByFavorites(result, favoritesOnly: favoritesOnly);
    result = filterByAvailability(
      result,
      hideUnavailable: visibilityFilters.contains(
        DrinkVisibilityFilter.availableOnly,
      ),
    );
    result = filterByNotTasted(
      result,
      notTastedOnly: visibilityFilters.contains(
        DrinkVisibilityFilter.notTasted,
      ),
    );
    result = filterByVegan(
      result,
      veganOnly: visibilityFilters.contains(DrinkVisibilityFilter.veganOnly),
    );
    result = filterByExcludedAllergens(result, excludedAllergens);
    result = filterBySearch(result, searchQuery);
    return result.toList();
  }
}
