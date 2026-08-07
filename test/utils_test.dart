import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('BeverageTypeHelper', () {
    test('formatBeverageType formats dash-separated strings', () {
      expect(BeverageTypeHelper.formatBeverageType('beer'), 'Beer');
      expect(
        BeverageTypeHelper.formatBeverageType('international-beer'),
        'International Beer',
      );
      expect(BeverageTypeHelper.formatBeverageType('low-no'), 'Low No');
    });

    test('formatBeverageType handles empty strings', () {
      expect(BeverageTypeHelper.formatBeverageType(''), '');
    });

    test('formatBeverageType handles single words', () {
      expect(BeverageTypeHelper.formatBeverageType('cider'), 'Cider');
      expect(BeverageTypeHelper.formatBeverageType('mead'), 'Mead');
    });

    test('getBeverageIcon returns correct icons', () {
      expect(BeverageTypeHelper.getBeverageIcon('beer'), Icons.sports_bar);
      expect(
        BeverageTypeHelper.getBeverageIcon('international-beer'),
        Icons.public,
      );
      expect(BeverageTypeHelper.getBeverageIcon('cider'), Icons.local_drink);
      expect(BeverageTypeHelper.getBeverageIcon('perry'), Icons.eco);
      expect(BeverageTypeHelper.getBeverageIcon('mead'), Icons.emoji_nature);
      expect(BeverageTypeHelper.getBeverageIcon('wine'), Icons.wine_bar);
      expect(BeverageTypeHelper.getBeverageIcon('low-no'), Icons.no_drinks);
    });

    test('getBeverageIcon returns fallback icon for unknown type', () {
      expect(BeverageTypeHelper.getBeverageIcon('unknown'), Icons.local_drink);
      expect(BeverageTypeHelper.getBeverageIcon(''), Icons.local_drink);
    });
  });

  group('StringFormattingHelper', () {
    test('capitalizeFirst capitalizes first letter', () {
      expect(StringFormattingHelper.capitalizeFirst('cask'), 'Cask');
      expect(StringFormattingHelper.capitalizeFirst('keg'), 'Keg');
      expect(StringFormattingHelper.capitalizeFirst('bottle'), 'Bottle');
    });

    test('capitalizeFirst handles empty string', () {
      expect(StringFormattingHelper.capitalizeFirst(''), '');
    });

    test('capitalizeFirst handles already capitalized', () {
      expect(StringFormattingHelper.capitalizeFirst('Cask'), 'Cask');
    });

    test('capitalizeFirst handles single character', () {
      expect(StringFormattingHelper.capitalizeFirst('k'), 'K');
    });
  });
}
