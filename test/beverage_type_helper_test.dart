import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeverageTypeHelper', () {
    group('formatBeverageType', () {
      test('title-cases a single word', () {
        expect(BeverageTypeHelper.formatBeverageType('beer'), 'Beer');
      });

      test('title-cases each dash-separated segment', () {
        expect(
          BeverageTypeHelper.formatBeverageType('international-beer'),
          'International Beer',
        );
        expect(BeverageTypeHelper.formatBeverageType('low-no'), 'Low No');
      });

      test('ignores empty segments from leading/trailing/double dashes', () {
        expect(BeverageTypeHelper.formatBeverageType('--beer--'), 'Beer');
        expect(BeverageTypeHelper.formatBeverageType('cider--perry'),
            'Cider Perry');
      });

      test('returns an empty string for empty input', () {
        expect(BeverageTypeHelper.formatBeverageType(''), '');
      });
    });

    group('getBeverageIcon', () {
      test('maps each known beverage type to a distinct icon', () {
        expect(BeverageTypeHelper.getBeverageIcon('beer'), Icons.sports_bar);
        expect(BeverageTypeHelper.getBeverageIcon('international-beer'),
            Icons.public);
        expect(BeverageTypeHelper.getBeverageIcon('cider'), Icons.local_drink);
        expect(BeverageTypeHelper.getBeverageIcon('perry'), Icons.eco);
        expect(BeverageTypeHelper.getBeverageIcon('mead'), Icons.emoji_nature);
        expect(BeverageTypeHelper.getBeverageIcon('wine'), Icons.wine_bar);
        expect(BeverageTypeHelper.getBeverageIcon('low-no'), Icons.no_drinks);
      });

      test('falls back to a generic icon for unknown types', () {
        expect(
          BeverageTypeHelper.getBeverageIcon('apple-juice'),
          Icons.local_drink,
        );
        expect(BeverageTypeHelper.getBeverageIcon(''), Icons.local_drink);
      });
    });
  });
}
