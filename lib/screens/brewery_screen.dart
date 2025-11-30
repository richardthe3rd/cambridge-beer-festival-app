import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'drink_detail_screen.dart';

/// Screen showing a brewery and its drinks
class BreweryScreen extends StatelessWidget {
  final String breweryId;

  const BreweryScreen({super.key, required this.breweryId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    
    // Find all drinks from this brewery
    final breweryDrinks = provider.allDrinks
        .where((d) => d.producer.id == breweryId)
        .toList();

    if (breweryDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brewery Not Found')),
        body: const Center(child: Text('This brewery could not be found.')),
      );
    }

    final producer = breweryDrinks.first.producer;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(producer.name),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, producer, breweryDrinks.length),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drinks (${breweryDrinks.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final drink = breweryDrinks[index];
                return DrinkCard(
                  drink: drink,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DrinkDetailScreen(drinkId: drink.id),
                    ),
                  ),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
              childCount: breweryDrinks.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Producer producer, int drinkCount) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            producer.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (producer.location.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  producer.location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          if (producer.yearFounded != null) ...[
            const SizedBox(height: 4),
            Text(
              'Est. ${producer.yearFounded}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$drinkCount drinks at this festival',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
