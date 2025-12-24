import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation Helpers', () {
    group('buildFestivalPath', () {
      test('builds path with leading slash', () {
        expect(
          buildFestivalPath('cbf2025', '/drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('builds path without leading slash', () {
        expect(
          buildFestivalPath('cbf2025', 'drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('handles nested paths', () {
        expect(
          buildFestivalPath('cbf2025', '/brewery/123'),
          equals('/cbf2025/brewery/123'),
        );
      });

      test('handles festival IDs with special characters', () {
        expect(
          buildFestivalPath('cbf-2025', '/drinks'),
          equals('/cbf-2025/drinks'),
        );
      });
    });

    group('buildFestivalHome', () {
      test('builds home path', () {
        expect(
          buildFestivalHome('cbf2025'),
          equals('/cbf2025'),
        );
      });
    });

    group('buildDrinksPath', () {
      test('builds drinks path without category', () {
        expect(
          buildDrinksPath('cbf2025'),
          equals('/cbf2025/drinks'),
        );
      });

      test('builds drinks path with category', () {
        expect(
          buildDrinksPath('cbf2025', category: 'beer'),
          equals('/cbf2025/drinks?category=beer'),
        );
      });
    });

    group('buildDrinkDetailPath', () {
      test('builds drink detail path', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink-123'),
          equals('/cbf2025/drink/drink-123'),
        );
      });

      test('handles drink IDs with special characters', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink-123-abc'),
          equals('/cbf2025/drink/drink-123-abc'),
        );
      });
    });

    group('buildBreweryPath', () {
      test('builds brewery path', () {
        expect(
          buildBreweryPath('cbf2025', 'brewery-123'),
          equals('/cbf2025/brewery/brewery-123'),
        );
      });
    });

    group('buildStylePath', () {
      test('builds style path', () {
        expect(
          buildStylePath('cbf2025', 'IPA'),
          equals('/cbf2025/style/IPA'),
        );
      });

      test('URL-encodes style names with spaces', () {
        expect(
          buildStylePath('cbf2025', 'American IPA'),
          equals('/cbf2025/style/American%20IPA'),
        );
      });

      test('URL-encodes style names with special characters', () {
        expect(
          buildStylePath('cbf2025', 'Barrel-Aged Stout'),
          equals('/cbf2025/style/Barrel-Aged%20Stout'),
        );
      });
    });

    group('buildCategoryPath', () {
      test('builds category path', () {
        expect(
          buildCategoryPath('cbf2025', 'beer'),
          equals('/cbf2025/category/beer'),
        );
      });
    });

    group('extractFestivalId', () {
      test('extracts festival ID from simple path', () {
        expect(
          extractFestivalId('/cbf2025/drinks'),
          equals('cbf2025'),
        );
      });

      test('extracts festival ID from nested path', () {
        expect(
          extractFestivalId('/cbf2025/brewery/123'),
          equals('cbf2025'),
        );
      });

      test('extracts festival ID from home path', () {
        expect(
          extractFestivalId('/cbf2025'),
          equals('cbf2025'),
        );
      });

      test('returns null for root path', () {
        expect(
          extractFestivalId('/'),
          isNull,
        );
      });

      test('returns null for empty path', () {
        expect(
          extractFestivalId(''),
          isNull,
        );
      });

      test('handles paths without leading slash', () {
        expect(
          extractFestivalId('cbf2025/drinks'),
          equals('cbf2025'),
        );
      });
    });

    group('isFestivalPath', () {
      test('returns true for festival-scoped paths', () {
        expect(isFestivalPath('/cbf2025/drinks'), isTrue);
        expect(isFestivalPath('/cbf2025/brewery/123'), isTrue);
        expect(isFestivalPath('/cbf2025'), isTrue);
      });

      test('returns false for non-festival paths', () {
        expect(isFestivalPath('/'), isFalse);
        expect(isFestivalPath(''), isFalse);
      });

      test('returns true for single segment paths (ambiguous)', () {
        // Note: Single segments are treated as potential festival IDs
        // Validation against actual festival list happens in Phase 1
        expect(isFestivalPath('/drinks'), isTrue);
        expect(isFestivalPath('/about'), isTrue);
      });
    });

    group('URL encoding edge cases', () {
      test('encodes drink IDs with spaces', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink 123'),
          equals('/cbf2025/drink/drink%20123'),
        );
      });

      test('encodes drink IDs with special characters', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink/456'),
          equals('/cbf2025/drink/drink%2F456'),
        );
      });

      test('encodes brewery IDs with ampersands', () {
        expect(
          buildBreweryPath('cbf2025', 'Oak & Elm'),
          equals('/cbf2025/brewery/Oak%20%26%20Elm'),
        );
      });

      test('encodes categories with slashes', () {
        expect(
          buildCategoryPath('cbf2025', 'low/no alcohol'),
          equals('/cbf2025/category/low%2Fno%20alcohol'),
        );
      });

      test('encodes query parameters in drinks path', () {
        expect(
          buildDrinksPath('cbf2025', category: 'cider & perry'),
          equals('/cbf2025/drinks?category=cider+%26+perry'), // + is valid for spaces in query params
        );
      });

      test('encodes Unicode characters in style names', () {
        expect(
          buildStylePath('cbf2025', 'Märzen'),
          equals('/cbf2025/style/M%C3%A4rzen'),
        );
      });
    });

    group('Input validation', () {
      test('buildFestivalPath asserts on empty festival ID', () {
        expect(
          () => buildFestivalPath('', '/drinks'),
          throwsAssertionError,
        );
      });

      test('buildFestivalPath asserts on empty path', () {
        expect(
          () => buildFestivalPath('cbf2025', ''),
          throwsAssertionError,
        );
      });

      test('buildDrinkDetailPath asserts on empty drink ID', () {
        expect(
          () => buildDrinkDetailPath('cbf2025', ''),
          throwsAssertionError,
        );
      });

      test('buildBreweryPath asserts on empty brewery ID', () {
        expect(
          () => buildBreweryPath('cbf2025', ''),
          throwsAssertionError,
        );
      });

      test('buildCategoryPath asserts on empty category', () {
        expect(
          () => buildCategoryPath('cbf2025', ''),
          throwsAssertionError,
        );
      });

      test('buildDrinksPath handles empty category gracefully', () {
        expect(
          buildDrinksPath('cbf2025', category: ''),
          equals('/cbf2025/drinks'),
        );
      });
    });

    group('Edge cases', () {
      test('handles very long festival IDs', () {
        final longId = 'x' * 100;
        expect(
          buildFestivalHome(longId),
          equals('/$longId'),
        );
      });

      test('handles paths with multiple slashes', () {
        expect(
          extractFestivalId('/cbf2025//drinks'),
          equals('cbf2025'),
        );
      });

      test('handles paths with trailing slashes', () {
        expect(
          extractFestivalId('/cbf2025/'),
          equals('cbf2025'),
        );
      });

      test('handles URL-encoded characters in IDs', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'test%20drink'),
          equals('/cbf2025/drink/test%2520drink'),
        );
      });
    });
  });
}
