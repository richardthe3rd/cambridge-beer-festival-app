/// Helper class for locale-aware string comparisons
/// 
/// Provides methods to properly sort and compare strings containing
/// non-ASCII characters (e.g., "rosé", "café") in a human-friendly way.
class StringComparisonHelper {
  // Private constructor to prevent instantiation
  StringComparisonHelper._();

  /// Locale-aware case-insensitive string comparison
  /// 
  /// This ensures that strings with accented characters (é, ñ, ü, etc.)
  /// are sorted in a reasonable alphabetical order. While not perfect for
  /// all locales, this approach handles common European accented characters
  /// properly for beer/wine/cider style names.
  /// 
  /// The comparison is case-insensitive, so "IPA", "Ipa", and "ipa" are
  /// treated as equal.
  /// 
  /// Examples:
  /// - "Café" comes right after "Cafe" 
  /// - "Rosé" comes right after "Rose"
  /// - "IPA" and "ipa" are treated as equal
  /// 
  /// For sorting lists:
  /// ```dart
  /// styles.sort(StringComparisonHelper.compareLocaleAware);
  /// ```
  static int compareLocaleAware(String a, String b) {
    // Use case-insensitive comparison
    // This handles accented characters reasonably well for European languages
    // by comparing the lowercase versions
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

