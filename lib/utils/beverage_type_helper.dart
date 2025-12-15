import 'package:flutter/material.dart';

/// Helper class for beverage type formatting and display
///
/// Provides utilities for formatting beverage type names and getting associated icons.
class BeverageTypeHelper {
  BeverageTypeHelper._();

  /// Format a beverage type string for display
  ///
  /// Converts dash-separated lowercase strings to Title Case.
  /// Example: 'international-beer' -> 'International Beer'
  static String formatBeverageType(String type) {
    return type
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get an icon for a beverage type
  ///
  /// Returns an appropriate Material icon based on the beverage type.
  /// Falls back to Icons.local_drink for unknown types.
  static IconData getBeverageIcon(String type) {
    switch (type) {
      case 'beer':
        return Icons.sports_bar;
      case 'international-beer':
        return Icons.public;
      case 'cider':
        return Icons.local_drink;
      case 'perry':
        return Icons.eco;
      case 'mead':
        return Icons.emoji_nature;
      case 'wine':
        return Icons.wine_bar;
      case 'low-no':
        return Icons.no_drinks;
      default:
        return Icons.local_drink;
    }
  }
}
