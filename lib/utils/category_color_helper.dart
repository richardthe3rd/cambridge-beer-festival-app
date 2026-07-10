import 'package:flutter/material.dart';
import '../models/models.dart';

/// Helper class for getting category-specific colors
///
/// Provides consistent theme-aware colors for different beverage categories.
/// Colors are supplementary visual aids, not primary indicators (accessibility).
class CategoryColorHelper {
  CategoryColorHelper._();

  /// Solid accent colour for a beverage [category], used for the coloured left
  /// edge of drink cards — both the list card and the similar-drinks carousel.
  /// A fixed palette (independent of theme) so a category reads at a glance;
  /// falls back to CBF navy for unknown categories.
  static Color getAccentColor(String category) {
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

  /// The "tasted" indicator green, shared by the drink card status badge and
  /// the similar-drinks carousel card. Darker in light mode for contrast,
  /// lighter in dark mode.
  static Color getTastedColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2E7D32);
  }

  /// Get color for a drink category
  ///
  /// Returns a theme-aware color based on the category name.
  /// Falls back to outline color if category is not recognized.
  static Color getCategoryColor(BuildContext context, String category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final cat = category.toLowerCase();

    if (cat.contains('beer')) {
      // Amber-like color
      return brightness == Brightness.dark
          ? colorScheme.secondary.withValues(alpha: 0.8)
          : colorScheme.secondary;
    } else if (cat.contains('cider')) {
      // Green-ish color
      return brightness == Brightness.dark
          ? const Color(0xFF8BC34A).withValues(alpha: 0.8)
          : const Color(0xFF689F38);
    } else if (cat.contains('perry')) {
      // Lime-ish color
      return brightness == Brightness.dark
          ? const Color(0xFFCDDC39).withValues(alpha: 0.8)
          : const Color(0xFFAFB42B);
    } else if (cat.contains('mead')) {
      // Yellow-ish color
      return brightness == Brightness.dark
          ? const Color(0xFFFFEB3B).withValues(alpha: 0.8)
          : const Color(0xFFF9A825);
    } else if (cat.contains('wine')) {
      // Deep purple/red color
      return brightness == Brightness.dark
          ? const Color(0xFF9C27B0).withValues(alpha: 0.8)
          : const Color(0xFF7B1FA2);
    } else if (cat.contains('low') || cat.contains('no')) {
      // Blue-ish color
      return brightness == Brightness.dark
          ? colorScheme.primary.withValues(alpha: 0.8)
          : colorScheme.primary;
    }
    // Default fallback
    return colorScheme.outline;
  }
}
