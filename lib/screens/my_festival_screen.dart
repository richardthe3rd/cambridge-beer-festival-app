import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing favorited drinks
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({required this.festivalId, super.key});

  final String festivalId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    if (provider.currentFestival.id != festivalId) {
      return buildLoadingScaffold();
    }
    final entries = provider.favoriteEntries;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.currentFestival.name,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '${entries.length} favourites',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [buildOverflowMenu(context)],
      ),
      body: entries.isEmpty
          ? Semantics(
              label:
                  'No favourites yet. Tap the heart icon on drinks you want to try.',
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No favourites yet',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap the ♡ on drinks you want to try'),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                if (entry.drink != null) {
                  final drink = entry.drink!;
                  return DrinkCard(
                    key: ValueKey(drink.id),
                    drink: drink,
                    onTap: () => navigateToRoute(
                      context,
                      buildDrinkDetailPath(
                        festivalId,
                        drink.category,
                        drink.id,
                      ),
                    ),
                    onFavoriteTap: () => provider.toggleFavorite(drink),
                  );
                }
                return Semantics(
                  label: 'Favourite drink ${entry.drinkId}, details loading',
                  child: ListTile(
                    title: Text(entry.drinkId),
                    subtitle: const Text('Loading details…'),
                  ),
                );
              },
            ),
    );
  }
}
