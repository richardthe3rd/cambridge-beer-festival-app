import 'package:collection/collection.dart';

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
///
/// ## Facet scoping rule
///
/// [availableCategories], [categoryCountsMap], [availableStyles],
/// [styleCountsMap], and [availableAllergens] are all derived by one rule:
/// **a facet is computed from the source with every *other* structural
/// filter applied — but never its own.** Structural filters are category,
/// styles, favourites-only, visibility filters, and excluded allergens. A
/// facet must not narrow itself, or selecting one of its own options would
/// hide its siblings and the list would collapse under the user's finger
/// (e.g. picking one style must not make every other style disappear from
/// the style picker). See [_scopeFor], the single helper all five getters
/// share.
///
/// Two invariants hold for every facet:
/// 1. A currently-selected option is always listed, even when its scoped
///    count is 0 — an active filter (especially an allergen exclusion,
///    which is a safety filter) must never vanish from the UI the user
///    would use to clear it.
/// 2. [availableAllergens] lists only allergens actually present (a
///    non-zero value) in scope, not merely mentioned with a value of 0 in a
///    drink's allergens map — matching
///    [DrinkFilterService.filterByExcludedAllergens]'s own definition of
///    "absent".
///
/// Free-text search is deliberately **excluded** from facet scoping.
/// `drinks_screen.dart` derives `hasStyleFilter` from
/// `provider.hasAvailableStyles` to decide whether to show the Style button
/// in the filter bar; scoping facets by the search query would make that
/// button appear and disappear as the user types.
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

  Set<String> _selectedCategories = {};
  Set<String> _selectedStyles = {};
  DrinkSort _currentSort = DrinkSort.nameAsc;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  Set<DrinkVisibilityFilter> _visibilityFilters = {};
  Set<String> _excludedAllergens = {};

  /// Caches [_scopeFor]'s per-facet result. Every getter sharing a facet key
  /// (e.g. the several consumers of [_Facet.style]) reuses one cached walk
  /// instead of re-running [DrinkFilterService.filterDrinks] over the whole
  /// source each time. Cleared by [_invalidateScopeCache].
  final Map<_Facet, List<Drink>> _scopeCache = {};

  // --- Criteria getters ---

  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
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

  /// Unique categories present in scope (see class doc), sorted naturally.
  /// Every [selectedCategories] entry is always included even if its scoped
  /// count is 0 (invariant 1).
  List<String> get availableCategories {
    final categories = _scopeFor(_Facet.category).map((d) => d.category).toSet()
      ..addAll(_selectedCategories);
    return categories.toList()..sort();
  }

  /// Cheap equivalent of `availableStyles.isNotEmpty`. [availableStyles] is
  /// `scopedStyles.toSet()..addAll(_selectedStyles)`, which is non-empty iff
  /// either operand is non-empty — this checks both without building the
  /// deduped `Set` or sorting it, and short-circuits on the first styled
  /// drink. The scope list itself may still be built on a cache miss
  /// ([DrinkFilterService.filterDrinks] always calls `toList()`), but it is
  /// then reused by every other consumer of this facet.
  bool get hasAvailableStyles =>
      _selectedStyles.isNotEmpty ||
      _scopeFor(
        _Facet.style,
      ).any((d) => d.style != null && d.style!.isNotEmpty);

  /// Unique styles in scope (see class doc), sorted case-insensitively (via
  /// [StringComparisonHelper.compareCaseInsensitive]) so styles order in a
  /// stable, human-friendly way regardless of capitalisation. Every
  /// [selectedStyles] entry is always included even if its scoped count is 0
  /// (invariant 1). Presentation consumes this directly — no sorting in the
  /// UI.
  List<String> get availableStyles {
    final styles =
        _scopeFor(_Facet.style)
            .where((d) => d.style != null && d.style!.isNotEmpty)
            .map((d) => d.style!)
            .toSet()
          ..addAll(_selectedStyles);
    return styles.toList()..sort(StringComparisonHelper.compareCaseInsensitive);
  }

  /// [availableStyles] grouped by category, for presentation as headed
  /// sections in the style filter sheet (issue #318 — a flat, alphabetical
  /// style list mixes styles from unrelated categories, e.g. wine and perry
  /// styles interleaved with beer styles). Built from the same style facet
  /// scope [_scopeFor] already defines — this is not a second scoping rule,
  /// just a different shape of the same scoped data.
  ///
  /// Keys are categories sorted naturally; values are that category's
  /// styles, sorted case-insensitively via
  /// [StringComparisonHelper.compareCaseInsensitive] — matching
  /// [availableStyles]'s own ordering. All ordering lives here, not in the
  /// UI.
  ///
  /// Invariant 1 still applies: a [selectedStyles] entry absent from scope
  /// is still included, grouped under the category it carries in the full,
  /// unfiltered [_source] (falling back to the first source drink with that
  /// style, since scope has none to offer).
  ///
  /// Counts are deliberately not part of this view — read them from
  /// [styleCountsMap], which is scoped identically (per style name, not per
  /// category), so the number shown next to a style always matches what
  /// ticking it actually yields. A style name occurring under two
  /// categories would appear in both groups sharing that one count; this is
  /// verified to be zero occurrences in current festival data, but nothing
  /// here assumes it can't happen.
  Map<String, List<String>> get stylesByCategory {
    final byCategory = <String, Set<String>>{};
    for (final drink in _scopeFor(_Facet.style)) {
      if (drink.style == null || drink.style!.isEmpty) continue;
      byCategory.putIfAbsent(drink.category, () => {}).add(drink.style!);
    }
    for (final style in _selectedStyles) {
      if (byCategory.values.any((styles) => styles.contains(style))) {
        continue;
      }
      final sourceDrink = _source.firstWhereOrNull((d) => d.style == style);
      if (sourceDrink != null) {
        byCategory.putIfAbsent(sourceDrink.category, () => {}).add(style);
      }
    }
    final sortedCategories = byCategory.keys.toList()..sort();
    return {
      for (final category in sortedCategories)
        category: byCategory[category]!.toList()
          ..sort(StringComparisonHelper.compareCaseInsensitive),
    };
  }

  /// Drink count per category, scoped per the class doc. Every entry of
  /// [selectedCategories] with no matches in scope is still present, mapped
  /// to 0 (invariant 1).
  Map<String, int> get categoryCountsMap {
    final counts = <String, int>{};
    for (final drink in _scopeFor(_Facet.category)) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    for (final category in _selectedCategories) {
      counts.putIfAbsent(category, () => 0);
    }
    return counts;
  }

  /// Drink count per style, scoped per the class doc. Every entry of
  /// [selectedStyles] with no matches in scope is still present, mapped to 0
  /// (invariant 1).
  Map<String, int> get styleCountsMap {
    final counts = <String, int>{};
    for (final drink in _scopeFor(_Facet.style)) {
      if (drink.style != null && drink.style!.isNotEmpty) {
        counts[drink.style!] = (counts[drink.style!] ?? 0) + 1;
      }
    }
    for (final style in _selectedStyles) {
      counts.putIfAbsent(style, () => 0);
    }
    return counts;
  }

  /// Allergens actually present (non-zero) on at least one drink in scope
  /// (see class doc and invariant 2), plus every currently
  /// [excludedAllergens] entry even if nothing in scope carries it
  /// (invariant 1) — a ticked allergen exclusion is a safety filter and must
  /// stay visible so the user can untick it.
  Set<String> get availableAllergens {
    final allergens = <String>{};
    for (final drink in _scopeFor(_Facet.allergen)) {
      for (final entry in drink.allergens.entries) {
        if (entry.value != 0) allergens.add(entry.key);
      }
    }
    allergens.addAll(_excludedAllergens);
    return allergens;
  }

  // --- Source management ---

  /// Replace the drinks being filtered and recompute the filtered list.
  void setSource(List<Drink> drinks) {
    _source = drinks;
    recompute();
  }

  /// Re-run the filter/sort pipeline against the current source, reassigning
  /// [_filtered] to a fresh list.
  ///
  /// Called by this controller's own mutators after a filter/sort criterion
  /// changes, and by [setSource]. It is *not* the way to pick up a change to
  /// a drink itself: since #564 nothing mutates the catalogue in place, so a
  /// personal-state write (favourite/rating/tasted/notes) hands over a new
  /// list and must go through [setSource] — a bare [recompute] would re-filter
  /// the stale previous source.
  /// [invalidateScopes] defaults to true so any new mutator is safe without
  /// thinking about it. Pass false only from a mutator that changes a field
  /// [_scopeFor] provably does not read — today just [setSort] and
  /// [setSearchQuery]. Sort order is irrelevant to a facet's membership, and
  /// free-text search is deliberately excluded from facet scoping (see the
  /// class doc), so flushing on those would re-walk the whole source on the
  /// next facet read for nothing — on every keystroke, in the search case.
  void recompute({bool invalidateScopes = true}) {
    if (invalidateScopes) _invalidateScopeCache();
    final filtered = _filterService.filterDrinks(
      _source,
      categories: _selectedCategories,
      styles: _selectedStyles,
      favoritesOnly: _showFavoritesOnly,
      visibilityFilters: _visibilityFilters,
      excludedAllergens: _excludedAllergens,
      searchQuery: _searchQuery,
    );
    _filtered = _sortService.sortDrinks(filtered, _currentSort);
  }

  // --- Mutators (synchronous, no side effects) ---

  /// Toggle a single category in the multi-select category filter.
  ///
  /// Prunes (rather than clears) the style selection: a style survives the
  /// toggle only if it is still present in the style facet's scope under the
  /// *new* category selection (see [_scopeFor] / [availableStyles]). Under
  /// single-select this used to be an unconditional clear, but that is too
  /// destructive for multi-select — e.g. adding "perry" to an existing
  /// "cider" selection would otherwise wipe a cider style the user just
  /// picked, even though it's still relevant to the combined selection.
  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories = Set.from(_selectedCategories)..remove(category);
    } else {
      _selectedCategories = Set.from(_selectedCategories)..add(category);
    }
    _pruneStylesToScope();
    recompute();
  }

  /// Replace the category selection with exactly [category].
  ///
  /// Distinct from [toggleCategory]: this is for entry points that name a
  /// single category as the whole intent — tapping "Cider" on the festival
  /// info overview means "show me the ciders", not "add cider to whatever I
  /// had selected". Prunes styles to the new scope like the other category
  /// mutators, so a style left over from a previous selection can't survive
  /// into a category it doesn't belong to.
  void selectOnlyCategory(String category) {
    _selectedCategories = {category};
    _pruneStylesToScope();
    recompute();
  }

  /// Clear all selected categories.
  void clearCategories() {
    _selectedCategories = {};
    _pruneStylesToScope();
    recompute();
  }

  /// Drop any selected style no longer present in the style facet's current
  /// scope (i.e. under the just-changed category selection). Recomputes
  /// scope directly against `_selectedStyles` rather than [availableStyles]
  /// so it isn't affected by that getter's own invariant-1 re-inclusion of
  /// already-selected styles.
  void _pruneStylesToScope() {
    _invalidateScopeCache();
    if (_selectedStyles.isEmpty) return;
    final scopedStyles = _scopeFor(_Facet.style)
        .where((d) => d.style != null && d.style!.isNotEmpty)
        .map((d) => d.style!)
        .toSet();
    final pruned = _selectedStyles.where(scopedStyles.contains).toSet();
    if (pruned.length != _selectedStyles.length) {
      _selectedStyles = pruned;
    }
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
    recompute(invalidateScopes: false);
  }

  /// Set the search query (stored lower-cased to match existing behaviour).
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    recompute(invalidateScopes: false);
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
    _selectedCategories = {};
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
    _invalidateScopeCache();
    if (visibilityFilters != null) {
      _visibilityFilters = Set.from(visibilityFilters);
    }
    if (excludedAllergens != null) {
      _excludedAllergens = Set.from(excludedAllergens);
    }
  }

  /// Clears the memoised [_scopeFor] results. Must be called from every
  /// place that mutates a field [_scopeFor] reads (source, categories,
  /// styles, favourites-only, visibility filters, excluded allergens)
  /// BEFORE any downstream read of [_scopeFor].
  void _invalidateScopeCache() => _scopeCache.clear();

  /// Source filtered by every structural criterion *except* the one
  /// belonging to [facet] — the single implementation of the facet-scoping
  /// rule documented on the class. Free-text search is intentionally never
  /// applied here (see class doc).
  Iterable<Drink> _scopeFor(_Facet facet) => _scopeCache.putIfAbsent(
    facet,
    () => _filterService.filterDrinks(
      _source,
      categories: facet == _Facet.category ? const {} : _selectedCategories,
      styles: facet == _Facet.style ? const {} : _selectedStyles,
      favoritesOnly: _showFavoritesOnly,
      visibilityFilters: _visibilityFilters,
      excludedAllergens: facet == _Facet.allergen
          ? const {}
          : _excludedAllergens,
      // searchQuery intentionally omitted — see class doc "Facet scoping rule".
    ),
  );
}

/// Which structural criterion a facet getter must not apply to itself. See
/// [DrinkFilterController._scopeFor].
enum _Facet { category, style, allergen }
