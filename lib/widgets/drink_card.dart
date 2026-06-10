import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/drink_visibility_filter.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'info_chip.dart';
import 'star_rating.dart';

/// Card widget for displaying a drink in a list
class DrinkCard extends StatelessWidget {
  final Drink drink;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const DrinkCard({
    super.key,
    required this.drink,
    this.onTap,
    this.onFavoriteTap,
  });

  static Color _accentColor(String category) {
    switch (category) {
      case BeverageCategories.beer:
        return const Color(0xFFF59E0B); // amber
      case BeverageCategories.internationalBeer:
        return const Color(0xFFEF4444); // red
      case BeverageCategories.cider:
        return const Color(0xFF22C55E); // green
      case BeverageCategories.perry:
        return const Color(0xFF84CC16); // lime
      case BeverageCategories.mead:
        return const Color(0xFFD97706); // honey gold
      case BeverageCategories.wine:
        return const Color(0xFF9333EA); // purple
      case BeverageCategories.lowNo:
        return const Color(0xFF06B6D4); // cyan
      case BeverageCategories.appleJuice:
        return const Color(0xFF65A30D); // apple green
      default:
        return const Color(0xFF2B3170); // CBF navy
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _accentColor(drink.category);
    final cardLabel = _buildCardSemanticLabel();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: cardLabel,
        hint: 'Double tap for details',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              drink.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              drink.breweryLocation.isNotEmpty
                                  ? '${drink.breweryName} • ${drink.breweryLocation}'
                                  : drink.breweryName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: drink.isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        hint: 'Double tap to toggle',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            drink.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: drink.isFavorite
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          onPressed: onFavoriteTap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _CategoryChip(
                        category: drink.category,
                        onTap: () => context.read<BeerProvider>().setCategory(
                          drink.category,
                        ),
                      ),
                      if (drink.style != null)
                        _StyleChip(
                          style: drink.style!,
                          onTap: () {
                            final provider = context.read<BeerProvider>();
                            unawaited(
                              provider.analyticsService.logStyleViewed(
                                drink.style!,
                              ),
                            );
                            navigateToRoute(
                              context,
                              buildStylePath(
                                provider.currentFestival.id,
                                drink.style!,
                              ),
                            );
                          },
                        ),
                      ExcludeSemantics(
                        child: InfoChip(
                          label: '${drink.abv.toStringAsFixed(1)}%',
                          icon: Icons.percent,
                        ),
                      ),
                      ExcludeSemantics(
                        child: InfoChip(
                          label: StringFormattingHelper.capitalizeFirst(
                            drink.dispense,
                          ),
                          icon: Icons.liquor,
                        ),
                      ),
                      if (drink.availabilityStatus != null)
                        _AvailabilityChip(
                          status: drink.availabilityStatus!,
                          rawText: drink.statusText,
                          onTap:
                              drink.availabilityStatus ==
                                  AvailabilityStatus.plenty
                              ? null
                              : () => unawaited(
                                  context
                                      .read<BeerProvider>()
                                      .setVisibilityFilter(
                                        DrinkVisibilityFilter.availableOnly,
                                        active: true,
                                      ),
                                ),
                        ),
                      if (drink.rating != null)
                        _RatingChip(rating: drink.rating!),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildCardSemanticLabel() {
    final buffer = StringBuffer()
      ..write(drink.name)
      ..write(', ${drink.abv.toStringAsFixed(1)} percent ABV');
    if (drink.style != null) {
      buffer.write(', ${drink.style}');
    }
    buffer.write(', by ${drink.breweryName}');
    if (drink.breweryLocation.isNotEmpty) {
      buffer.write(', ${drink.breweryLocation}');
    }
    if (drink.availabilityStatus != null) {
      switch (drink.availabilityStatus!) {
        case AvailabilityStatus.plenty:
          buffer.write(', Available');
          break;
        case AvailabilityStatus.good:
          buffer.write(', Some remaining');
          break;
        case AvailabilityStatus.low:
          buffer.write(', Low availability');
          break;
        case AvailabilityStatus.veryLow:
          buffer.write(', Very low availability');
          break;
        case AvailabilityStatus.out:
          buffer.write(', Sold out');
          break;
        case AvailabilityStatus.unknown:
          buffer.write(', ${drink.statusText ?? 'Unknown availability'}');
          break;
      }
    }
    if (drink.rating != null) {
      buffer.write(', Rated ${drink.rating} out of 5 stars');
    }
    return buffer.toString();
  }
}

class _AvailabilityChip extends StatelessWidget {
  final AvailabilityStatus status;
  final String? rawText;
  final VoidCallback? onTap;

  const _AvailabilityChip({required this.status, this.rawText, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    String label;
    IconData icon;

    switch (status) {
      case AvailabilityStatus.plenty:
        color = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
        label = 'Available';
        icon = Icons.check_circle;
        break;
      case AvailabilityStatus.good:
        color = isDark ? const Color(0xFF8BC34A) : const Color(0xFF558B2F);
        label = 'Some Left';
        icon = Icons.check_circle_outline;
        break;
      case AvailabilityStatus.low:
        color = isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00);
        label = 'Low';
        icon = Icons.warning;
        break;
      case AvailabilityStatus.veryLow:
        color = isDark ? const Color(0xFFFF7043) : const Color(0xFFBF360C);
        label = 'Nearly Gone';
        icon = Icons.warning_amber;
        break;
      case AvailabilityStatus.out:
        color = theme.colorScheme.error;
        label = 'Sold Out';
        icon = Icons.cancel;
        break;
      case AvailabilityStatus.unknown:
        color = isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A);
        label = rawText ?? 'Unknown';
        icon = Icons.info_outline;
        break;
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: onTap != null
          ? '$label — filter to show only available drinks'
          : label,
      hint: onTap != null ? 'Double tap to hide unavailable drinks' : null,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final int rating;

  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return StarRating(rating: rating, isEditable: false, starSize: 14);
  }
}

/// Prominent category chip with bold styling
class _CategoryChip extends StatelessWidget {
  final String category;
  final VoidCallback? onTap;

  const _CategoryChip({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use theme-aware colors
    final backgroundColor = isDark
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
        : theme.colorScheme.primaryContainer;
    final textColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.9)
        : theme.colorScheme.onPrimaryContainer;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Filter by ${BeverageTypeHelper.formatBeverageType(category)}',
      button: onTap != null,
      hint: onTap != null
          ? 'Double tap to filter drinks by this category'
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                BeverageTypeHelper.formatBeverageType(category),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent style chip with bold styling
class _StyleChip extends StatelessWidget {
  final String style;
  final VoidCallback? onTap;

  const _StyleChip({required this.style, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use theme-aware colors - use secondary color for distinction from category
    final backgroundColor = isDark
        ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
        : theme.colorScheme.secondaryContainer;
    final textColor = isDark
        ? theme.colorScheme.secondary.withValues(alpha: 0.9)
        : theme.colorScheme.onSecondaryContainer;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'View all $style drinks',
      button: onTap != null,
      hint: onTap != null
          ? 'Double tap to see all drinks with this style'
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_drink, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                style,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right, size: 12, color: textColor),
            ],
          ),
        ),
      ),
    );
  }
}
