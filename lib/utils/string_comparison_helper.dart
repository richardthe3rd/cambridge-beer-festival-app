/// Helper class for case-insensitive string comparisons.
///
/// Used to order user-facing lists (drink names, breweries, styles) so that
/// capitalisation doesn't decide the order.
class StringComparisonHelper {
  // Private constructor to prevent instantiation
  StringComparisonHelper._();

  /// Case-insensitive string comparison.
  ///
  /// Lower-cases both operands and compares them with [String.compareTo], so
  /// "IPA", "Ipa", and "ipa" are treated as equal.
  ///
  /// **This is not collation.** [String.compareTo] compares UTF-16 code units,
  /// so any character outside ASCII sorts after every ASCII letter regardless
  /// of what it looks like: "Rosé" sorts after "Rosz", not next to "Rose", and
  /// a brewery like "Ārpus" sorts below "Zötler". Sorting accented text the way
  /// a reader would expect needs a real locale-aware collator (or a
  /// diacritic-folded sort key), which would change the visible order of the
  /// style filter and the My Festival list and should be its own change.
  ///
  /// For sorting lists:
  /// ```dart
  /// styles.sort(StringComparisonHelper.compareCaseInsensitive);
  /// ```
  static int compareCaseInsensitive(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
