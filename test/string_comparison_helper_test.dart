import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('StringComparisonHelper', () {
    test('sorts case-insensitively', () {
      final unsorted = ['ipa', 'IPA', 'bitter', 'BITTER', 'Stout', 'STOUT'];
      final sorted = List<String>.from(unsorted)
        ..sort(StringComparisonHelper.compareCaseInsensitive);

      // All case variations of the same word should be grouped together
      expect(sorted[0].toLowerCase(), 'bitter');
      expect(sorted[1].toLowerCase(), 'bitter');
      expect(sorted[2].toLowerCase(), 'ipa');
      expect(sorted[3].toLowerCase(), 'ipa');
      expect(sorted[4].toLowerCase(), 'stout');
      expect(sorted[5].toLowerCase(), 'stout');
    });

    test('sorts an accented word directly after its exact base word', () {
      // True only because 'rose' is a prefix of 'rosé' — see the test below
      // for what actually happens once any other letter is in play.
      final unsorted = ['Rosé', 'Rose', 'Café', 'Cafe'];
      final sorted = List<String>.from(unsorted)
        ..sort(StringComparisonHelper.compareCaseInsensitive);

      expect(
        sorted.indexWhere((s) => s == 'Cafe'),
        lessThan(sorted.indexWhere((s) => s == 'Café')),
      );
      expect(
        sorted.indexWhere((s) => s == 'Rose'),
        lessThan(sorted.indexWhere((s) => s == 'Rosé')),
      );
    });

    test(
      'pins the known limitation: non-ASCII sorts after every ASCII letter',
      () {
        // compareCaseInsensitive is NOT collation — String.compareTo compares
        // UTF-16 code units, so 'é' (U+00E9) is greater than every ASCII letter.
        // This is the behaviour the app ships today; it is pinned so that
        // introducing a real collator is a deliberate decision with a visible
        // diff here, not an accidental reordering of the style filter.
        final sorted = ['Rosé', 'Rosa', 'Rose', 'Rosz', 'Rosy']
          ..sort(StringComparisonHelper.compareCaseInsensitive);

        expect(
          sorted,
          ['Rosa', 'Rose', 'Rosy', 'Rosz', 'Rosé'],
          reason:
              'Rosé sorts last, after Rosz — a locale-aware collator would put '
              'it next to Rose',
        );
      },
    );

    test('maintains consistent alphabetical ordering', () {
      final unsorted = [
        'Rosé',
        'Rose',
        'IPA',
        'Bitter',
        'Café',
        'Cafe',
        'Pilsner',
        'Stout',
      ];
      final sorted = List<String>.from(unsorted)
        ..sort(StringComparisonHelper.compareCaseInsensitive);

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
        'Kölsch', // German ö
        'Kolsch',
        'Märzen', // German ä
        'Marzen',
        'Niño', // Spanish ñ
        'Nino',
      ];
      final sorted = List<String>.from(unsorted)
        ..sort(StringComparisonHelper.compareCaseInsensitive);

      // Verify basic alphabetical grouping works
      // All K's should come before M's, M's before N's
      final kCount = sorted
          .where((s) => s.toLowerCase().startsWith('k'))
          .length;
      final mCount = sorted
          .where((s) => s.toLowerCase().startsWith('m'))
          .length;

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

      StringComparisonHelper.compareCaseInsensitive(original, copy);

      expect(
        original,
        'Rosé Cider',
        reason: 'Original string should not be modified',
      );
      expect(copy, 'Rosé Cider', reason: 'Copy string should not be modified');
    });

    test('handles empty strings', () {
      expect(StringComparisonHelper.compareCaseInsensitive('', ''), 0);
      expect(
        StringComparisonHelper.compareCaseInsensitive('', 'a'),
        lessThan(0),
      );
      expect(
        StringComparisonHelper.compareCaseInsensitive('a', ''),
        greaterThan(0),
      );
    });

    test('returns consistent ordering (transitivity)', () {
      // Verify transitivity: if a < b and b < c, then a < c
      const a = 'Cafe';
      const b = 'Café';
      const c = 'IPA';

      final ab = StringComparisonHelper.compareCaseInsensitive(a, b);
      final bc = StringComparisonHelper.compareCaseInsensitive(b, c);
      final ac = StringComparisonHelper.compareCaseInsensitive(a, c);

      if (ab < 0 && bc < 0) {
        expect(
          ac,
          lessThan(0),
          reason: 'Transitivity should hold: a < b < c => a < c',
        );
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

      final sorted = List<String>.from(styles)
        ..sort(StringComparisonHelper.compareCaseInsensitive);

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
      final styles = ['Rosé', 'Café', 'Märzen']
        ..sort(StringComparisonHelper.compareCaseInsensitive);

      // Verify the accented characters are preserved correctly
      expect(
        styles.any((s) => s.contains('é')),
        true,
        reason: 'Should contain é character',
      );
      expect(
        styles.any((s) => s.contains('ä')),
        true,
        reason: 'Should contain ä character',
      );

      // Verify they're not garbled (common mojibake patterns)
      expect(
        styles.any((s) => s.contains('Ã©')),
        false,
        reason: 'Should not contain mojibake Ã© (garbled é)',
      );
      expect(
        styles.any((s) => s.contains('Ã¤')),
        false,
        reason: 'Should not contain mojibake Ã¤ (garbled ä)',
      );
    });
  });
}
