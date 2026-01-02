import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../utils/navigation_helpers.dart';

/// Screen showing the user's festival log (My Festival)
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.festivalId,
    super.key,
  });

  final String festivalId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => provider.loadDrinks(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: _buildTitle(context, provider),
              actions: [
                buildOverflowMenu(context),
              ],
            ),
            _buildFestivalLogSliver(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Festival'),
        Text(
          provider.currentFestival.name,
          style: theme.textTheme.labelSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFestivalLogSliver(BuildContext context, BeerProvider provider) {
    // Get all favorite drinks
    final allDrinks = provider.allDrinks.where((d) => d.isFavorite).toList();

    if (allDrinks.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    // Build list of drinks with their statuses
    return FutureBuilder<List<(Drink, String?, int)>>(
      future: Future.wait(
        allDrinks.map((drink) async {
          final status = await provider.getFavoriteStatus(drink);
          final tryCount = await provider.getTryCount(drink);
          return (drink, status, tryCount);
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final drinksWithStatus = snapshot.data!;

        // Sort: "want_to_try" first, then "tasted", then by name
        drinksWithStatus.sort((a, b) {
          final (drinkA, statusA, _) = a;
          final (drinkB, statusB, _) = b;

          // "want_to_try" comes before "tasted"
          if (statusA == 'want_to_try' && statusB == 'tasted') return -1;
          if (statusA == 'tasted' && statusB == 'want_to_try') return 1;

          // Within same status, sort by name
          return drinkA.name.compareTo(drinkB.name);
        });

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final (drink, status, _) = drinksWithStatus[index];

              // Show divider between "want to try" and "tasted"
              final showDivider = index > 0 &&
                  drinksWithStatus[index - 1].$2 != status;

              return Column(
                children: [
                  if (showDivider) _buildSectionDivider(context, status!),
                  Semantics(
                    label: '${drink.name} by ${drink.breweryName}',
                    hint: 'Double tap to view drink details',
                    button: true,
                    child: DrinkCard(
                      drink: drink,
                      onTap: () => context.go(buildDrinkDetailPath(festivalId, drink.id)),
                      onFavoriteTap: () => provider.toggleFavorite(drink),
                    ),
                  ),
                ],
              );
            },
            childCount: drinksWithStatus.length,
          ),
        );
      },
    );
  }

  Widget _buildSectionDivider(BuildContext context, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              status == 'tasted' ? 'Tasted' : '',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Your festival log is empty',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on drinks you want to try or mark drinks as tasted to build your festival log',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
