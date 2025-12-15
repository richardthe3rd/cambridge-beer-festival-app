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
}
