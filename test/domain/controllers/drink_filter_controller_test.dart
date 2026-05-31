import 'package:cambridge_beer_festival/domain/controllers/controllers.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit tests for DrinkFilterController in isolation.
//
// The deep filter/sort *semantics* (availability, vegan, allergens, search
// matching, sort orders) are covered by:
// - test/domain/services/drink_filter_service_test.dart
// - test/domain/services/drink_sort_service_test.dart
//
// These tests focus on what the controller adds on top of those services:
// criteria state management, the derived facet views (with category scoping),
// source management / recompute, and the lifecycle helpers.

Drink _drink({
  required String id,
  required String name,
  required String category,
  String? style,
  String abv = '5.0',
  String? notes,
  Map<String, dynamic> allergens = const {},
  bool isFavorite = false,
  bool isTasted = false,
  String breweryName = 'Test Brewery',
}) {
  final producer = Producer.fromJson({
    'id': 'brewery-$breweryName',
    'name': breweryName,
    'location': 'Cambridge',
    'products': const [],
  });
  final product = Product.fromJson({
    'id': id,
    'name': name,
    'category': category,
    if (style != null) 'style': style,
    'dispense': 'cask',
    'abv': abv,
    if (notes != null) 'notes': notes,
    if (allergens.isNotEmpty) 'allergens': allergens,
  });
  return Drink(
    product: product,
    producer: producer,
    festivalId: 'cbf2025',
    isFavorite: isFavorite,
    isTasted: isTasted,
  );
}

List<Drink> _sampleDrinks() => [
  _drink(id: 'd1', name: 'Alpha Ale', category: 'beer', style: 'IPA'),
  _drink(id: 'd2', name: 'Beta Bitter', category: 'beer', style: 'Bitter'),
  _drink(id: 'd3', name: 'Crisp Cider', category: 'cider', style: 'Dry'),
  _drink(id: 'd4', name: 'Zesty Zider', category: 'cider', style: 'Sweet'),
];

void main() {
  group('DrinkFilterController', () {
    late DrinkFilterController controller;

    setUp(() {
      controller = DrinkFilterController();
    });

    group('initial state', () {
      test('starts empty with default sort and no criteria', () {
        expect(controller.filteredDrinks, isEmpty);
        expect(controller.selectedCategory, isNull);
        expect(controller.selectedStyles, isEmpty);
        expect(controller.currentSort, DrinkSort.nameAsc);
        expect(controller.searchQuery, isEmpty);
        expect(controller.showFavoritesOnly, isFalse);
        expect(controller.visibilityFilters, isEmpty);
        expect(controller.excludedAllergens, isEmpty);
        expect(controller.hideUnavailable, isFalse);
      });
    });

    group('setSource', () {
      test('exposes all drinks sorted by name when no filters active', () {
        controller.setSource(_sampleDrinks());
        expect(controller.filteredDrinks.map((d) => d.name).toList(), [
          'Alpha Ale',
          'Beta Bitter',
          'Crisp Cider',
          'Zesty Zider',
        ]);
      });

      test('replacing the source recomputes the filtered list', () {
        controller.setSource(_sampleDrinks());
        expect(controller.filteredDrinks, hasLength(4));

        controller.setSource([
          _drink(id: 'x', name: 'Only One', category: 'beer'),
        ]);
        expect(controller.filteredDrinks, hasLength(1));
        expect(controller.filteredDrinks.single.name, 'Only One');
      });

      test('empty source yields empty filtered list', () {
        controller.setSource(_sampleDrinks());
        controller.setSource([]);
        expect(controller.filteredDrinks, isEmpty);
      });
    });

    group('category filter', () {
      test('narrows filtered drinks to the selected category', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('cider');
        expect(controller.filteredDrinks.map((d) => d.name), [
          'Crisp Cider',
          'Zesty Zider',
        ]);
      });

      test('setting category clears any active style filter', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('beer');
        controller.toggleStyle('IPA');
        expect(controller.selectedStyles, {'IPA'});

        controller.setCategory('cider');
        expect(controller.selectedStyles, isEmpty);
      });

      test('null category shows all categories again', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('beer');
        controller.setCategory(null);
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('style filter', () {
      test('toggleStyle adds then removes a style', () {
        controller.setSource(_sampleDrinks());
        controller.toggleStyle('IPA');
        expect(controller.selectedStyles, {'IPA'});
        expect(controller.filteredDrinks.map((d) => d.name), ['Alpha Ale']);

        controller.toggleStyle('IPA');
        expect(controller.selectedStyles, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });

      test('multiple styles use OR logic', () {
        controller.setSource(_sampleDrinks());
        controller.toggleStyle('IPA');
        controller.toggleStyle('Dry');
        expect(controller.selectedStyles, {'IPA', 'Dry'});
        expect(controller.filteredDrinks.map((d) => d.name), [
          'Alpha Ale',
          'Crisp Cider',
        ]);
      });

      test('clearStyles removes all style filters', () {
        controller.setSource(_sampleDrinks());
        controller.toggleStyle('IPA');
        controller.clearStyles();
        expect(controller.selectedStyles, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('search filter', () {
      test('matches name and is stored lower-cased', () {
        controller.setSource(_sampleDrinks());
        controller.setSearchQuery('CIDER');
        expect(controller.searchQuery, 'cider');
        expect(controller.filteredDrinks.map((d) => d.name), ['Crisp Cider']);
      });
    });

    group('favorites filter', () {
      test('shows only favourites when enabled', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(isFavorite: true);
        controller.setSource(drinks);

        controller.setShowFavoritesOnly(true);
        expect(controller.filteredDrinks.map((d) => d.name), ['Alpha Ale']);

        controller.setShowFavoritesOnly(false);
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('visibility filters', () {
      test('setVisibilityFilter toggles membership and hideUnavailable', () {
        controller.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          true,
        );
        expect(
          controller.visibilityFilters,
          contains(DrinkVisibilityFilter.availableOnly),
        );
        expect(controller.hideUnavailable, isTrue);

        controller.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          false,
        );
        expect(controller.visibilityFilters, isEmpty);
        expect(controller.hideUnavailable, isFalse);
      });

      test('clearVisibilityFilters removes all', () {
        controller.setVisibilityFilter(DrinkVisibilityFilter.notTasted, true);
        controller.setVisibilityFilter(DrinkVisibilityFilter.veganOnly, true);
        controller.clearVisibilityFilters();
        expect(controller.visibilityFilters, isEmpty);
      });

      test('notTasted filter hides tasted drinks', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(isTasted: true);
        controller.setSource(drinks);
        controller.setVisibilityFilter(DrinkVisibilityFilter.notTasted, true);
        expect(
          controller.filteredDrinks.map((d) => d.name),
          isNot(contains('Alpha Ale')),
        );
        expect(controller.filteredDrinks, hasLength(3));
      });

      test('visibilityFilters getter is unmodifiable', () {
        controller.setVisibilityFilter(DrinkVisibilityFilter.notTasted, true);
        expect(
          () =>
              controller.visibilityFilters.add(DrinkVisibilityFilter.veganOnly),
          throwsUnsupportedError,
        );
      });
    });

    group('allergen filters', () {
      test('excludes drinks containing an excluded allergen', () {
        controller.setSource([
          _drink(
            id: 'a',
            name: 'Gluten Beer',
            category: 'beer',
            allergens: {'gluten': 1},
          ),
          _drink(id: 'b', name: 'Clean Beer', category: 'beer'),
        ]);
        controller.setAllergenFilter('gluten', true);
        expect(controller.filteredDrinks.map((d) => d.name), ['Clean Beer']);

        controller.setAllergenFilter('gluten', false);
        expect(controller.filteredDrinks, hasLength(2));
      });

      test('clearAllergenFilters removes all exclusions', () {
        controller.setAllergenFilter('gluten', true);
        controller.setAllergenFilter('nuts', true);
        controller.clearAllergenFilters();
        expect(controller.excludedAllergens, isEmpty);
      });

      test('excludedAllergens getter is unmodifiable', () {
        controller.setAllergenFilter('gluten', true);
        expect(
          () => controller.excludedAllergens.add('nuts'),
          throwsUnsupportedError,
        );
      });
    });

    group('sort', () {
      test('setSort reorders the filtered list', () {
        controller.setSource(_sampleDrinks());
        controller.setSort(DrinkSort.nameDesc);
        expect(controller.currentSort, DrinkSort.nameDesc);
        expect(controller.filteredDrinks.first.name, 'Zesty Zider');
      });
    });

    group('facet getters', () {
      test('availableCategories is unique and sorted', () {
        controller.setSource(_sampleDrinks());
        expect(controller.availableCategories, ['beer', 'cider']);
      });

      test('categoryCountsMap counts across the full source', () {
        controller.setSource(_sampleDrinks());
        expect(controller.categoryCountsMap, {'beer': 2, 'cider': 2});
      });

      test('availableStyles spans all categories when none selected', () {
        controller.setSource(_sampleDrinks());
        expect(controller.availableStyles, ['Bitter', 'Dry', 'IPA', 'Sweet']);
      });

      test('availableStyles narrows to the selected category', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('cider');
        expect(controller.availableStyles, ['Dry', 'Sweet']);
      });

      test('styleCountsMap narrows to the selected category', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('beer');
        expect(controller.styleCountsMap, {'IPA': 1, 'Bitter': 1});
      });

      test('availableAllergens aggregates keys across the source', () {
        controller.setSource([
          _drink(
            id: 'a',
            name: 'A',
            category: 'beer',
            allergens: {'gluten': 1},
          ),
          _drink(id: 'b', name: 'B', category: 'beer', allergens: {'nuts': 0}),
        ]);
        expect(controller.availableAllergens, {'gluten', 'nuts'});
      });
    });

    group('recompute', () {
      test(
        'reflects favourite change via list replacement when favourites-only',
        () {
          final drinks = _sampleDrinks();
          controller.setSource(drinks);
          controller.setShowFavoritesOnly(true);
          expect(controller.filteredDrinks, isEmpty);

          // Simulate BeerProvider replacing a list element via copyWith, then
          // asking the controller to re-run the pipeline.
          drinks[1] = drinks[1].copyWith(isFavorite: true);
          controller.setSource(drinks);
          expect(controller.filteredDrinks.map((d) => d.name), ['Beta Bitter']);
        },
      );
    });

    group('clearCategoryStyleSearch', () {
      test('resets category, styles and search but keeps sort/visibility', () {
        controller.setSource(_sampleDrinks());
        controller.setCategory('beer');
        controller.toggleStyle('IPA');
        controller.setSearchQuery('alpha');
        controller.setSort(DrinkSort.nameDesc);
        controller.setVisibilityFilter(DrinkVisibilityFilter.notTasted, true);

        controller.clearCategoryStyleSearch();

        expect(controller.selectedCategory, isNull);
        expect(controller.selectedStyles, isEmpty);
        expect(controller.searchQuery, isEmpty);
        // Preserved
        expect(controller.currentSort, DrinkSort.nameDesc);
        expect(
          controller.visibilityFilters,
          contains(DrinkVisibilityFilter.notTasted),
        );
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('hydrate', () {
      test('seeds persisted filters without needing a source', () {
        controller.hydrate(
          visibilityFilters: {DrinkVisibilityFilter.availableOnly},
          excludedAllergens: {'gluten'},
        );
        expect(controller.visibilityFilters, {
          DrinkVisibilityFilter.availableOnly,
        });
        expect(controller.excludedAllergens, {'gluten'});
        expect(controller.hideUnavailable, isTrue);
      });

      test('applies once a source is set', () {
        controller.hydrate(excludedAllergens: {'gluten'});
        controller.setSource([
          _drink(
            id: 'a',
            name: 'Gluten',
            category: 'beer',
            allergens: {'gluten': 1},
          ),
          _drink(id: 'b', name: 'Clean', category: 'beer'),
        ]);
        expect(controller.filteredDrinks.map((d) => d.name), ['Clean']);
      });

      test('null arguments leave existing state unchanged', () {
        controller.setVisibilityFilter(DrinkVisibilityFilter.notTasted, true);
        controller.hydrate();
        expect(controller.visibilityFilters, {DrinkVisibilityFilter.notTasted});
      });
    });
  });
}
