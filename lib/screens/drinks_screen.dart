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

    // provider.drinks (the filtered list) is a cached field on
    // DrinkFilterController, reassigned only by recompute() — nothing
    // theme/loading-related calls recompute(), so selecting the whole
    // List<Drink> here is safe today. This is an implementation artifact of
    // the controller, not a documented contract.
    final drinks = context.select<BeerProvider, List<Drink>>((p) => p.drinks);
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
    // directly off `provider` inside the builder methods below — safe because
    // that read isn't used as a change-detection comparison.
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
      (p) => p.availableStyles.isNotEmpty,
    );

    final provider = context.read<BeerProvider>();

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
                      child: _buildRefreshStatus(
                        context,
                        provider,
                        hasData: hasData,
                        isRefreshing: isRefreshing,
                        refreshNotice: refreshNotice,
                      ),
                    ),
                    if (_showSearch)
                      SliverToBoxAdapter(
                        child: _buildSearchBar(context, provider),
                      ),
                    _buildDrinksListSliver(
                      context,
                      provider,
                      drinks: drinks,
                      isLoading: isLoading,
                      error: error,
                      searchQuery: searchQuery,
                      selectedCategoriesEmpty: selectedCategoriesEmpty,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls for filtering, sorting, and search - thumb friendly
            _buildBottomControls(
              context,
              provider,
              hasStyleFilter: hasStyleFilter,
              selectedCategoriesEmpty: selectedCategoriesEmpty,
              selectedCategoriesLength: selectedCategoriesLength,
              selectedStylesEmpty: selectedStylesEmpty,
              selectedStylesLength: selectedStylesLength,
              selectedStylesFirst: selectedStylesFirst,
              visibilityFiltersLength: visibilityFiltersLength,
              excludedAllergensLength: excludedAllergensLength,
              currentSort: currentSort,
              searchQuery: searchQuery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: _searchController,
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
              onPressed: () {
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
                provider.setSearchQuery('');
              },
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
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    BeerProvider provider, {
    required bool hasStyleFilter,
    required bool selectedCategoriesEmpty,
    required int selectedCategoriesLength,
    required bool selectedStylesEmpty,
    required int selectedStylesLength,
    required String? selectedStylesFirst,
    required int visibilityFiltersLength,
    required int excludedAllergensLength,
    required DrinkSort currentSort,
    required String searchQuery,
  }) {
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

    // Sort styles before joining so the semantic label announces them in a
    // deterministic order, matching the category filter pattern above.
    final sortedStyles = provider.selectedStyles.toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: FilterButton(
              label: categoryLabel,
              semanticLabel: formattedCategories.isEmpty
                  ? 'Filter by category'
                  : 'Filter by category: ${formattedCategories.join(', ')}',
              icon: Icons.filter_list,
              onPressed: () => showCategoryFilter(context),
              isActive: !selectedCategoriesEmpty,
            ),
          ),
          if (hasStyleFilter) ...[
            const SizedBox(width: 6),
            Expanded(
              child: FilterButton(
                label: styleLabel,
                semanticLabel: sortedStyles.isEmpty
                    ? 'Filter by style'
                    : 'Filter by style: ${sortedStyles.join(', ')}',
                icon: Icons.style,
                onPressed: () => showStyleFilter(context),
                isActive: !selectedStylesEmpty,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: FilterButton(
              label: currentSort.label,
              semanticLabel: 'Sort drinks by ${currentSort.label}',
              icon: Icons.sort,
              onPressed: () => showSortOptions(context),
              isActive: false,
            ),
          ),
          const SizedBox(width: 6),
          VisibilityFilterButton(
            activeCount: visibilityFiltersLength + excludedAllergensLength,
            onPressed: () => showVisibilityFilter(context),
          ),
          const SizedBox(width: 6),
          SearchButton(
            isActive: _showSearch,
            hasQuery: searchQuery.isNotEmpty,
            onPressed: () {
              // Collapsing the search bar clears the query; expanding it does
              // not. As with the clear button, setState keeps only the
              // widget-local fields and the provider call runs after it
              // (issue #526).
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
                provider.setSearchQuery('');
              }
            },
          ),
        ],
      ),
    );
  }

  /// Thin progress bar while a background refresh runs with data on screen, or
  /// a dismissible notice when a refresh failed but cached data remains shown.
  Widget _buildRefreshStatus(
    BuildContext context,
    BeerProvider provider, {
    required bool hasData,
    required bool isRefreshing,
    required String? refreshNotice,
  }) {
    final theme = Theme.of(context);

    if (refreshNotice != null && hasData) {
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
                  refreshNotice,
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
                  onPressed: provider.dismissRefreshNotice,
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

  Widget _buildDrinksListSliver(
    BuildContext context,
    BeerProvider provider, {
    required List<Drink> drinks,
    required bool isLoading,
    required String? error,
    required String searchQuery,
    required bool selectedCategoriesEmpty,
  }) {
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
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Semantics(
                label: 'Retry loading drinks',
                hint: 'Double tap to reload festival data',
                button: true,
                excludeSemantics: true,
                child: ElevatedButton(
                  onPressed: provider.loadDrinks,
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
                    onPressed: () => provider.clearCategories(),
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
            onTap: () => _navigateToDetail(context, drink.id, drink.category),
            onFavoriteTap: () => provider.toggleFavorite(drink),
          );
        }, childCount: drinks.length),
      ),
    );
  }

  void _navigateToDetail(
    BuildContext context,
    String drinkId,
    String category,
  ) {
    navigateToRoute(
      context,
      buildDrinkDetailPath(widget.festivalId, category, drinkId),
    );
  }
}
