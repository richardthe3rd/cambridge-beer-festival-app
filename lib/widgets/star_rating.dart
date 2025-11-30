import 'package:flutter/material.dart';

/// A widget that displays a star rating with optional interactive editing.
class StarRating extends StatelessWidget {
  /// The current rating (1-5), or null if not rated.
  final int? rating;

  /// Whether the rating can be changed by tapping.
  final bool isEditable;

  /// Callback when the rating is changed (only called if isEditable is true).
  final ValueChanged<int>? onRatingChanged;

  /// Size of each star icon.
  final double starSize;

  /// Color of filled stars.
  final Color? activeColor;

  /// Color of empty stars.
  final Color? inactiveColor;

  const StarRating({
    super.key,
    this.rating,
    this.isEditable = false,
    this.onRatingChanged,
    this.starSize = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? Colors.amber;
    final inactive = inactiveColor ?? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);

    final ratingValue = rating ?? 0;
    final semanticLabel = isEditable ? 'Rate this drink' : 'Rating';
    final semanticValue = '$ratingValue out of 5 stars';
    final semanticHint = isEditable ? 'Tap a star to rate from 1 to 5' : null;

    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      hint: semanticHint,
      enabled: isEditable,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starNumber = index + 1;
          final isFilled = rating != null && starNumber <= rating!;

          return Semantics(
            label: 'Star $starNumber',
            button: isEditable,
            selected: isFilled,
            child: GestureDetector(
              onTap: isEditable
                  ? () => onRatingChanged?.call(starNumber)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: starSize,
                  color: isFilled ? active : inactive,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
