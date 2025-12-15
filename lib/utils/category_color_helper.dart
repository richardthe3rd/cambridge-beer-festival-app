import 'package:flutter/material.dart';

/// Helper class for getting category-specific colors
///
/// Provides consistent theme-aware colors for different beverage categories.
/// Colors are supplementary visual aids, not primary indicators (accessibility).
class CategoryColorHelper {
  CategoryColorHelper._();

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
