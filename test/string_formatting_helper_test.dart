import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringFormattingHelper', () {
    group('capitalizeFirst', () {
      test('uppercases the first character', () {
        expect(StringFormattingHelper.capitalizeFirst('cask'), 'Cask');
        expect(StringFormattingHelper.capitalizeFirst('keg'), 'Keg');
      });

      test('leaves the remaining characters untouched', () {
        expect(
          StringFormattingHelper.capitalizeFirst('bag in box'),
          'Bag in box',
        );
      });

      test('is a no-op for an already capitalised string', () {
        expect(StringFormattingHelper.capitalizeFirst('Cask'), 'Cask');
      });

      test('returns an empty string unchanged', () {
        expect(StringFormattingHelper.capitalizeFirst(''), '');
      });

      test('handles a single character', () {
        expect(StringFormattingHelper.capitalizeFirst('a'), 'A');
      });
    });

    group('drinkCountLabel', () {
      test('pluralises zero', () {
        expect(StringFormattingHelper.drinkCountLabel(0), '0 drinks');
      });

      test('uses the singular for exactly one', () {
        expect(StringFormattingHelper.drinkCountLabel(1), '1 drink');
      });

      test('pluralises counts above one', () {
        expect(StringFormattingHelper.drinkCountLabel(2), '2 drinks');
        expect(StringFormattingHelper.drinkCountLabel(147), '147 drinks');
      });
    });
  });
}
