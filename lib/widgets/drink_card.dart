import 'package:flutter/material.dart';
import '../models/models.dart';
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
      child: Semantics(
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
                          Text(
                            drink.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
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
                      label: drink.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                      hint: 'Double tap to toggle',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          drink.isFavorite ? Icons.favorite : Icons.favorite_border,
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
                    _InfoChip(
                      label: '${drink.abv.toStringAsFixed(1)}%',
                      icon: Icons.percent,
                    ),
                    _InfoChip(
                      label: _formatDispense(drink.dispense),
                      icon: Icons.liquor,
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

  String _formatDispense(String dispense) {
    if (dispense.isEmpty) return dispense;
    return dispense[0].toUpperCase() + dispense.substring(1);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
            _formatCategory(category),
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
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
