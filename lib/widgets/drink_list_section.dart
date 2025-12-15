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
}
