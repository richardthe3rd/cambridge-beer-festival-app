import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('CategoryColorHelper', () {
    testWidgets('returns correct color for beer category', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final color = CategoryColorHelper.getCategoryColor(context, 'beer');
              expect(color, isNotNull);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('returns correct color for cider category in light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              final color = CategoryColorHelper.getCategoryColor(context, 'cider');
              expect(color, const Color(0xFF689F38));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('returns valid color for unknown category', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              final color = CategoryColorHelper.getCategoryColor(context, 'unknown');
              expect(color, isNotNull);
              expect(color, isA<Color>());
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('handles case-insensitive matching', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final colorLower = CategoryColorHelper.getCategoryColor(context, 'beer');
              final colorUpper = CategoryColorHelper.getCategoryColor(context, 'BEER');
              final colorMixed = CategoryColorHelper.getCategoryColor(context, 'BeEr');
              
              expect(colorLower, colorUpper);
              expect(colorUpper, colorMixed);
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('ABVStrengthHelper', () {
    testWidgets('getABVStrengthLabel returns Low for low ABV', (tester) async {
      expect(ABVStrengthHelper.getABVStrengthLabel(3.5), '(Low)');
      expect(ABVStrengthHelper.getABVStrengthLabel(0.5), '(Low)');
    });

    testWidgets('getABVStrengthLabel returns Medium for medium ABV', (tester) async {
      expect(ABVStrengthHelper.getABVStrengthLabel(4.0), '(Medium)');
      expect(ABVStrengthHelper.getABVStrengthLabel(5.5), '(Medium)');
      expect(ABVStrengthHelper.getABVStrengthLabel(6.9), '(Medium)');
    });

    testWidgets('getABVStrengthLabel returns High for high ABV', (tester) async {
      expect(ABVStrengthHelper.getABVStrengthLabel(7.0), '(High)');
      expect(ABVStrengthHelper.getABVStrengthLabel(10.5), '(High)');
    });

    testWidgets('getABVColor returns correct colors for different ABV ranges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final lowColor = ABVStrengthHelper.getABVColor(context, 3.5);
              final mediumColor = ABVStrengthHelper.getABVColor(context, 5.0);
              final highColor = ABVStrengthHelper.getABVColor(context, 8.0);
              
              expect(lowColor, isNotNull);
              expect(mediumColor, isNotNull);
              expect(highColor, isNotNull);
              
              // Colors should be different for different ranges
              expect(lowColor, isNot(mediumColor));
              expect(mediumColor, isNot(highColor));
              
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('BeverageTypeHelper', () {
    test('formatBeverageType formats dash-separated strings', () {
      expect(BeverageTypeHelper.formatBeverageType('beer'), 'Beer');
      expect(BeverageTypeHelper.formatBeverageType('international-beer'), 'International Beer');
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
      expect(BeverageTypeHelper.getBeverageIcon('international-beer'), Icons.public);
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
