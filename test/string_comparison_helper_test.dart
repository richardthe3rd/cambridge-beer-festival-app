import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('StringComparisonHelper', () {
    test('sorts case-insensitively', () {
      final unsorted = ['ipa', 'IPA', 'bitter', 'BITTER', 'Stout', 'STOUT'];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // All case variations of the same word should be grouped together
      expect(sorted[0].toLowerCase(), 'bitter');
      expect(sorted[1].toLowerCase(), 'bitter');
      expect(sorted[2].toLowerCase(), 'ipa');
      expect(sorted[3].toLowerCase(), 'ipa');
      expect(sorted[4].toLowerCase(), 'stout');
      expect(sorted[5].toLowerCase(), 'stout');
    });

    test('sorts accented characters after their base characters', () {
      // With case-insensitive comparison, accented versions should come
      // after their non-accented counterparts in most cases
      final unsorted = ['Rosé', 'Rose', 'Café', 'Cafe'];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // Verify Cafe comes before Café, and Rose comes before Rosé
      final cafeIndex = sorted.indexWhere((s) => s == 'Cafe');
      final cafeAccentIndex = sorted.indexWhere((s) => s == 'Café');
      expect(cafeIndex, lessThan(cafeAccentIndex),
        reason: 'Cafe should come before Café');

      final roseIndex = sorted.indexWhere((s) => s == 'Rose');
      final roseAccentIndex = sorted.indexWhere((s) => s == 'Rosé');
      expect(roseIndex, lessThan(roseAccentIndex),
        reason: 'Rose should come before Rosé');
    });

    test('maintains consistent alphabetical ordering', () {
      final unsorted = ['Rosé', 'Rose', 'IPA', 'Bitter', 'Café', 'Cafe', 'Pilsner', 'Stout'];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // Verify basic alphabetical order (B < C < I < P < R < S)
      final bIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('b'));
      final cIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('c'));
      final iIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('i'));
      final pIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('p'));
      final rIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('r'));
      final sIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('s'));

      expect(bIndex, lessThan(cIndex));
      expect(cIndex, lessThan(iIndex));
      expect(iIndex, lessThan(pIndex));
      expect(pIndex, lessThan(rIndex));
      expect(rIndex, lessThan(sIndex));
    });

    test('handles various Unicode characters', () {
      // Test with various European characters that might appear in beer/wine names
      final unsorted = [
        'Kölsch',      // German ö
        'Kolsch',
        'Märzen',      // German ä
        'Marzen',
        'Niño',        // Spanish ñ
        'Nino',
      ];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // Verify basic alphabetical grouping works
      // All K's should come before M's, M's before N's
      final kCount = sorted.where((s) => s.toLowerCase().startsWith('k')).length;
      final mCount = sorted.where((s) => s.toLowerCase().startsWith('m')).length;
      
      expect(kCount, 2);
      expect(mCount, 2);
      
      // Verify the K words come first
      expect(sorted[0].toLowerCase().startsWith('k'), true);
      expect(sorted[1].toLowerCase().startsWith('k'), true);
      expect(sorted[2].toLowerCase().startsWith('m'), true);
      expect(sorted[3].toLowerCase().startsWith('m'), true);
      expect(sorted[4].toLowerCase().startsWith('n'), true);
      expect(sorted[5].toLowerCase().startsWith('n'), true);
    });

    test('preserves original strings (no normalization)', () {
      // Ensure the comparison doesn't modify the strings
      const original = 'Rosé Cider';
      const copy = 'Rosé Cider';
      
      StringComparisonHelper.compareLocaleAware(original, copy);
      
      expect(original, 'Rosé Cider', reason: 'Original string should not be modified');
      expect(copy, 'Rosé Cider', reason: 'Copy string should not be modified');
    });

    test('handles empty strings', () {
      expect(StringComparisonHelper.compareLocaleAware('', ''), 0);
      expect(StringComparisonHelper.compareLocaleAware('', 'a'), lessThan(0));
      expect(StringComparisonHelper.compareLocaleAware('a', ''), greaterThan(0));
    });

    test('returns consistent ordering (transitivity)', () {
      // Verify transitivity: if a < b and b < c, then a < c
      const a = 'Cafe';
      const b = 'Café';
      const c = 'IPA';

      final ab = StringComparisonHelper.compareLocaleAware(a, b);
      final bc = StringComparisonHelper.compareLocaleAware(b, c);
      final ac = StringComparisonHelper.compareLocaleAware(a, c);

      if (ab < 0 && bc < 0) {
        expect(ac, lessThan(0), reason: 'Transitivity should hold: a < b < c => a < c');
      }
    });

    test('actual beer style names with accents', () {
      // Real-world test case with actual beer/wine style names that might have accents
      final styles = [
        'Saison',
        'Märzen',
        'Kölsch',
        'Rosé Cider',
        'Bière de Garde',
        'IPA',
        'Bitter',
        'Porter',
      ];
      
      final sorted = List<String>.from(styles);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // Verify it's in a reasonable alphabetical order
      // B comes before I, I before K, K before M, etc.
      final bIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('b'));
      final iIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('i'));
      final kIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('k'));
      final mIndex = sorted.indexWhere((s) => s.toLowerCase().startsWith('m'));
      
      expect(bIndex, lessThan(iIndex), reason: 'B should come before I');
      expect(iIndex, lessThan(kIndex), reason: 'I should come before K');
      expect(kIndex, lessThan(mIndex), reason: 'K should come before M');
    });

    test('accented characters display correctly (not garbled)', () {
      // This test verifies that the strings with accented characters
      // maintain their correct form after comparison
      final styles = ['Rosé', 'Café', 'Märzen'];
      
      styles.sort(StringComparisonHelper.compareLocaleAware);
      
      // Verify the accented characters are preserved correctly
      expect(styles.any((s) => s.contains('é')), true,
        reason: 'Should contain é character');
      expect(styles.any((s) => s.contains('ä')), true,
        reason: 'Should contain ä character');
      
      // Verify they're not garbled (common mojibake patterns)
      expect(styles.any((s) => s.contains('Ã©')), false,
        reason: 'Should not contain mojibake Ã© (garbled é)');
      expect(styles.any((s) => s.contains('Ã¤')), false,
        reason: 'Should not contain mojibake Ã¤ (garbled ä)');
    });
  });
}
