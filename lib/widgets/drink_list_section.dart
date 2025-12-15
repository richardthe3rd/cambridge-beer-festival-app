import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import 'widgets.dart';

/// Reusable widget that renders a list of drinks as slivers
///
/// This widget encapsulates the common pattern of displaying a titled list of drinks:
/// - SliverToBoxAdapter for the section title
/// - SliverList for the drink cards
///
/// Used by EntityDetailScreen and DrinkDetailScreen's Similar Drinks section.
///
/// **Testing**: This widget is thoroughly tested through integration tests in:
/// - EntityDetailScreen (test/brewery_screen_test.dart, test/style_screen_test.dart)
/// - DrinkDetailScreen (test/drink_detail_screen_test.dart - Similar Drinks section)
class DrinkListSection {
  /// Build a list of slivers that display drinks with a title
  ///
  /// Returns:
  /// - SliverToBoxAdapter with the title
  /// - SliverList with DrinkCard items
  ///
  /// Example usage in a CustomScrollView:
  /// ```dart
  /// CustomScrollView(
  ///   slivers: [
  ///     ...DrinkListSection.buildSlivers(
  ///       context: context,
  ///       title: 'Similar Drinks',
  ///       drinks: similarDrinks,
  ///     ),
  ///   ],
  /// )
  /// ```
  static List<Widget> buildSlivers({
    required BuildContext context,
    required String title,
    required List<Drink> drinks,
    bool showCount = true,
  }) {
    if (drinks.isEmpty) {
      return [];
    }

    final theme = Theme.of(context);
    final provider = context.read<BeerProvider>();
    final displayTitle = showCount ? '$title (${drinks.length})' : title;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            displayTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final drink = drinks[index];
            return DrinkCard(
              key: ValueKey(drink.id),
              drink: drink,
              onTap: () => context.go('/drink/${drink.id}'),
              onFavoriteTap: () => provider.toggleFavorite(drink),
            );
          },
          childCount: drinks.length,
        ),
      ),
    ];
  }

  /// Build a list of slivers that display drinks with subtitles explaining why they're included
  ///
  /// Similar to buildSlivers but accepts a list of (Drink, String) tuples where the string
  /// is a subtitle to display under each drink (e.g., "Same brewery", "Similar style").
  ///
  /// Returns:
  /// - SliverToBoxAdapter with the title
  /// - SliverList with custom cards showing drink + subtitle
  static List<Widget> buildSliversWithSubtitles({
    required BuildContext context,
    required String title,
    required List<(Drink, String)> drinksWithSubtitles,
    bool showCount = true,
  }) {
    if (drinksWithSubtitles.isEmpty) {
      return [];
    }

    final theme = Theme.of(context);
    final provider = context.read<BeerProvider>();
    final displayTitle = showCount ? '$title (${drinksWithSubtitles.length})' : title;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            displayTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final (drink, subtitle) = drinksWithSubtitles[index];
            return _DrinkCardWithSubtitle(
              key: ValueKey(drink.id),
              drink: drink,
              subtitle: subtitle,
              onTap: () => context.go('/drink/${drink.id}'),
              onFavoriteTap: () => provider.toggleFavorite(drink),
            );
          },
          childCount: drinksWithSubtitles.length,
        ),
      ),
    ];
  }
}

/// Internal widget that wraps a DrinkCard with a subtitle
class _DrinkCardWithSubtitle extends StatelessWidget {
  final Drink drink;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const _DrinkCardWithSubtitle({
    super.key,
    required this.drink,
    required this.subtitle,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DrinkCard(
          drink: drink,
          onTap: onTap,
          onFavoriteTap: onFavoriteTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
