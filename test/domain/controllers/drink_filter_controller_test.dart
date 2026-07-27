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
    userState: (isFavorite || isTasted)
        ? UserDrinkState.initial().copyWith(
            wantToTry: isFavorite,
            tastingEvents: isTasted ? [DateTime(2026, 5, 18)] : const [],
          )
        : null,
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
        expect(controller.selectedCategories, isEmpty);
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
        controller
          ..setSource(_sampleDrinks())
          ..setSource([]);
        expect(controller.filteredDrinks, isEmpty);
      });
    });

    group('category filter', () {
      test('narrows filtered drinks to the selected category', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider');
        expect(controller.filteredDrinks.map((d) => d.name), [
          'Crisp Cider',
          'Zesty Zider',
        ]);
      });

      test('toggleCategory adds then removes a category', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer');
        expect(controller.selectedCategories, {'beer'});
        expect(controller.filteredDrinks, hasLength(2));

        controller.toggleCategory('beer');
        expect(controller.selectedCategories, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });

      test('multiple categories use OR logic', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider')
          ..toggleCategory('beer');
        expect(controller.selectedCategories, {'cider', 'beer'});
        expect(controller.filteredDrinks, hasLength(4));
      });

      test('clearCategories restores all categories', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer')
          ..clearCategories();
        expect(controller.selectedCategories, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });

      test('toggling a category prunes a style that no longer matches the '
          'new scope', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer')
          ..toggleStyle('IPA'); // IPA only exists on a beer drink.
        expect(controller.selectedStyles, {'IPA'});

        // Adding cider alongside beer keeps IPA in scope (beer is still
        // selected) — this is the "don't wipe the whole selection" case.
        controller.toggleCategory('cider');
        expect(controller.selectedStyles, {'IPA'});

        // Removing beer leaves only cider selected; IPA no longer matches
        // any drink in scope, so it is pruned.
        controller.toggleCategory('beer');
        expect(controller.selectedStyles, isEmpty);
      });

      test('toggling a category keeps a style that still matches the new '
          'scope', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider')
          ..toggleStyle('Dry'); // Dry only exists on a cider drink.
        expect(controller.selectedStyles, {'Dry'});

        // Adding beer alongside cider: Dry still matches (cider is still
        // selected), so it survives the prune. The style filter still
        // narrows the result to just the Dry cider, though — category and
        // style filters combine with AND.
        controller.toggleCategory('beer');
        expect(controller.selectedStyles, {'Dry'});
        expect(controller.filteredDrinks.map((d) => d.name), ['Crisp Cider']);
      });
    });

    group('style filter', () {
      test('toggleStyle adds then removes a style', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleStyle('IPA');
        expect(controller.selectedStyles, {'IPA'});
        expect(controller.filteredDrinks.map((d) => d.name), ['Alpha Ale']);

        controller.toggleStyle('IPA');
        expect(controller.selectedStyles, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });

      test('multiple styles use OR logic', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleStyle('IPA')
          ..toggleStyle('Dry');
        expect(controller.selectedStyles, {'IPA', 'Dry'});
        expect(controller.filteredDrinks.map((d) => d.name), [
          'Alpha Ale',
          'Crisp Cider',
        ]);
      });

      test('clearStyles removes all style filters', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleStyle('IPA')
          ..clearStyles();
        expect(controller.selectedStyles, isEmpty);
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('search filter', () {
      test('matches name and is stored lower-cased', () {
        controller
          ..setSource(_sampleDrinks())
          ..setSearchQuery('CIDER');
        expect(controller.searchQuery, 'cider');
        expect(controller.filteredDrinks.map((d) => d.name), ['Crisp Cider']);
      });
    });

    group('favorites filter', () {
      test('shows only favourites when enabled', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        );
        controller
          ..setSource(drinks)
          ..setShowFavoritesOnly(value: true);
        expect(controller.filteredDrinks.map((d) => d.name), ['Alpha Ale']);

        controller.setShowFavoritesOnly(value: false);
        expect(controller.filteredDrinks, hasLength(4));
      });
    });

    group('visibility filters', () {
      test('setVisibilityFilter toggles membership and hideUnavailable', () {
        controller.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          active: true,
        );
        expect(
          controller.visibilityFilters,
          contains(DrinkVisibilityFilter.availableOnly),
        );
        expect(controller.hideUnavailable, isTrue);

        controller.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          active: false,
        );
        expect(controller.visibilityFilters, isEmpty);
        expect(controller.hideUnavailable, isFalse);
      });

      test('clearVisibilityFilters removes all', () {
        controller
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true)
          ..setVisibilityFilter(DrinkVisibilityFilter.veganOnly, active: true)
          ..clearVisibilityFilters();
        expect(controller.visibilityFilters, isEmpty);
      });

      test('notTasted filter hides tasted drinks', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        controller
          ..setSource(drinks)
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true);
        expect(
          controller.filteredDrinks.map((d) => d.name),
          isNot(contains('Alpha Ale')),
        );
        expect(controller.filteredDrinks, hasLength(3));
      });

      test('visibilityFilters getter is unmodifiable', () {
        controller.setVisibilityFilter(
          DrinkVisibilityFilter.notTasted,
          active: true,
        );
        expect(
          () =>
              controller.visibilityFilters.add(DrinkVisibilityFilter.veganOnly),
          throwsUnsupportedError,
        );
      });
    });

    group('allergen filters', () {
      test('excludes drinks containing an excluded allergen', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten Beer',
              category: 'beer',
              allergens: {'gluten': 1},
            ),
            _drink(id: 'b', name: 'Clean Beer', category: 'beer'),
          ])
          ..setAllergenFilter('gluten', active: true);
        expect(controller.filteredDrinks.map((d) => d.name), ['Clean Beer']);

        controller.setAllergenFilter('gluten', active: false);
        expect(controller.filteredDrinks, hasLength(2));
      });

      test('clearAllergenFilters removes all exclusions', () {
        controller
          ..setAllergenFilter('gluten', active: true)
          ..setAllergenFilter('nuts', active: true)
          ..clearAllergenFilters();
        expect(controller.excludedAllergens, isEmpty);
      });

      test('excludedAllergens getter is unmodifiable', () {
        controller.setAllergenFilter('gluten', active: true);
        expect(
          () => controller.excludedAllergens.add('nuts'),
          throwsUnsupportedError,
        );
      });
    });

    group('sort', () {
      test('setSort reorders the filtered list', () {
        controller
          ..setSource(_sampleDrinks())
          ..setSort(DrinkSort.nameDesc);
        expect(controller.currentSort, DrinkSort.nameDesc);
        expect(controller.filteredDrinks.first.name, 'Zesty Zider');
      });
    });

    // Facet scoping rule under test: each facet is derived from the source
    // with every *other* structural filter applied, but never its own. See
    // the class doc on DrinkFilterController for the full statement.

    group('category facet scoping', () {
      test('availableCategories and categoryCountsMap span the full source '
          'when no other filter is active', () {
        controller.setSource(_sampleDrinks());
        expect(controller.availableCategories, ['beer', 'cider']);
        expect(controller.categoryCountsMap, {'beer': 2, 'cider': 2});
      });

      test('categories narrow when a style filter is active', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleStyle('IPA'); // IPA only exists on a beer drink.
        expect(controller.availableCategories, ['beer']);
        expect(controller.categoryCountsMap, {'beer': 1});
      });

      test('categories narrow when favourites-only is active', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        ); // Alpha Ale (beer) is the only favourite.
        controller
          ..setSource(drinks)
          ..setShowFavoritesOnly(value: true);
        expect(controller.availableCategories, ['beer']);
        expect(controller.categoryCountsMap, {'beer': 1});
      });

      test('categories narrow when a visibility filter is active', () {
        final drinks = _sampleDrinks();
        // Mark both beer drinks tasted so the entire category drops out
        // under the not-tasted filter.
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        drinks[1] = drinks[1].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        controller
          ..setSource(drinks)
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true);
        expect(controller.availableCategories, ['cider']);
        expect(controller.categoryCountsMap, {'cider': 2});
      });

      test('categories narrow when an allergen exclusion is active', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten Pale',
              category: 'beer',
              allergens: {'gluten': 1},
            ),
            _drink(id: 'b', name: 'Only Cider', category: 'cider'),
          ])
          ..setAllergenFilter('gluten', active: true);
        expect(controller.availableCategories, ['cider']);
        expect(controller.categoryCountsMap, {'cider': 1});
      });

      test('category facet does not narrow itself — selecting one category '
          'still lists the others', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer');
        expect(controller.availableCategories, ['beer', 'cider']);
        expect(controller.categoryCountsMap, {'beer': 2, 'cider': 2});
      });
    });

    group('style facet scoping', () {
      test('availableStyles spans all categories when none selected', () {
        controller.setSource(_sampleDrinks());
        expect(controller.availableStyles, ['Bitter', 'Dry', 'IPA', 'Sweet']);
      });

      test('availableStyles narrows to the selected category', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider');
        expect(controller.availableStyles, ['Dry', 'Sweet']);
      });

      test('availableStyles sorts case-insensitively, not by code unit', () {
        // A plain List.sort() compares code units, so every upper-case style
        // would sort before any lower-case one ('Stout' before 'ipa'). The
        // controller sorts case-insensitively, so 'ipa' falls between 'Bitter'
        // and 'Stout'. This sorting now lives here, not in the filter sheet.
        controller.setSource([
          _drink(id: 's1', name: 'A', category: 'beer', style: 'Stout'),
          _drink(id: 's2', name: 'B', category: 'beer', style: 'ipa'),
          _drink(id: 's3', name: 'C', category: 'beer', style: 'Bitter'),
        ]);
        expect(controller.availableStyles, ['Bitter', 'ipa', 'Stout']);
      });

      test('styleCountsMap narrows to the selected category', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer');
        expect(controller.styleCountsMap, {'IPA': 1, 'Bitter': 1});
      });

      test('styles narrow when favourites-only is active', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        ); // Alpha Ale (style IPA) is the only favourite.
        controller
          ..setSource(drinks)
          ..setShowFavoritesOnly(value: true);
        expect(controller.availableStyles, ['IPA']);
        expect(controller.styleCountsMap, {'IPA': 1});
      });

      test('styles narrow when a visibility filter is active', () {
        final drinks = _sampleDrinks();
        // Tag every drink except Crisp Cider (style Dry) as tasted.
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        drinks[1] = drinks[1].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        drinks[3] = drinks[3].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        controller
          ..setSource(drinks)
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true);
        expect(controller.availableStyles, ['Dry']);
        expect(controller.styleCountsMap, {'Dry': 1});
      });

      test('styles narrow when an allergen exclusion is active', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten IPA',
              category: 'beer',
              style: 'IPA',
              allergens: {'gluten': 1},
            ),
            _drink(
              id: 'b',
              name: 'Clean Stout',
              category: 'beer',
              style: 'Stout',
            ),
          ])
          ..setAllergenFilter('gluten', active: true);
        expect(controller.availableStyles, ['Stout']);
        expect(controller.styleCountsMap, {'Stout': 1});
      });

      test('style facet does not narrow itself — selecting one style still '
          'lists the others', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleStyle('IPA');
        expect(controller.availableStyles, ['Bitter', 'Dry', 'IPA', 'Sweet']);
        expect(controller.styleCountsMap, {
          'IPA': 1,
          'Bitter': 1,
          'Dry': 1,
          'Sweet': 1,
        });
      });
    });

    group('allergen facet scoping', () {
      test('availableAllergens narrows to the selected category', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten Beer',
              category: 'beer',
              allergens: {'gluten': 1},
            ),
            _drink(
              id: 'b',
              name: 'Nutty Cider',
              category: 'cider',
              allergens: {'nuts': 1},
            ),
          ])
          ..toggleCategory('beer');
        expect(controller.availableAllergens, {'gluten'});
      });

      test('availableAllergens narrows to the selected style', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten IPA',
              category: 'beer',
              style: 'IPA',
              allergens: {'gluten': 1},
            ),
            _drink(
              id: 'b',
              name: 'Nutty Stout',
              category: 'beer',
              style: 'Stout',
              allergens: {'nuts': 1},
            ),
          ])
          ..toggleStyle('IPA');
        expect(controller.availableAllergens, {'gluten'});
      });

      test('availableAllergens narrows when favourites-only is active', () {
        final favourite =
            _drink(
              id: 'a',
              name: 'Gluten Beer',
              category: 'beer',
              allergens: {'gluten': 1},
            ).copyWith(
              userState: UserDrinkState.initial().copyWith(wantToTry: true),
            );
        controller
          ..setSource([
            favourite,
            _drink(
              id: 'b',
              name: 'Nutty Beer',
              category: 'beer',
              allergens: {'nuts': 1},
            ),
          ])
          ..setShowFavoritesOnly(value: true);
        expect(controller.availableAllergens, {'gluten'});
      });

      test('allergen facet does not narrow itself — excluding one allergen '
          'still lists the others', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten Beer',
              category: 'beer',
              allergens: {'gluten': 1},
            ),
            _drink(
              id: 'b',
              name: 'Nutty Beer',
              category: 'beer',
              allergens: {'nuts': 1},
            ),
          ])
          ..setAllergenFilter('gluten', active: true);
        expect(controller.availableAllergens, {'gluten', 'nuts'});
      });
    });

    group('facet invariant: an active filter is never hidden', () {
      test('selected category with a scoped count of 0 is still listed, with '
          'count 0', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider')
          ..toggleStyle('IPA'); // IPA has no cider drinks.
        expect(controller.selectedCategories, {'cider'});
        expect(controller.availableCategories, containsAll(['beer', 'cider']));
        expect(controller.categoryCountsMap['cider'], 0);
        expect(controller.categoryCountsMap['beer'], 1);
      });

      test('selected style with a scoped count of 0 is still listed, with '
          'count 0', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('cider')
          ..toggleStyle('IPA'); // IPA has no cider drinks.
        expect(controller.selectedStyles, {'IPA'});
        expect(
          controller.availableStyles,
          containsAll(['Dry', 'Sweet', 'IPA']),
        );
        expect(controller.styleCountsMap['IPA'], 0);
        expect(controller.styleCountsMap['Dry'], 1);
        expect(controller.styleCountsMap['Sweet'], 1);
      });

      test(
        'excluded allergen with nothing matching in scope is still listed',
        () {
          controller
            ..setSource([_drink(id: 'a', name: 'Clean Beer', category: 'beer')])
            ..setAllergenFilter('gluten', active: true);
          expect(controller.excludedAllergens, {'gluten'});
          expect(controller.availableAllergens, contains('gluten'));
        },
      );

      test('ticking a scoped-narrowed category option yields exactly the '
          'stated count', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        ); // Alpha Ale (beer) is the only favourite.
        controller
          ..setSource(drinks)
          ..setShowFavoritesOnly(value: true);
        expect(controller.categoryCountsMap, {'beer': 1});

        controller.toggleCategory('beer');
        expect(controller.filteredDrinks, hasLength(1));
        expect(controller.filteredDrinks.single.name, 'Alpha Ale');
      });

      test('ticking a scoped-narrowed style option yields exactly the stated '
          'count', () {
        final drinks = _sampleDrinks();
        drinks[0] = drinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        ); // Alpha Ale (style IPA) is the only favourite.
        controller
          ..setSource(drinks)
          ..setShowFavoritesOnly(value: true);
        expect(controller.styleCountsMap, {'IPA': 1});

        controller.toggleStyle('IPA');
        expect(controller.filteredDrinks, hasLength(1));
        expect(controller.filteredDrinks.single.name, 'Alpha Ale');
      });

      test('ticking a scoped-narrowed allergen exclusion yields exactly the '
          'stated filtered result', () {
        controller.setSource([
          _drink(
            id: 'a',
            name: 'Gluten Beer',
            category: 'beer',
            allergens: {'gluten': 1},
          ),
          _drink(id: 'b', name: 'Clean Beer', category: 'beer'),
        ]);
        expect(controller.availableAllergens, {'gluten'});

        controller.setAllergenFilter('gluten', active: true);
        expect(controller.filteredDrinks.map((d) => d.name), ['Clean Beer']);
      });
    });

    group('allergen presence (only non-zero counts as present)', () {
      test('an allergen key present only with value 0 is not listed', () {
        controller.setSource([
          _drink(id: 'a', name: 'A', category: 'beer', allergens: {'nuts': 0}),
        ]);
        expect(controller.availableAllergens, isNot(contains('nuts')));
      });

      test('an allergen key is listed once some drink in scope has it '
          'non-zero', () {
        controller.setSource([
          _drink(id: 'a', name: 'A', category: 'beer', allergens: {'nuts': 0}),
          _drink(id: 'b', name: 'B', category: 'beer', allergens: {'nuts': 1}),
        ]);
        expect(controller.availableAllergens, contains('nuts'));
      });

      test('an allergen key is listed when currently selected even if scope '
          'only has it zeroed', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'A',
              category: 'beer',
              allergens: {'nuts': 0},
            ),
          ])
          ..setAllergenFilter('nuts', active: true);
        expect(controller.availableAllergens, contains('nuts'));
      });

      test('bool and numeric allergen values are honoured by the presence '
          'check, not just int', () {
        // Product.fromJson already normalises bool/num allergen values to
        // int at parse time — confirm the facet respects that normalised
        // value rather than assuming the raw map is always int-valued.
        controller.setSource([
          _drink(
            id: 'a',
            name: 'A',
            category: 'beer',
            allergens: {'gluten': false, 'nuts': 2.0, 'milk': true},
          ),
        ]);
        expect(controller.availableAllergens, {'nuts', 'milk'});
      });
    });

    group('search query does not affect facets', () {
      test('search narrows filteredDrinks but not category/style facets', () {
        controller
          ..setSource(_sampleDrinks())
          ..setSearchQuery('alpha');
        expect(controller.filteredDrinks.map((d) => d.name), ['Alpha Ale']);
        expect(controller.availableCategories, ['beer', 'cider']);
        expect(controller.categoryCountsMap, {'beer': 2, 'cider': 2});
        expect(controller.availableStyles, ['Bitter', 'Dry', 'IPA', 'Sweet']);
        expect(controller.styleCountsMap, {
          'IPA': 1,
          'Bitter': 1,
          'Dry': 1,
          'Sweet': 1,
        });
      });

      test('search narrows filteredDrinks but not the allergen facet', () {
        controller
          ..setSource([
            _drink(
              id: 'a',
              name: 'Gluten Beer',
              category: 'beer',
              allergens: {'gluten': 1},
            ),
            _drink(id: 'b', name: 'Clean Cider', category: 'cider'),
          ])
          ..setSearchQuery('clean');
        expect(controller.filteredDrinks.map((d) => d.name), ['Clean Cider']);
        expect(controller.availableAllergens, {'gluten'});
      });
    });

    group('recompute', () {
      test(
        'reflects favourite change via list replacement when favourites-only',
        () {
          final drinks = _sampleDrinks();
          controller
            ..setSource(drinks)
            ..setShowFavoritesOnly(value: true);
          expect(controller.filteredDrinks, isEmpty);

          // Simulate BeerProvider replacing a list element via copyWith, then
          // asking the controller to re-run the pipeline.
          drinks[1] = drinks[1].copyWith(
            userState: UserDrinkState.initial().copyWith(wantToTry: true),
          );
          controller.setSource(drinks);
          expect(controller.filteredDrinks.map((d) => d.name), ['Beta Bitter']);
        },
      );
    });

    group('clearCategoryStyleSearch', () {
      test('resets category, styles and search but keeps sort/visibility', () {
        controller
          ..setSource(_sampleDrinks())
          ..toggleCategory('beer')
          ..toggleStyle('IPA')
          ..setSearchQuery('alpha')
          ..setSort(DrinkSort.nameDesc)
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true)
          ..clearCategoryStyleSearch();

        expect(controller.selectedCategories, isEmpty);
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
        controller
          ..hydrate(excludedAllergens: {'gluten'})
          ..setSource([
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
        controller
          ..setVisibilityFilter(DrinkVisibilityFilter.notTasted, active: true)
          ..hydrate();
        expect(controller.visibilityFilters, {DrinkVisibilityFilter.notTasted});
      });
    });
  });
}
