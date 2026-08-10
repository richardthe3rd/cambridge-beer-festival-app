/// Helper class for string formatting utilities
///
/// Provides common string formatting functions used throughout the app.
class StringFormattingHelper {
  StringFormattingHelper._();

  /// Capitalize the first letter of a string
  ///
  /// Returns the string with the first character uppercased.
  /// Returns empty string if input is empty.
  ///
  /// Example: 'cask' -> 'Cask', 'keg' -> 'Keg'
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Format a drink count with the correctly pluralised noun.
  ///
  /// Used in screen-reader labels, where an inlined `count == 1 ? ... : ...`
  /// ternary has twice been forgotten and announced '1 drinks' (#506, #513).
  ///
  /// Example: 0 -> '0 drinks', 1 -> '1 drink', 2 -> '2 drinks'
  static String drinkCountLabel(int count) {
    return '$count ${count == 1 ? 'drink' : 'drinks'}';
  }
}
