import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'drink_detail_screen.dart';
import 'brewery_screen.dart';

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
    final theme = Theme.of(context);
    final provider = context.watch<BeerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search drinks, breweries, styles...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => provider.setSearchQuery(value),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.currentFestival.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${provider.drinks.length} drinks',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
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
      body: Column(
        children: [
          _buildFilterBar(context, provider),
          Expanded(
            child: _buildDrinksList(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, BeerProvider provider) {
    return Container(
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
        ],
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
