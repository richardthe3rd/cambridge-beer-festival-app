import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

/// Main screen showing the list of drinks
class DrinksScreen extends StatefulWidget {
  const DrinksScreen({super.key});

  @override
  State<DrinksScreen> createState() => _DrinksScreenState();
}

class _DrinksScreenState extends State<DrinksScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadDrinks(),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    title: Text(provider.currentFestival.name),
                    actions: [
                      _buildInfoButton(context),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: SafeArea(
                        child: Column(
                          children: [
                            const SizedBox(height: 56), // AppBar height
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: _buildFestivalHeader(context, provider),
                            ),
                            _buildFestivalBanner(context, provider),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildInfoButton(BuildContext context) {
    return Semantics(
      label: 'About app',
      hint: 'Double tap to view app information and version',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: 'About',
        onPressed: () {
          context.go('/about');
        },
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
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => provider.setSearchQuery(value),
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
            child: _FilterButton(
              label: provider.selectedCategory ?? 'Category',
              semanticLabel: provider.selectedCategory != null
                  ? 'Filter by category: ${provider.selectedCategory}'
                  : 'Filter by category',
              icon: Icons.filter_list,
              onPressed: () => _showCategoryFilter(context, provider),
              isActive: provider.selectedCategory != null,
            ),
          ),
          if (hasStyleFilter) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _FilterButton(
                label: styleLabel,
                semanticLabel: provider.selectedStyles.isEmpty
                    ? 'Filter by style'
                    : 'Filter by style: ${provider.selectedStyles.join(", ")}',
                icon: Icons.style,
                onPressed: () => _showStyleFilter(context, provider),
                isActive: provider.selectedStyles.isNotEmpty,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: _FilterButton(
              label: _getSortLabel(provider.currentSort),
              semanticLabel: 'Sort drinks by ${_getSortLabel(provider.currentSort)}',
              icon: Icons.sort,
              onPressed: () => _showSortOptions(context, provider),
              isActive: false,
            ),
          ),
          const SizedBox(width: 6),
          _AvailabilityButton(
            isActive: provider.hideUnavailable,
            onPressed: () {
              provider.setHideUnavailable(!provider.hideUnavailable);
            },
          ),
          const SizedBox(width: 6),
          _SearchButton(
            isActive: _showSearch,
            hasQuery: provider.searchQuery.isNotEmpty,
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
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

  Widget _buildFestivalHeader(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = Festival.getStatusInContext(
      provider.currentFestival,
      provider.sortedFestivals,
    );

    return Semantics(
      label: 'Current festival: ${provider.currentFestival.name}, ${provider.drinks.length} drinks',
      hint: 'Double tap to change festival',
      button: true,
      child: GestureDetector(
        onTap: () => _showFestivalSelector(context, provider),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.festival,
              size: 28,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.currentFestival.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${provider.drinks.length} drinks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (status == FestivalStatus.live) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (status == FestivalStatus.upcoming) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (status == FestivalStatus.mostRecent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'RECENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (status == FestivalStatus.past) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PAST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFestivalBanner(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    final festival = provider.currentFestival;
    
    // Only show banner if festival has dates or location
    if (festival.formattedDates.isEmpty && festival.location == null) {
      return const SizedBox.shrink();
    }

    final semanticLabel = [
      if (festival.formattedDates.isNotEmpty) festival.formattedDates,
      if (festival.location != null) festival.location,
    ].join(', ');

    return Semantics(
      label: 'Festival information: $semanticLabel',
      hint: 'Double tap for more details',
      button: true,
      child: InkWell(
        onTap: () => context.go('/festival-info'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (festival.formattedDates.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            festival.formattedDates,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    if (festival.location != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            festival.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrinksListSliver(BuildContext context, BeerProvider provider) {
    if (provider.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading drinks', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.loadDrinks(),
                child: const Text('Retry'),
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
              const Icon(Icons.local_drink, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No drinks found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Try adjusting your filters'),
              if (provider.selectedCategory != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => provider.setCategory(null),
                  child: const Text('Clear Filters'),
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
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final drink = provider.drinks[index];
            return DrinkCard(
              key: ValueKey(drink.id),
              drink: drink,
              onTap: () => _navigateToDetail(context, drink.id),
              onFavoriteTap: () => provider.toggleFavorite(drink),
            );
          },
          childCount: provider.drinks.length,
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String drinkId) {
    context.go('/drink/$drinkId');
  }

  void _showCategoryFilter(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryFilterSheet(provider: provider),
    );
  }

  void _showStyleFilter(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StyleFilterSheet(provider: provider),
    );
  }

  void _showSortOptions(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SortOptionsSheet(provider: provider),
    );
  }

  void _showFestivalSelector(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FestivalSelectorSheet(provider: provider),
    );
  }

  String _getSortLabel(DrinkSort sort) {
    switch (sort) {
      case DrinkSort.nameAsc:
        return 'Name (A-Z)';
      case DrinkSort.nameDesc:
        return 'Name (Z-A)';
      case DrinkSort.abvHigh:
        return 'ABV (High)';
      case DrinkSort.abvLow:
        return 'ABV (Low)';
      case DrinkSort.brewery:
        return 'Brewery';
      case DrinkSort.style:
        return 'Style';
    }
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final String? semanticLabel;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isActive,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabel = semanticLabel ?? label;
    final semanticHint = isActive ? 'Double tap to clear filter' : 'Double tap to select filter';

    return Semantics(
      label: effectiveLabel,
      hint: semanticHint,
      button: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final bool isActive;
  final bool hasQuery;
  final VoidCallback onPressed;

  const _SearchButton({
    required this.isActive,
    this.hasQuery = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isActive ? 'Close search' : 'Search drinks';
    final hint = isActive ? 'Double tap to close search bar' : 'Double tap to open search bar';

    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          backgroundColor: hasQuery && !isActive
              ? theme.colorScheme.primaryContainer
              : null,
        ),
        child: Icon(
          isActive ? Icons.search_off : Icons.search,
          size: 20,
        ),
      ),
    );
  }
}

class _AvailabilityButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _AvailabilityButton({
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isActive ? 'Show unavailable' : 'Hide unavailable';
    final hint = isActive 
        ? 'Double tap to show sold out and not yet available drinks' 
        : 'Double tap to hide sold out and not yet available drinks';

    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          backgroundColor: isActive
              ? theme.colorScheme.primaryContainer
              : null,
        ),
        child: Icon(
          isActive ? Icons.visibility_off : Icons.visibility,
          size: 20,
        ),
      ),
    );
  }
}

class _CategoryFilterSheet extends StatelessWidget {
  final BeerProvider provider;

  const _CategoryFilterSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = provider.availableCategories;
    final counts = provider.categoryCountsMap;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filter by Category', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<String?>(
                groupValue: provider.selectedCategory,
                onChanged: (value) {
                  provider.setCategory(value);
                  Navigator.pop(context);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Radio<String?>(value: null),
                      title: Text('All (${provider.allDrinks.length})'),
                      onTap: () {
                        provider.setCategory(null);
                        Navigator.pop(context);
                      },
                    ),
                    ...categories.map((category) => ListTile(
                          leading: Radio<String?>(value: category),
                          title: Text('${_formatCategory(category)} (${counts[category] ?? 0})'),
                          onTap: () {
                            provider.setCategory(category);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatCategory(String category) {
    return category
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _SortOptionsSheet extends StatelessWidget {
  final BeerProvider provider;

  const _SortOptionsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort By', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<DrinkSort>(
                groupValue: provider.currentSort,
                onChanged: (value) {
                  if (value != null) {
                    provider.setSort(value);
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DrinkSort.values.map((sort) => ListTile(
                        leading: Radio<DrinkSort>(value: sort),
                        title: Text(_getSortLabel(sort)),
                        onTap: () {
                          provider.setSort(sort);
                          Navigator.pop(context);
                        },
                      )).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getSortLabel(DrinkSort sort) {
    switch (sort) {
      case DrinkSort.nameAsc:
        return 'Name (A-Z)';
      case DrinkSort.nameDesc:
        return 'Name (Z-A)';
      case DrinkSort.abvHigh:
        return 'ABV (High to Low)';
      case DrinkSort.abvLow:
        return 'ABV (Low to High)';
      case DrinkSort.brewery:
        return 'Brewery (A-Z)';
      case DrinkSort.style:
        return 'Style (A-Z)';
    }
  }
}

/// Style filter sheet with checkboxes for multi-select
class _StyleFilterSheet extends StatelessWidget {
  final BeerProvider provider;

  const _StyleFilterSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = provider.availableStyles;
    final styleCounts = provider.styleCountsMap;
    final selectedStyles = provider.selectedStyles;

    // Sort styles: selected first (alphabetically), then unselected (alphabetically)
    final sortedStyles = List<String>.from(styles);
    sortedStyles.sort((a, b) {
      final aSelected = selectedStyles.contains(a);
      final bSelected = selectedStyles.contains(b);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.compareTo(b);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter by Style', style: theme.textTheme.titleLarge),
              if (selectedStyles.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  onPressed: () {
                    provider.clearStyles();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (selectedStyles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedStyles.join(', '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: sortedStyles.map((style) {
                  final count = styleCounts[style] ?? 0;
                  final isSelected = selectedStyles.contains(style);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => provider.toggleStyle(style),
                    title: Text('$style ($count)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FestivalSelectorSheet extends StatelessWidget {
  final BeerProvider provider;

  const _FestivalSelectorSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use dynamically loaded festivals (sorted)
    final festivals = provider.sortedFestivals;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.festival, size: 28),
              const SizedBox(width: 12),
              Text('Select Festival', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a festival to browse its drinks',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isFestivalsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (provider.festivalsError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load festivals',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.festivalsError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => provider.loadFestivals(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (festivals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.festival_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No festivals available',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => provider.loadFestivals(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...festivals.map((festival) => _FestivalCard(
                  festival: festival,
                  sortedFestivals: festivals,
                  isSelected: festival.id == provider.currentFestival.id,
                  onTap: () {
                    provider.setFestival(festival);
                    Navigator.pop(context);
                  },
                  onInfoTap: () {
                    Navigator.pop(context);
                    context.go('/festival-info');
                  },
                )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Enhanced festival card with more information
class _FestivalCard extends StatelessWidget {
  final Festival festival;
  final List<Festival> sortedFestivals;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _FestivalCard({
    required this.festival,
    required this.sortedFestivals,
    required this.isSelected,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = Festival.getStatusInContext(festival, sortedFestivals);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusBadge(status),
                            Expanded(
                              child: Text(
                                festival.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (festival.formattedDates.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                festival.formattedDates,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (festival.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  festival.location!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 24,
                        )
                      else
                        Icon(
                          Icons.radio_button_unchecked,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: onInfoTap,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Festival info',
                      ),
                    ],
                  ),
                ],
              ),
              if (festival.availableBeverageTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: festival.availableBeverageTypes
                      .take(5) // Show max 5 types
                      .map((type) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatBeverageType(type),
                              style: theme.textTheme.labelSmall,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FestivalStatus status) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        Color backgroundColor;
        String label;

        switch (status) {
          case FestivalStatus.live:
            backgroundColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
            label = 'LIVE';
          case FestivalStatus.upcoming:
            backgroundColor = isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2);
            label = 'COMING SOON';
          case FestivalStatus.mostRecent:
            backgroundColor = isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00);
            label = 'MOST RECENT';
          case FestivalStatus.past:
            backgroundColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
            label = 'PAST';
        }

        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  String _formatBeverageType(String type) {
    return type
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

