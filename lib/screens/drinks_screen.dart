import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/models.dart';
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
    final provider = context.watch<BeerProvider>();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadDrinks(),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    title: FestivalHeader(provider: provider),
                    actions: [buildOverflowMenu(context)],
                  ),
                  SliverToBoxAdapter(
                    child: FestivalBanner(
                      provider: provider,
                      festivalId: widget.festivalId,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildRefreshStatus(context, provider),
                  ),
                  if (_showSearch)
                    SliverToBoxAdapter(
                      child: _buildSearchBar(context, provider),
                    ),
                  _buildDrinksListSliver(context, provider),
                ],
              ),
            ),
          ),
          // Bottom controls for filtering, sorting, and search - thumb friendly
          _buildBottomControls(context, provider),
        ],
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
                setState(() {
                  _showSearch = false;
                  _searchController.clear();
                  provider.setSearchQuery('');
                });
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

  Widget _buildBottomControls(BuildContext context, BeerProvider provider) {
    final hasStyleFilter = provider.availableStyles.isNotEmpty;
    final styleLabel = provider.selectedStyles.isEmpty
        ? 'Style'
        : provider.selectedStyles.length == 1
        ? provider.selectedStyles.first
        : '${provider.selectedStyles.length} styles';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: FilterButton(
              label: provider.selectedCategory ?? 'Category',
              semanticLabel: provider.selectedCategory != null
                  ? 'Filter by category: ${provider.selectedCategory}'
                  : 'Filter by category',
              icon: Icons.filter_list,
              onPressed: () => showCategoryFilter(context),
              isActive: provider.selectedCategory != null,
            ),
          ),
          if (hasStyleFilter) ...[
            const SizedBox(width: 6),
            Expanded(
              child: FilterButton(
                label: styleLabel,
                semanticLabel: provider.selectedStyles.isEmpty
                    ? 'Filter by style'
                    : 'Filter by style: ${provider.selectedStyles.join(', ')}',
                icon: Icons.style,
                onPressed: () => showStyleFilter(context),
                isActive: provider.selectedStyles.isNotEmpty,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: FilterButton(
              label: provider.currentSort.label,
              semanticLabel: 'Sort drinks by ${provider.currentSort.label}',
              icon: Icons.sort,
              onPressed: () => showSortOptions(context),
              isActive: false,
            ),
          ),
          const SizedBox(width: 6),
          VisibilityFilterButton(
            activeCount:
                provider.visibilityFilters.length +
                provider.excludedAllergens.length,
            onPressed: () => showVisibilityFilter(context),
          ),
          const SizedBox(width: 6),
          SearchButton(
            isActive: _showSearch,
            hasQuery: provider.searchQuery.isNotEmpty,
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchDebounceTimer?.cancel();
                  _searchController.clear();
                  provider.setSearchQuery('');
                }
              });
            },
          ),
        ],
      ),
    );
  }

  /// Thin progress bar while a background refresh runs with data on screen, or
  /// a dismissible notice when a refresh failed but cached data remains shown.
  Widget _buildRefreshStatus(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    // Test against the unfiltered list so an active filter (favourites only,
    // search query with no matches) doesn't hide the refresh indicator.
    final hasData = provider.allDrinks.isNotEmpty;

    if (provider.refreshNotice != null && hasData) {
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
                  provider.refreshNotice!,
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

    if (provider.isRefreshing && hasData) {
      return Semantics(
        label: 'Refreshing drinks',
        liveRegion: true,
        child: const LinearProgressIndicator(minHeight: 2),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDrinksListSliver(BuildContext context, BeerProvider provider) {
    if (provider.isLoading && provider.drinks.isEmpty) {
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

    if (provider.error != null && provider.drinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading drinks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Semantics(
                label: 'Retry loading drinks',
                hint: 'Double tap to reload festival data',
                button: true,
                excludeSemantics: true,
                child: ElevatedButton(
                  onPressed: () => provider.loadDrinks(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.drinks.isEmpty) {
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
              if (provider.selectedCategory != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Clear category filter',
                  hint: 'Double tap to show all drinks',
                  button: true,
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: () => provider.setCategory(null),
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
          final drink = provider.drinks[index];
          return DrinkCard(
            key: ValueKey(drink.id),
            drink: drink,
            onTap: () => _navigateToDetail(context, drink.id, drink.category),
            onFavoriteTap: () => provider.toggleFavorite(drink),
          );
        }, childCount: provider.drinks.length),
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
