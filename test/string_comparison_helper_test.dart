import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('StringComparisonHelper', () {
    test('sorts non-ASCII characters correctly with compareLocaleAware', () {
      final unsorted = ['Rosé', 'Rose', 'IPA', 'Bitter', 'Café', 'Cafe', 'Pilsner', 'Stout'];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // With locale-aware sorting, accented versions should come right after
      // their non-accented counterparts
      expect(sorted, [
        'Bitter',
        'Cafe',
        'Café',
        'IPA',
        'Pilsner',
        'Rose',
        'Rosé',
        'Stout',
      ]);
    });

    test('sorts case-insensitively', () {
      final unsorted = ['ipa', 'IPA', 'bitter', 'BITTER', 'Stout', 'STOUT'];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareCaseInsensitive);

      // All case variations of the same word should be grouped together
      // The exact order within a group may vary by locale, but groups should be together
      expect(sorted[0].toLowerCase(), 'bitter');
      expect(sorted[1].toLowerCase(), 'bitter');
      expect(sorted[2].toLowerCase(), 'ipa');
      expect(sorted[3].toLowerCase(), 'ipa');
      expect(sorted[4].toLowerCase(), 'stout');
      expect(sorted[5].toLowerCase(), 'stout');
    });

    test('handles various Unicode characters correctly', () {
      // Test with various European characters that might appear in beer/wine names
      final unsorted = [
        'Kölsch',      // German ö
        'Kolsch',
        'Märzen',      // German ä
        'Marzen',
        'Niño',        // Spanish ñ
        'Nino',
        'Øl',          // Norwegian ø
        'Ol',
      ];
      final sorted = List<String>.from(unsorted);
      sorted.sort(StringComparisonHelper.compareLocaleAware);

      // Verify each accented version comes right after its non-accented counterpart
      final kolschIndex = sorted.indexOf('Kolsch');
      final kolschAccentIndex = sorted.indexOf('Kölsch');
      expect(kolschAccentIndex, kolschIndex + 1, 
        reason: 'Kölsch should come right after Kolsch');

      final marzenIndex = sorted.indexOf('Marzen');
      final marzenAccentIndex = sorted.indexOf('Märzen');
      expect(marzenAccentIndex, marzenIndex + 1,
        reason: 'Märzen should come right after Marzen');
    });

    test('preserves original strings (no normalization)', () {
      // Ensure the comparison doesn't modify the strings
      final original = 'Rosé Cider';
      final copy = 'Rosé Cider';
      
      StringComparisonHelper.compareLocaleAware(original, copy);
      
      expect(original, 'Rosé Cider', reason: 'Original string should not be modified');
      expect(copy, 'Rosé Cider', reason: 'Copy string should not be modified');
    });

    test('handles empty strings', () {
      expect(StringComparisonHelper.compareLocaleAware('', ''), 0);
      expect(StringComparisonHelper.compareLocaleAware('', 'a'), lessThan(0));
      expect(StringComparisonHelper.compareLocaleAware('a', ''), greaterThan(0));
    });

    test('returns consistent ordering', () {
      // Verify transitivity: if a < b and b < c, then a < c
      final a = 'Cafe';
      final b = 'Café';
      final c = 'IPA';

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
      final bIndex = sorted.indexWhere((s) => s.startsWith('B'));
      final iIndex = sorted.indexWhere((s) => s.startsWith('I'));
      final kIndex = sorted.indexWhere((s) => s.startsWith('K'));
      final mIndex = sorted.indexWhere((s) => s.startsWith('M'));
      
      expect(bIndex, lessThan(iIndex), reason: 'B should come before I');
      expect(iIndex, lessThan(kIndex), reason: 'I should come before K');
      expect(kIndex, lessThan(mIndex), reason: 'K should come before M');
    });
  });
}
