import '../../models/models.dart';
import '../../utils/string_comparison_helper.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Owns drink filtering, sorting, and search state, and derives the views the
/// UI needs (the filtered list plus category/style/allergen facets).
///
/// Pure application logic: no Flutter, persistence, async, or analytics
/// dependencies, so it can be unit-tested in isolation. [BeerProvider] composes
/// this controller, feeds it the loaded drinks via [setSource], and handles the
/// cross-cutting concerns (persistence, analytics, change notification) around
/// it.
///
/// All mutators are synchronous and side-effect free; callers are responsible
/// for persisting and broadcasting changes.
class DrinkFilterController {
  final DrinkFilterService _filterService;
  final DrinkSortService _sortService;

  DrinkFilterController({
    DrinkFilterService? filterService,
    DrinkSortService? sortService,
  }) : _filterService = filterService ?? DrinkFilterService(),
       _sortService = sortService ?? DrinkSortService();

  List<Drink> _source = [];
  List<Drink> _filtered = [];

  String? _selectedCategory;
  Set<String> _selectedStyles = {};
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  Set<DrinkVisibilityFilter> _visibilityFilters = {};
  Set<String> _excludedAllergens = {};

  // --- Criteria getters ---

  String? get selectedCategory => _selectedCategory;
  Set<String> get selectedStyles => _selectedStyles;
  DrinkSort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  Set<DrinkVisibilityFilter> get visibilityFilters =>
      Set.unmodifiable(_visibilityFilters);
  Set<String> get excludedAllergens => Set.unmodifiable(_excludedAllergens);

  /// Convenience flag mirroring the `availableOnly` visibility filter.
  bool get hideUnavailable =>
      _visibilityFilters.contains(DrinkVisibilityFilter.availableOnly);

  // --- Derived views ---

  /// Drinks after the active filters and sort have been applied.
  List<Drink> get filteredDrinks => _filtered;

  /// Unique categories present in the source drinks, sorted.
  List<String> get availableCategories {
    return _source.map((d) => d.category).toSet().toList()..sort();
  }

  /// Unique styles in the source drinks, narrowed to the selected category when
  /// one is active, sorted case-insensitively (via
  /// [StringComparisonHelper.compareLocaleAware]) so styles order in a stable,
  /// human-friendly way regardless of capitalisation. Presentation consumes
  /// this directly — no sorting in the UI.
  List<String> get availableStyles {
    return _categoryScopedSource()
        .where((d) => d.style != null && d.style!.isNotEmpty)
        .map((d) => d.style!)
        .toSet()
        .toList()
      ..sort(StringComparisonHelper.compareLocaleAware);
  }

  /// Drink count per category across the full source.
  Map<String, int> get categoryCountsMap {
    final counts = <String, int>{};
    for (final drink in _source) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Drink count per style, narrowed to the selected category when one is
  /// active.
  Map<String, int> get styleCountsMap {
    final counts = <String, int>{};
    for (final drink in _categoryScopedSource()) {
      if (drink.style != null && drink.style!.isNotEmpty) {
        counts[drink.style!] = (counts[drink.style!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Every allergen key present across the source drinks.
  Set<String> get availableAllergens {
    final allergens = <String>{};
    for (final drink in _source) {
      allergens.addAll(drink.allergens.keys);
    }
    return allergens;
  }

  // --- Source management ---

  /// Replace the drinks being filtered and recompute the filtered list.
  void setSource(List<Drink> drinks) {
    _source = drinks;
    recompute();
  }

  /// Re-run the filter/sort pipeline against the current source. Use after the
  /// source drinks mutate in place (e.g. favourite/tasted toggles).
  void recompute() {
    final filtered = _filterService.filterDrinks(
      _source,
      category: _selectedCategory,
      styles: _selectedStyles,
      favoritesOnly: _showFavoritesOnly,
      visibilityFilters: _visibilityFilters,
      excludedAllergens: _excludedAllergens,
      searchQuery: _searchQuery,
    );
    _filtered = _sortService.sortDrinks(filtered, _currentSort);
  }

  // --- Mutators (synchronous, no side effects) ---

  /// Set the category filter. Clears any active style filter, since styles are
  /// category-dependent.
  void setCategory(String? category) {
    _selectedCategory = category;
    if (_selectedStyles.isNotEmpty) {
      _selectedStyles = {};
    }
    recompute();
  }

  /// Toggle a single style in the multi-select style filter.
  void toggleStyle(String style) {
    if (_selectedStyles.contains(style)) {
      _selectedStyles = Set.from(_selectedStyles)..remove(style);
    } else {
      _selectedStyles = Set.from(_selectedStyles)..add(style);
    }
    recompute();
  }

  /// Clear all selected styles.
  void clearStyles() {
    _selectedStyles = {};
    recompute();
  }

  /// Set the sort order.
  void setSort(DrinkSort sort) {
    _currentSort = sort;
    recompute();
  }

  /// Set the search query (stored lower-cased to match existing behaviour).
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    recompute();
  }

  /// Toggle the favourites-only filter.
  void setShowFavoritesOnly({required bool value}) {
    _showFavoritesOnly = value;
    recompute();
  }

  /// Turn a visibility filter on or off.
  void setVisibilityFilter(
    DrinkVisibilityFilter filter, {
    required bool active,
  }) {
    if (active) {
      _visibilityFilters = Set.from(_visibilityFilters)..add(filter);
    } else {
      _visibilityFilters = Set.from(_visibilityFilters)..remove(filter);
    }
    recompute();
  }

  /// Clear all visibility filters.
  void clearVisibilityFilters() {
    _visibilityFilters = {};
    recompute();
  }

  /// Turn a per-allergen exclusion on or off.
  void setAllergenFilter(String allergen, {required bool active}) {
    if (active) {
      _excludedAllergens = Set.from(_excludedAllergens)..add(allergen);
    } else {
      _excludedAllergens = Set.from(_excludedAllergens)..remove(allergen);
    }
    recompute();
  }

  /// Clear all allergen exclusions.
  void clearAllergenFilters() {
    _excludedAllergens = {};
    recompute();
  }

  /// Reset the category, style, and search filters (used when switching
  /// festivals). Sort, visibility, and allergen preferences are intentionally
  /// preserved.
  void clearCategoryStyleSearch() {
    _selectedCategory = null;
    _selectedStyles = {};
    _searchQuery = '';
    recompute();
  }

  /// Seed the persisted filter preferences at startup without recomputing
  /// (the source has not been loaded yet at hydration time).
  void hydrate({
    Set<DrinkVisibilityFilter>? visibilityFilters,
    Set<String>? excludedAllergens,
  }) {
    if (visibilityFilters != null) {
      _visibilityFilters = Set.from(visibilityFilters);
    }
    if (excludedAllergens != null) {
      _excludedAllergens = Set.from(excludedAllergens);
    }
  }

  /// Source narrowed to the selected category, or the full source when no
  /// category is selected.
  Iterable<Drink> _categoryScopedSource() {
    if (_selectedCategory == null) return _source;
    return _source.where((d) => d.category == _selectedCategory);
  }
}
