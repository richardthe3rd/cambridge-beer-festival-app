import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'drink_detail_screen.dart';
import 'brewery_screen.dart';
import 'festival_info_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: _buildFestivalHeader(context, provider),
      ),
      body: Column(
        children: [
          _buildFestivalBanner(context, provider),
          if (_showSearch) _buildSearchBar(context, provider),
          Expanded(
            child: _buildDrinksList(context, provider),
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
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _showSearch = false;
                _searchController.clear();
                provider.setSearchQuery('');
              });
            },
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _FilterButton(
                  label: provider.selectedCategory ?? 'All Categories',
                  icon: Icons.filter_list,
                  onPressed: () => _showCategoryFilter(context, provider),
                  isActive: provider.selectedCategory != null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterButton(
                  label: _getSortLabel(provider.currentSort),
                  icon: Icons.sort,
                  onPressed: () => _showSortOptions(context, provider),
                  isActive: false,
                ),
              ),
              const SizedBox(width: 8),
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
        ),
        // Style filter chips
        if (provider.availableStyles.isNotEmpty)
          _StyleFilterChips(provider: provider),
      ],
    );
  }

  Widget _buildFestivalHeader(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    final status = Festival.getStatusInContext(
      provider.currentFestival,
      provider.sortedFestivals,
    );
    
    return GestureDetector(
      onTap: () => _showFestivalSelector(context, provider),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.festival,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.currentFestival.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${provider.drinks.length} drinks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                        color: Colors.green,
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
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'COMING SOON',
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'MOST RECENT',
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
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
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

    return Material(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FestivalInfoScreen(festival: festival),
          ),
        ),
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            festival.formattedDates,
                            style: theme.textTheme.bodySmall,
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            festival.location!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrinksList(BuildContext context, BeerProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
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
      );
    }

    if (provider.drinks.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadDrinks(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: provider.drinks.length,
        itemBuilder: (context, index) {
          final drink = provider.drinks[index];
          return DrinkCard(
            drink: drink,
            onTap: () => _navigateToDetail(context, drink.id),
            onFavoriteTap: () => provider.toggleFavorite(drink),
            onBreweryTap: () => _navigateToBrewery(context, drink.producer.id),
          );
        },
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String drinkId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrinkDetailScreen(drinkId: drinkId),
      ),
    );
  }

  void _navigateToBrewery(BuildContext context, String breweryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BreweryScreen(breweryId: breweryId),
      ),
    );
  }

  void _showCategoryFilter(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CategoryFilterSheet(provider: provider),
    );
  }

  void _showSortOptions(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortOptionsSheet(provider: provider),
    );
  }

  void _showFestivalSelector(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
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

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.tonal(
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
    return FilledButton.tonal(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filter by Category', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            leading: Radio<String?>(
              value: null,
              groupValue: provider.selectedCategory,
              onChanged: (value) {
                provider.setCategory(null);
                Navigator.pop(context);
              },
            ),
            title: Text('All (${provider.allDrinks.length})'),
            onTap: () {
              provider.setCategory(null);
              Navigator.pop(context);
            },
          ),
          ...categories.map((category) => ListTile(
                leading: Radio<String?>(
                  value: category,
                  groupValue: provider.selectedCategory,
                  onChanged: (value) {
                    provider.setCategory(value);
                    Navigator.pop(context);
                  },
                ),
                title: Text('${_formatCategory(category)} (${counts[category] ?? 0})'),
                onTap: () {
                  provider.setCategory(category);
                  Navigator.pop(context);
                },
              )),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort By', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          ...DrinkSort.values.map((sort) => ListTile(
                leading: Radio<DrinkSort>(
                  value: sort,
                  groupValue: provider.currentSort,
                  onChanged: (value) {
                    if (value != null) {
                      provider.setSort(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                title: Text(_getSortLabel(sort)),
                onTap: () {
                  provider.setSort(sort);
                  Navigator.pop(context);
                },
              )),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FestivalInfoScreen(festival: festival),
                      ),
                    );
                  },
                )),
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
    Color backgroundColor;
    String label;
    
    switch (status) {
      case FestivalStatus.live:
        backgroundColor = Colors.green;
        label = 'LIVE';
      case FestivalStatus.upcoming:
        backgroundColor = Colors.blue;
        label = 'COMING SOON';
      case FestivalStatus.mostRecent:
        backgroundColor = Colors.orange;
        label = 'MOST RECENT';
      case FestivalStatus.past:
        return const SizedBox.shrink(); // No badge for past festivals
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
  }

  String _formatBeverageType(String type) {
    return type
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Horizontal scrollable style filter chips
class _StyleFilterChips extends StatelessWidget {
  final BeerProvider provider;

  const _StyleFilterChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = provider.availableStyles;
    final styleCounts = provider.styleCountsMap;
    final selectedStyles = provider.selectedStyles;

    if (styles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Style:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (selectedStyles.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear all'),
                  onPressed: () => provider.clearStyles(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _buildStyleChips(styles, styleCounts, selectedStyles, provider),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStyleChips(
    List<String> styles,
    Map<String, int> styleCounts,
    Set<String> selectedStyles,
    BeerProvider provider,
  ) {
    // Sort styles: selected first (alphabetically), then unselected (alphabetically)
    final sortedStyles = List<String>.from(styles);
    sortedStyles.sort((a, b) {
      final aSelected = selectedStyles.contains(a);
      final bSelected = selectedStyles.contains(b);

      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.compareTo(b);
    });

    return sortedStyles.map((style) {
      final count = styleCounts[style] ?? 0;
      final isSelected = selectedStyles.contains(style);

      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14),
              const SizedBox(width: 2),
            ],
            Text(
              '$style ($count)',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => provider.toggleStyle(style),
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();
  }
}
