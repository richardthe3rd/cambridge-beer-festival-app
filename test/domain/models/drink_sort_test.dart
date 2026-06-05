import 'package:cambridge_beer_festival/domain/models/drink_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DrinkSortLabel', () {
    test('every sort option has a human-readable label', () {
      const expected = {
        DrinkSort.nameAsc: 'Name (A-Z)',
        DrinkSort.nameDesc: 'Name (Z-A)',
        DrinkSort.abvHigh: 'ABV (High to Low)',
        DrinkSort.abvLow: 'ABV (Low to High)',
        DrinkSort.brewery: 'Brewery (A-Z)',
        DrinkSort.style: 'Style (A-Z)',
      };

      for (final sort in DrinkSort.values) {
        expect(sort.label, expected[sort], reason: 'label for $sort');
      }
    });

    test('labels are unique across all sort options', () {
      final labels = DrinkSort.values.map((s) => s.label).toSet();
      expect(labels.length, DrinkSort.values.length);
    });
  });
}
