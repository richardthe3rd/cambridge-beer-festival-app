import 'package:flutter/material.dart';
import '../models/models.dart';

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
      case BeverageCategories.beer:
        return Icons.sports_bar;
      case BeverageCategories.internationalBeer:
        return Icons.public;
      case BeverageCategories.cider:
        return Icons.local_drink;
      case BeverageCategories.perry:
        return Icons.eco;
      case BeverageCategories.mead:
        return Icons.emoji_nature;
      case BeverageCategories.wine:
        return Icons.wine_bar;
      case BeverageCategories.lowNo:
        return Icons.no_drinks;
      default:
        return Icons.local_drink;
    }
  }
}
