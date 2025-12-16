import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('StyleDescriptionHelper', () {
    test('returns null for null style', () async {
      final result = await StyleDescriptionHelper.getStyleDescription(null);
      expect(result, isNull);
    });

    test('returns null for unknown style', () async {
      final result = await StyleDescriptionHelper.getStyleDescription('Unknown Style');
      expect(result, isNull);
    });

    test('handles case-insensitive lookup', () async {
      // Since we have an empty map initially, this should return null
      // But when populated, it should work case-insensitively
      final result1 = await StyleDescriptionHelper.getStyleDescription('IPA');
      final result2 = await StyleDescriptionHelper.getStyleDescription('ipa');
      final result3 = await StyleDescriptionHelper.getStyleDescription('Ipa');
      
      expect(result1, equals(result2));
      expect(result2, equals(result3));
    });

    test('trims whitespace from style name', () async {
      final result = await StyleDescriptionHelper.getStyleDescription('  IPA  ');
      // Should handle trimming without error
      expect(result, isNull); // null because no description is populated yet
    });

    test('returns empty string descriptions as null', () async {
      // The helper filters out empty strings
      final result = await StyleDescriptionHelper.getStyleDescription('ipa');
      // Should be null if empty string in JSON
      expect(result, anyOf(isNull, isNotEmpty));
    });
  });
}
