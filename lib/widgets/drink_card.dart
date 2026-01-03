import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build semantic label for the card
    final cardLabel = _buildCardSemanticLabel();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        children: [
          Semantics(
            label: cardLabel,
            hint: 'Double tap for details',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
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
                          label: drink.isFavorite ? 'Remove from want to try' : 'Add to want to try',
                          hint: 'Double tap to toggle',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              drink.isFavorite ? Icons.bookmark : Icons.bookmark_border,
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
                        _CategoryChip(category: drink.category),
                        if (drink.style != null)
                          _StyleChip(style: drink.style!),
                        ExcludeSemantics(
                          child: InfoChip(
                            label: '${drink.abv.toStringAsFixed(1)}%',
                            icon: Icons.percent,
                          ),
                        ),
                        ExcludeSemantics(
                          child: InfoChip(
                            label: StringFormattingHelper.capitalizeFirst(drink.dispense),
                            icon: Icons.liquor,
                          ),
                        ),
                        if (drink.availabilityStatus != null)
                          _AvailabilityChip(status: drink.availabilityStatus!),
                        if (drink.rating != null)
                          _RatingChip(rating: drink.rating!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Status badge overlay
          _StatusBadge(drink: drink),
        ],
      ),
    );
  }

  String _buildCardSemanticLabel() {
    final buffer = StringBuffer();
    buffer.write(drink.name);
    buffer.write(', ${drink.abv.toStringAsFixed(1)} percent ABV');
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
        case AvailabilityStatus.low:
          buffer.write(', Low availability');
          break;
        case AvailabilityStatus.out:
          buffer.write(', Sold out');
          break;
        case AvailabilityStatus.notYetAvailable:
          buffer.write(', Not yet available');
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

  const _AvailabilityChip({required this.status});

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
      case AvailabilityStatus.low:
        color = isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00);
        label = 'Low';
        icon = Icons.warning;
        break;
      case AvailabilityStatus.out:
        color = theme.colorScheme.error;
        label = 'Sold Out';
        icon = Icons.cancel;
        break;
      case AvailabilityStatus.notYetAvailable:
        color = isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2);
        label = 'Coming Soon';
        icon = Icons.schedule;
        break;
    }

    return Container(
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
    );
  }
}

class _RatingChip extends StatelessWidget {
  final int rating;

  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return StarRating(
      rating: rating,
      isEditable: false,
      starSize: 14,
    );
  }
}

/// Prominent category chip with bold styling
class _CategoryChip extends StatelessWidget {
  final String category;

  const _CategoryChip({required this.category});

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
    
    return Container(
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
    );
  }
}

/// Prominent style chip with bold styling
class _StyleChip extends StatelessWidget {
  final String style;

  const _StyleChip({required this.style});

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
    
    return Container(
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
        ],
      ),
    );
  }
}

/// Status badge showing festival log status
class _StatusBadge extends StatelessWidget {
  final Drink drink;

  const _StatusBadge({required this.drink});

  @override
  Widget build(BuildContext context) {
    // Try to get provider, but gracefully handle when it's not available (e.g., in tests)
    final provider = context.watch<BeerProvider?>();
    
    if (provider == null) {
      return const SizedBox.shrink(); // No provider, no badge
    }
    
    return FutureBuilder<(String?, int)>(
      future: Future.wait([
        provider.getFavoriteStatus(drink),
        provider.getTryCount(drink),
      ]).then((results) => (results[0] as String?, results[1] as int)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final (status, tryCount) = snapshot.data!;
        
        // Only show badge for tasted drinks (bookmark button already indicates want_to_try)
        if (status != 'tasted') {
          return const SizedBox.shrink();
        }

        final (icon, color, label) = tryCount == 1
            ? (Icons.check_circle, Colors.green, 'Tasted once')
            : (Icons.check_circle, Colors.green, 'Tasted $tryCount times');

        return Positioned(
          bottom: 8,
          right: 8,
          child: Semantics(
            label: label,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (tryCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${tryCount}x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
