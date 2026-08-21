import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/models.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Main screen showing the list of drinks
class DrinksScreen extends StatefulWidget {
  const DrinksScreen({required this.festivalId, super.key});

  final String festivalId;

  @override
  State<DrinksScreen> createState() => _DrinksScreenState();
}

class _DrinksScreenState extends State<DrinksScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  Timer? _searchDebounceTimer;

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => context.read<BeerProvider>().setSearchQuery(value),
    );
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    // setState mutates widget-local state only. The provider call
    // stays outside the closure: notifyListeners() marks watching
    // elements dirty synchronously, and mixing that with an
    // in-progress setState is what produces "setState() or
    // markNeedsBuild() called during build" (issue #526).
    setState(() {
      _showSearch = false;
      _searchController.clear();
    });
    context.read<BeerProvider>().setSearchQuery('');
  }

  void _toggleSearch() {
    // Collapsing the search bar clears the query; expanding it does not. As
    // with the clear button, setState keeps only the widget-local fields and
    // the provider call runs after it (issue #526).
    final isCollapsing = _showSearch;
    if (isCollapsing) {
      _searchDebounceTimer?.cancel();
    }
    setState(() {
      _showSearch = !_showSearch;
      if (isCollapsing) {
        _searchController.clear();
      }
    });
    if (isCollapsing) {
      context.read<BeerProvider>().setSearchQuery('');
    }
  }

  void _navigateToDetail(BuildContext context, Drink drink) {
    navigateToRoute(
      context,
      buildDrinkDetailPath(widget.festivalId, drink.category, drink.id),
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Narrow per-concern selects instead of a bare watch<BeerProvider>() —
    // each select only rebuilds this screen when the specific value it reads
    // actually changes, rather than on every notifyListeners() (e.g. a
    // theme-mode change this screen doesn't render). A single context.read
    // below covers action callbacks, which never need to subscribe to
    // rebuilds.
    //
    // Festival-flash guard: the router schedules setFestival in a post-frame
    // callback, so a URL-driven festival change (cross-festival deep link on a
    // warm app, browser back/forward, the post-init redirect in main.dart)
    // would otherwise render one frame of the previous festival's name and
    // drinks before the provider catches up (issue #397). Keep it first in
    // build(), as in MyFestivalScreen. Festival.== is id-scoped by design, so
    // this selects the id specifically rather than the whole Festival object
    // (selecting the object would swallow an in-place metadata refresh).
    final currentFestivalId = context.select<BeerProvider, String>(
      (p) => p.currentFestival.id,
    );
    if (currentFestivalId != widget.festivalId) {
      return buildLoadingScaffold();
    }

    final currentFestivalName = context.select<BeerProvider, String>(
      (p) => p.currentFestival.name,
    );

    final isLoading = context.select<BeerProvider, bool>((p) => p.isLoading);
    final error = context.select<BeerProvider, String?>((p) => p.error);
    final isRefreshing = context.select<BeerProvider, bool>(
      (p) => p.isRefreshing,
    );
    final refreshNotice = context.select<BeerProvider, String?>(
      (p) => p.refreshNotice,
    );
    // Test against the unfiltered list so an active filter (favourites only,
    // search query with no matches) doesn't hide the refresh indicator.
    final hasData = context.select<BeerProvider, bool>(
      (p) => p.allDrinks.isNotEmpty,
    );
    final searchQuery = context.select<BeerProvider, String>(
      (p) => p.searchQuery,
    );
    final currentSort = context.select<BeerProvider, DrinkSort>(
      (p) => p.currentSort,
    );

    // selectedCategories/visibilityFilters/excludedAllergens each return a
    // fresh Set.unmodifiable(...) wrapper on every call, so a selector on the
    // whole Set always sees "changed" — wasteful, but harmless. Selecting
    // derived primitives keeps those reads able to actually skip.
    //
    // (selectedStyles is different: DrinkFilterController reassigns
    // _selectedStyles to a new Set on every mutation rather than mutating in
    // place, so Dart's identity == makes it genuinely selector-safe as a whole
    // Set. Primitives are used below for consistency, not necessity.)
    //
    // The actual Set contents, needed for the formatted label text, are read
    // directly off `provider` below — safe because that read isn't used as a
    // change-detection comparison.
    final selectedCategoriesLength = context.select<BeerProvider, int>(
      (p) => p.selectedCategories.length,
    );
    final selectedCategoriesEmpty = selectedCategoriesLength == 0;
    final selectedStylesLength = context.select<BeerProvider, int>(
      (p) => p.selectedStyles.length,
    );
    final selectedStylesEmpty = selectedStylesLength == 0;
    final selectedStylesFirst = context.select<BeerProvider, String?>(
      (p) => p.selectedStyles.isEmpty ? null : p.selectedStyles.first,
    );
    final visibilityFiltersLength = context.select<BeerProvider, int>(
      (p) => p.visibilityFilters.length,
    );
    final excludedAllergensLength = context.select<BeerProvider, int>(
      (p) => p.excludedAllergens.length,
    );
    final hasStyleFilter = context.select<BeerProvider, bool>(
      (p) => p.hasAvailableStyles,
    );

    final provider = context.read<BeerProvider>();

    final styleLabel = selectedStylesEmpty
        ? 'Style'
        : selectedStylesLength == 1
        ? selectedStylesFirst!
        : '$selectedStylesLength styles';
    // Formatted and sorted so the screen reader announces the same names a
    // sighted user sees, in a deterministic order (a Set has none). Reads the
    // live Set off `provider` (context.read, not a selector) — the rebuild
    // itself is already gated by the primitive selects above.
    //
    // That gating holds only because every category mutation changes the
    // Set's length: toggleCategory adds or removes exactly one entry, and
    // clearCategories empties it. A bulk setter that swapped one category for
    // another would keep the length identical, fire no select, and leave this
    // label stale — add a content-based select (e.g. the sorted joined names,
    // as _canonicalCategoryFilter already does) if one is ever introduced.
    final formattedCategories =
        provider.selectedCategories
            .map(BeverageTypeHelper.formatBeverageType)
            .toList()
          ..sort();
    final categoryLabel = selectedCategoriesEmpty
        ? 'Category'
        : selectedCategoriesLength == 1
        ? formattedCategories.first
        : '$selectedCategoriesLength categories';
    final categorySemanticLabel = formattedCategories.isEmpty
        ? 'Filter by category'
        : 'Filter by category: ${formattedCategories.join(', ')}';

    // Sorted before joining so the screen reader announces the styles in a
    // deterministic order (a Set has none) — the same reasoning as the
    // category path above, minus the formatting: styles are raw feed strings.
    // Read live off `provider`, not selected: the rebuild is already gated by
    // selectedStylesLength/selectedStylesFirst, and emptiness stays keyed to
    // that gating value so both FilterButton props agree on one source.
    final sortedStyles = provider.selectedStyles.toList()..sort();
    final styleSemanticLabel = selectedStylesEmpty
        ? 'Filter by style'
        : 'Filter by style: ${sortedStyles.join(', ')}';

    return PageTitle(
      pageTitle: currentFestivalName,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.loadDrinks,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      title: const FestivalHeader(),
                      actions: [buildOverflowMenu(context)],
                    ),
                    SliverToBoxAdapter(
                      child: FestivalBanner(festivalId: widget.festivalId),
                    ),
                    SliverToBoxAdapter(
                      child: _RefreshStatus(
                        hasData: hasData,
                        isRefreshing: isRefreshing,
                        refreshNotice: refreshNotice,
                        onDismissNotice: provider.dismissRefreshNotice,
                      ),
                    ),
                    if (_showSearch)
                      SliverToBoxAdapter(
                        child: _SearchBar(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onClear: _clearSearch,
                        ),
                      ),
                    // provider.drinks must be observed by *identity*, not
                    // `==`. DrinkFilterController.recompute() assigns a fresh
                    // _filtered list on every change, but a plain
                    // context.select would compare the two lists with
                    // DeepCollectionEquality, which falls through to each
                    // element's own `==` — and Drink.== is id+festivalId
                    // scoped (drink.dart), so a userState-only write
                    // (rating/favourite/tasted/notes) compares equal and the
                    // rebuild is silently dropped, leaving a stale star chip
                    // on the card (#568). Scoped to this sliver rather than
                    // the whole build() because `drinks` is used only here.
                    Selector<BeerProvider, List<Drink>>(
                      selector: (_, p) => p.drinks,
                      shouldRebuild: (prev, next) => !identical(prev, next),
                      builder: (context, drinks, _) => _DrinksListSliver(
                        drinks: drinks,
                        isLoading: isLoading,
                        error: error,
                        searchQuery: searchQuery,
                        selectedCategoriesEmpty: selectedCategoriesEmpty,
                        onRetry: provider.loadDrinks,
                        onClearFilters: provider.clearCategories,
                        onDrinkTap: (drink) =>
                            _navigateToDetail(context, drink),
                        onFavoriteTap: provider.toggleFavorite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls for filtering, sorting, and search - thumb friendly
            _BottomControls(
              categoryLabel: categoryLabel,
              categorySemanticLabel: categorySemanticLabel,
              categoryActive: !selectedCategoriesEmpty,
              hasStyleFilter: hasStyleFilter,
              styleLabel: styleLabel,
              styleSemanticLabel: styleSemanticLabel,
              styleActive: !selectedStylesEmpty,
              sortLabel: currentSort.label,
              sortSemanticLabel: 'Sort drinks by ${currentSort.label}',
              visibilityActiveCount:
                  visibilityFiltersLength + excludedAllergensLength,
              searchActive: _showSearch,
              searchHasQuery: searchQuery.isNotEmpty,
              onCategoryTap: () => showCategoryFilter(context),
              onStyleTap: () => showStyleFilter(context),
              onSortTap: () => showSortOptions(context),
              onVisibilityTap: () => showVisibilityFilter(context),
              onSearchToggle: _toggleSearch,
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanding search field shown under the app bar while [_showSearch] is
/// true. Purely presentational — the debounce timer and visibility flag it
/// mutates live on [_DrinksScreenState].
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search drinks, breweries, styles...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Semantics(
            label: 'Clear search',
            hint: 'Double tap to clear search and close search bar',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Thumb-friendly row of filter/sort/search controls pinned to the bottom of
/// the screen. All labels and semantic labels are computed by the host from
/// live provider reads (context.select-gated) and handed down as plain
/// strings — see the comment in [_DrinksScreenState.build] this logic moved
/// from for why reading the Sets directly is still safe there.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.categoryLabel,
    required this.categorySemanticLabel,
    required this.categoryActive,
    required this.hasStyleFilter,
    required this.styleLabel,
    required this.styleSemanticLabel,
    required this.styleActive,
    required this.sortLabel,
    required this.sortSemanticLabel,
    required this.visibilityActiveCount,
    required this.searchActive,
    required this.searchHasQuery,
    required this.onCategoryTap,
    required this.onStyleTap,
    required this.onSortTap,
    required this.onVisibilityTap,
    required this.onSearchToggle,
  });

  final String categoryLabel;
  final String categorySemanticLabel;
  final bool categoryActive;
  final bool hasStyleFilter;
  final String styleLabel;
  final String styleSemanticLabel;
  final bool styleActive;
  final String sortLabel;
  final String sortSemanticLabel;
  final int visibilityActiveCount;
  final bool searchActive;
  final bool searchHasQuery;
  final VoidCallback onCategoryTap;
  final VoidCallback onStyleTap;
  final VoidCallback onSortTap;
  final VoidCallback onVisibilityTap;
  final VoidCallback onSearchToggle;

  @override
  Widget build(BuildContext context) {
    // This row is genuinely over-subscribed at phone widths, so its spacing
    // is measured rather than chosen by eye. At 400 logical px the two 48px
    // square buttons, the 8px container padding and the four 4px gaps leave
    // 272px to split between the three FilterButtons. Measured against the
    // real bundled Nunito Sans at labelMedium, each button needs (label +
    // its own 16px padding + either the 18px leading glyph and its 8px gap,
    // or the 16px clear icon and its 2px gap):
    //
    //   category  '2 categories'  106.7px  <- widest, grows with selection
    //   style     '2 styles'       80.7px
    //   sort      'Name (A-Z)'    111.6px  <- cannot fit at any split
    //
    // The flex values below are therefore percentages of that 272px, not
    // arbitrary weights: 40/31/29. Category takes the largest share because
    // its label is the only one that grows with the filter; style takes
    // what it needs; sort takes the remainder. Sort is never active and
    // every DrinkSort label ('ABV (High to Low)') is wider than any share
    // this row can offer, so it ellipsizes by design — it is the right place
    // to take the slack from, and 29% still leaves it more text than it
    // rendered before this split existed.
    //
    // Widening the padding, the gaps, or the type scale spends this budget
    // and the labels start disappearing again (#579), so
    // drinks_screen_filter_bar_layout_test.dart pins the outcome.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: FilterButton(
              label: categoryLabel,
              semanticLabel: categorySemanticLabel,
              icon: Icons.filter_list,
              onPressed: onCategoryTap,
              isActive: categoryActive,
            ),
          ),
          if (hasStyleFilter) ...[
            const SizedBox(width: 4),
            Expanded(
              flex: 31,
              child: FilterButton(
                label: styleLabel,
                semanticLabel: styleSemanticLabel,
                icon: Icons.style,
                onPressed: onStyleTap,
                isActive: styleActive,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Expanded(
            flex: 29,
            child: FilterButton(
              label: sortLabel,
              semanticLabel: sortSemanticLabel,
              icon: Icons.sort,
              onPressed: onSortTap,
              isActive: false,
            ),
          ),
          const SizedBox(width: 4),
          VisibilityFilterButton(
            activeCount: visibilityActiveCount,
            onPressed: onVisibilityTap,
          ),
          const SizedBox(width: 4),
          SearchButton(
            isActive: searchActive,
            hasQuery: searchHasQuery,
            onPressed: onSearchToggle,
          ),
        ],
      ),
    );
  }
}

/// Thin progress bar while a background refresh runs with data on screen, or
/// a dismissible notice when a refresh failed but cached data remains shown.
class _RefreshStatus extends StatelessWidget {
  const _RefreshStatus({
    required this.hasData,
    required this.isRefreshing,
    required this.refreshNotice,
    required this.onDismissNotice,
  });

  final bool hasData;
  final bool isRefreshing;
  final String? refreshNotice;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = refreshNotice;

    if (notice != null && hasData) {
      return Material(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Semantics(
                label: 'Dismiss saved data notice',
                hint: 'Double tap to dismiss',
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  onPressed: onDismissNotice,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRefreshing && hasData) {
      return Semantics(
        label: 'Refreshing drinks',
        liveRegion: true,
        child: const LinearProgressIndicator(minHeight: 2),
      );
    }

    return const SizedBox.shrink();
  }
}

/// The main drinks list sliver: loading spinner, error view, empty state, or
/// the populated [SliverList] of [DrinkCard]s, depending on [isLoading] /
/// [error] / [drinks].
class _DrinksListSliver extends StatelessWidget {
  const _DrinksListSliver({
    required this.drinks,
    required this.isLoading,
    required this.error,
    required this.searchQuery,
    required this.selectedCategoriesEmpty,
    required this.onRetry,
    required this.onClearFilters,
    required this.onDrinkTap,
    required this.onFavoriteTap,
  });

  final List<Drink> drinks;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final bool selectedCategoriesEmpty;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final ValueChanged<Drink> onDrinkTap;
  final ValueChanged<Drink> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && drinks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/app_icon.png', width: 80, height: 80),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (error != null && drinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading drinks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Semantics(
                label: 'Retry loading drinks',
                hint: 'Double tap to reload festival data',
                button: true,
                excludeSemantics: true,
                child: ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (drinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No drinks found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Try adjusting your filters'),
              if (!selectedCategoriesEmpty) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Clear all category filters',
                  hint: 'Double tap to show every category',
                  button: true,
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: onClearFilters,
                    child: const Text('Clear Filters'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final drink = drinks[index];
          return DrinkCard(
            key: ValueKey(drink.id),
            drink: drink,
            searchQuery: searchQuery,
            onTap: () => onDrinkTap(drink),
            onFavoriteTap: () => onFavoriteTap(drink),
          );
        }, childCount: drinks.length),
      ),
    );
  }
}
