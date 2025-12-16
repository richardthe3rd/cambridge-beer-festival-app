import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('StyleDescriptionHelper', () {
    testWidgets('returns null for null style', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final result = await StyleDescriptionHelper.getStyleDescription(null);
      expect(result, isNull);
    });

    testWidgets('returns null for unknown style', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final result = await StyleDescriptionHelper.getStyleDescription('Unknown Style');
      expect(result, isNull);
    });

    testWidgets('loads and returns description from JSON file', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      
      // Test that IPA description is actually loaded from the JSON file
      final result = await StyleDescriptionHelper.getStyleDescription('IPA');
      expect(result, isNotNull);
      expect(result, contains('Lorem ipsum')); // Verify it's the lorem ipsum placeholder
    });

    testWidgets('handles case-insensitive lookup', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      
      // All case variations should return the same description
      final result1 = await StyleDescriptionHelper.getStyleDescription('IPA');
      final result2 = await StyleDescriptionHelper.getStyleDescription('ipa');
      final result3 = await StyleDescriptionHelper.getStyleDescription('Ipa');
      
      expect(result1, isNotNull);
      expect(result1, equals(result2));
      expect(result2, equals(result3));
    });

    testWidgets('trims whitespace from style name', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      
      final result = await StyleDescriptionHelper.getStyleDescription('  IPA  ');
      expect(result, isNotNull);
      expect(result, contains('Lorem ipsum'));
    });

    testWidgets('filters out empty string descriptions', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      
      // The helper should filter out empty strings from JSON
      final result = await StyleDescriptionHelper.getStyleDescription('ipa');
      // Should be non-null and non-empty if it exists
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    testWidgets('reset clears cached descriptions', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      
      // Load descriptions
      final firstResult = await StyleDescriptionHelper.getStyleDescription('IPA');
      expect(firstResult, isNotNull);
      
      // Reset should clear the cache
      StyleDescriptionHelper.reset();
      
      // Should be able to load again
      final result = await StyleDescriptionHelper.getStyleDescription('IPA');
      expect(result, isNotNull);
    });
  });
}
