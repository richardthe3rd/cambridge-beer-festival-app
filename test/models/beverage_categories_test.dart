import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Pins the beverage-type slug -> feed category mapping.
//
// The constants in BeverageCategories name feed FILES (and appear in a
// festival's available_beverage_types). Six of the eight are also the
// `category` the products inside carry; two are not. Anything that matches a
// slug against Drink.category has to go through feedCategoryFor, and this
// test is the record of which slugs need translating.
//
// Verified 2026-09-02 against the live cbf2026, cbf2025 and cbf2024 feeds:
// international-beer.json carries 'foreign beer' throughout, apple-juice.json
// carries 'apple juice'. If the upstream feed is ever corrected to match its
// own filenames, this test is the thing that should fail first.
void main() {
  group('BeverageCategories.feedCategoryFor', () {
    test('translates the two slugs the feed labels differently', () {
      expect(
        BeverageCategories.feedCategoryFor(
          BeverageCategories.internationalBeer,
        ),
        'foreign beer',
      );
      expect(
        BeverageCategories.feedCategoryFor(BeverageCategories.appleJuice),
        'apple juice',
      );
    });

    test('passes through the six slugs that match their feed category', () {
      for (final slug in const [
        BeverageCategories.beer,
        BeverageCategories.cider,
        BeverageCategories.perry,
        BeverageCategories.mead,
        BeverageCategories.wine,
        BeverageCategories.lowNo,
      ]) {
        expect(BeverageCategories.feedCategoryFor(slug), slug);
      }
    });

    test('passes through an unknown type unchanged', () {
      // A festival could list a beverage type this app has no constant for;
      // filtering on the raw value is the only sensible guess.
      expect(BeverageCategories.feedCategoryFor('kombucha'), 'kombucha');
    });
  });
}
