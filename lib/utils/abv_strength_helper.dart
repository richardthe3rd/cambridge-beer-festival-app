import 'package:flutter/material.dart';

/// Helper class for getting ABV strength-related information
///
/// Provides consistent ABV strength indicators (colors and labels).
class ABVStrengthHelper {
  ABVStrengthHelper._();

  /// Get color for ABV strength indicator
  ///
  /// Returns theme-aware colors:
  /// - Low ABV (< 4.0%): Blue
  /// - Medium ABV (4.0% - 6.9%): Amber
  /// - High ABV (>= 7.0%): Deep Orange
  static Color getABVColor(BuildContext context, double abv) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    if (abv < 4.0) {
      // Low ABV: Blue-ish
      return brightness == Brightness.dark
          ? colorScheme.primary.withValues(alpha: 0.7)
          : colorScheme.primary;
    } else if (abv < 7.0) {
      // Medium ABV: Amber/Secondary
      return brightness == Brightness.dark
          ? colorScheme.secondary.withValues(alpha: 0.8)
          : colorScheme.secondary;
    } else {
      // High ABV: Deep Orange/Tertiary
      return brightness == Brightness.dark
          ? const Color(0xFFFF5722).withValues(alpha: 0.85)
          : const Color(0xFFE64A19);
    }
  }

  /// Get human-readable label for ABV strength
  ///
  /// Returns:
  /// - "(Low)" for ABV < 4.0%
  /// - "(Medium)" for ABV 4.0% - 6.9%
  /// - "(High)" for ABV >= 7.0%
  static String getABVStrengthLabel(double abv) {
    if (abv < 4.0) {
      return '(Low)';
    } else if (abv < 7.0) {
      return '(Medium)';
    } else {
      return '(High)';
    }
  }
}
