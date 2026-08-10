import 'package:flutter/material.dart';
import '../domain/services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'highlighted_text.dart';
import 'info_chip.dart';
import 'star_rating.dart';

/// Card widget for displaying a drink in a list
class DrinkCard extends StatelessWidget {
  final Drink drink;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  /// The active search query, used to highlight matched text and surface an
  /// excerpt when the match lies in a field the card doesn't otherwise show
  /// (the catalogue description or the user's own note). Empty (the default)
  /// disables all search decoration, so non-search usages are unaffected.
  final String searchQuery;

  const DrinkCard({
    super.key,
    required this.drink,
    this.onTap,
    this.onFavoriteTap,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = CategoryColorHelper.getAccentColor(
      drink.category,
      theme.brightness,
    );
    final excerpt = searchQuery.trim().isEmpty
        ? null
        : const SearchMatchService().hiddenFieldExcerpt(drink, searchQuery);
    final cardLabel = _buildCardSemanticLabel(excerpt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: cardLabel,
        hint: 'Double tap for details',
        button: true,
        excludeSemantics: true,
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
                            // Plain Text, not SelectableText: the whole card
                            // is a tap target, and text selection would
                            // swallow the tap (same rationale as
                            // _SimilarDrinkCard in drink_detail_screen.dart).
                            // HighlightedText degrades to a plain Text when the
                            // query is empty, so non-search rows are unchanged.
                            HighlightedText(
                              text: drink.name,
                              query: searchQuery,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            HighlightedText(
                              text: drink.breweryLocation.isNotEmpty
                                  ? '${drink.breweryName} • ${drink.breweryLocation}'
                                  : drink.breweryName,
                              query: searchQuery,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(drink: drink),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _CategoryChip(category: drink.category),
                      if (drink.style != null) _StyleChip(style: drink.style!),
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
                        ),
                      if (drink.rating != null)
                        _RatingChip(rating: drink.rating!),
                    ],
                  ),
                  if (excerpt != null) ...[
                    const SizedBox(height: 8),
                    HighlightedText(
                      text: excerpt.text,
                      query: searchQuery,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildCardSemanticLabel(SearchExcerpt? excerpt) {
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
      // Switch *expression*, deliberately without a wildcard arm: a new
      // AvailabilityStatus value must break the build here rather than
      // silently drop availability from the screen-reader label (#534).
      buffer.write(switch (drink.availabilityStatus!) {
        AvailabilityStatus.plenty => ', Available',
        AvailabilityStatus.good => ', Some remaining',
        AvailabilityStatus.low => ', Low availability',
        AvailabilityStatus.veryLow => ', Very low availability',
        AvailabilityStatus.out => ', Sold out',
        AvailabilityStatus.unknown =>
          ', ${drink.statusText ?? 'Unknown availability'}',
      });
    }
    if (drink.rating != null) {
      buffer.write(', Rated ${drink.rating} out of 5 stars');
    }
    // Tasted takes priority over want-to-try: a drink can be both flagged and
    // tasted, but the tasted state is the more specific, more recent signal
    // (mirrors the "Tasted section takes priority" rule in the vision doc).
    if (drink.tastingCount > 0) {
      buffer.write(
        drink.tastingCount == 1
            ? ', Tasted once'
            : ', Tasted ${drink.tastingCount} times',
      );
    } else if (drink.isFavorite) {
      buffer.write(', Added to want to try');
    }
    // Explain a match that isn't visible in the fields above — the query hit
    // the catalogue description or the user's own note.
    if (excerpt != null) {
      buffer.write(', matching text: ${excerpt.text}');
    }
    return buffer.toString();
  }
}

/// Read-only want-to-try / tasted status indicator.
///
/// Passive — not tappable. Toggling want-to-try and recording tastings lives
/// on the drink detail screen; this badge only reflects state.
class _StatusBadge extends StatelessWidget {
  final Drink drink;

  const _StatusBadge({required this.drink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tastingCount = drink.tastingCount;

    // Tasted takes priority: a drink can be both want-to-try and tasted, but
    // once tasted the checkmark badge is what's shown (vision.md).
    if (tastingCount > 0) {
      final tastedColor = CategoryColorHelper.getTastedColor(theme.brightness);
      final label = tastingCount == 1 ? 'Tasted' : 'Tasted $tastingCount times';
      return Semantics(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 24, color: tastedColor),
            if (tastingCount > 1) ...[
              const SizedBox(width: 2),
              Text(
                '$tastingCount×',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tastedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (drink.isFavorite) {
      return Semantics(
        label: 'Want to try',
        child: Icon(
          Icons.circle_outlined,
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _AvailabilityChip extends StatelessWidget {
  final AvailabilityStatus status;
  final String? rawText;

  const _AvailabilityChip({required this.status, this.rawText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = CategoryColorHelper.getAvailabilityColor(
      status,
      theme.colorScheme,
    );
    // Switch *expression*, deliberately without a wildcard arm — see #534.
    final (label, icon) = switch (status) {
      AvailabilityStatus.plenty => ('Available', Icons.check_circle),
      AvailabilityStatus.good => ('Some Left', Icons.check_circle_outline),
      AvailabilityStatus.low => ('Low', Icons.warning),
      AvailabilityStatus.veryLow => ('Nearly Gone', Icons.warning_amber),
      AvailabilityStatus.out => ('Sold Out', Icons.cancel),
      AvailabilityStatus.unknown => (rawText ?? 'Unknown', Icons.info_outline),
    };

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
    return StarRating(rating: rating, isEditable: false, starSize: 14);
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
