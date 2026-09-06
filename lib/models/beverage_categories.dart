abstract final class BeverageCategories {
  static const String beer = 'beer';
  static const String internationalBeer = 'international-beer';
  static const String cider = 'cider';
  static const String perry = 'perry';
  static const String mead = 'mead';
  static const String wine = 'wine';
  static const String lowNo = 'low-no';
  static const String appleJuice = 'apple-juice';

  static const String defaultCategory = beer;

  /// Feed `category` values that differ from the beverage-type slug their
  /// products are served under.
  ///
  /// These constants are **feed-file slugs**: they name the JSON document
  /// (`/{festivalId}/international-beer.json`) and appear in a festival's
  /// `available_beverage_types`. They are NOT always the `category` each
  /// product inside that document carries. Six of the eight agree; two do
  /// not — `international-beer.json` labels its products `foreign beer`, and
  /// `apple-juice.json` labels its products `apple juice`.
  ///
  /// Verified 2026-09-02 against the live feeds for cbf2026, cbf2025 and
  /// cbf2024 — the divergence is stable across all three, not a one-off.
  /// The feeds are an upstream source this app adapts to and never edits, so
  /// the mapping lives here rather than being corrected at the source.
  static const Map<String, String> _feedCategoryBySlug = {
    internationalBeer: 'foreign beer',
    appleJuice: 'apple juice',
  };

  /// The `category` that drinks served under [beverageType] actually carry.
  ///
  /// Use this whenever a beverage-type slug has to be matched against
  /// [Drink.category] — filtering by it, or looking up anything keyed by it.
  /// Returns [beverageType] unchanged for the six types whose slug and
  /// category already agree, so it is safe to call for any type.
  static String feedCategoryFor(String beverageType) =>
      _feedCategoryBySlug[beverageType] ?? beverageType;

  /// The inverse of [_feedCategoryBySlug], built lazily from the same map so
  /// the two directions can never drift apart — there is exactly one source
  /// of truth for the divergence, this is just its reverse index.
  static final Map<String, String> _slugByFeedCategory = {
    for (final entry in _feedCategoryBySlug.entries) entry.value: entry.key,
  };

  /// The beverage-type slug that products carrying [feedCategory] are
  /// actually served under — the inverse of [feedCategoryFor].
  ///
  /// Use this whenever a [Drink.category] value (read straight off a
  /// product) has to be matched against a beverage-type slug — for example
  /// looking up a slug-keyed icon for a drink's own category. Returns
  /// [feedCategory] unchanged for the six types whose slug and category
  /// already agree, so it is safe to call for any category.
  static String slugFor(String feedCategory) =>
      _slugByFeedCategory[feedCategory] ?? feedCategory;
}
