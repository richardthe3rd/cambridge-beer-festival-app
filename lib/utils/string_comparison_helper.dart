import 'package:intl/intl.dart';

/// Helper class for locale-aware string comparisons
/// 
/// Provides methods to properly sort and compare strings containing
/// non-ASCII characters (e.g., "rosé", "café") in a human-friendly way.
/// 
/// Uses the Intl package's Collator for proper Unicode handling.
class StringComparisonHelper {
  // Private constructor to prevent instantiation
  StringComparisonHelper._();

  /// Locale-aware string comparison using the Intl package's Collator
  /// 
  /// This ensures that strings with accented characters (é, ñ, ü, etc.)
  /// are sorted correctly according to linguistic rules rather than raw
  /// Unicode code point values.
  /// 
  /// Examples:
  /// - "Café" comes after "Cafe" (not far away based on accent code point)
  /// - "Rosé" comes after "Rose" 
  /// - Case-insensitive: "IPA" and "ipa" are treated as equal
  /// 
  /// For sorting lists:
  /// ```dart
  /// styles.sort(StringComparisonHelper.compareLocaleAware);
  /// ```
  static int compareLocaleAware(String a, String b) {
    // Create a collator for the default locale
    // Strength.TERTIARY provides case-insensitive comparison while
    // still respecting accent differences
    final collator = Collator()..strength = Strength.TERTIARY;
    return collator.compare(a, b);
  }

  /// Case-insensitive locale-aware string comparison
  /// 
  /// Similar to compareLocaleAware but ensures case differences are ignored.
  /// This is useful when you want "IPA", "Ipa", and "ipa" to be treated
  /// as identical.
  static int compareCaseInsensitive(String a, String b) {
    final collator = Collator()..strength = Strength.SECONDARY;
    return collator.compare(a, b);
  }
}
