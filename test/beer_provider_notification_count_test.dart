// Notification-volume guard for the decision recorded in ADR 0007 (#556/#577).
//
// #577's premise was that BeerProvider's single notification channel is
// chatty: 28 `notifyListeners()` call sites, and `context.select` suppresses
// the *rebuild* but not the *wake-up*, so every mounted selector re-evaluates
// on every notification. ADR 0007 declined the four-provider split on the
// strength of two measurements, and this file pins the one that is
// deterministic enough to assert on.
//
// The measured fact: **28 call sites are not 28 fires.** Every user action
// costs exactly one notification, and a catalogue load costs two (the
// loading-state flip, then the loaded data). A whole realistic session is
// ~20 notifications, not hundreds. That is what makes the per-wake-up cost
// (~0.9us for DrinksScreen's entire 15-selector set at 500 drinks, and
// unmeasurable against the re-filter it follows) round to nothing.
//
// If this goes red, an action has started firing a burst and ADR 0007's
// arithmetic needs redoing before the extra fires are accepted. Deliberately
// asserts counts, not timings — wall-clock thresholds are flaky in CI, so the
// timings live in the ADR and were taken by a throwaway probe (see the ADR's
// Method section for how to reproduce them).
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

const Festival _otherFestival = Festival(
  id: 'cbf2024',
  name: 'Cambridge Beer Festival 2024',
  dataBaseUrl: 'https://test.example.com/cbf2024',
);

void main() {
  group('BeerProvider notification volume (ADR 0007, #556/#577)', () {
    late AppHarness harness;
    late int notifications;

    setUp(() async {
      harness = await AppHarness.create(
        festivals: const [defaultTestFestival, _otherFestival],
        drinksByFestival: {
          defaultTestFestival.id: createSampleDrinks(40),
          _otherFestival.id: createSampleDrinks(
            30,
            festivalId: _otherFestival.id,
          ),
        },
      );
      notifications = 0;
      harness.provider.addListener(() => notifications++);
    });

    tearDown(() {
      harness.dispose();
    });

    /// Runs [action] and returns how many notifications it fired.
    Future<int> fires(Future<void> Function() action) async {
      final before = notifications;
      await action();
      return notifications - before;
    }

    test('every filter, sort and search action fires exactly one', () async {
      final provider = harness.provider;

      expect(
        await fires(() async => provider.setSearchQuery('test')),
        1,
        reason: 'A keystroke must not fan out into several notifications',
      );
      expect(await fires(() async => provider.toggleCategory('beer')), 1);
      expect(await fires(() async => provider.clearCategories()), 1);
      expect(await fires(() async => provider.toggleStyle('IPA')), 1);
      expect(await fires(() async => provider.clearStyles()), 1);
      expect(await fires(() async => provider.setSort(DrinkSort.abvHigh)), 1);
      expect(
        await fires(() async => provider.setShowFavoritesOnly(value: true)),
        1,
      );
      expect(
        await fires(
          () => provider.setVisibilityFilter(
            DrinkVisibilityFilter.availableOnly,
            active: true,
          ),
        ),
        1,
        reason:
            'The persist() that follows must not notify a second time — it '
            'changes nothing any widget renders',
      );
      expect(await fires(provider.clearVisibilityFilters), 1);
      expect(
        await fires(() => provider.setAllergenFilter('gluten', active: true)),
        1,
      );
      expect(await fires(provider.clearAllergenFilters), 1);
      expect(await fires(() => provider.setThemeMode(ThemeMode.dark)), 1);
    });

    test('every personal-state write fires exactly one', () async {
      final provider = harness.provider;
      final drink = provider.allDrinks.first;
      final other = provider.allDrinks[1];

      expect(await fires(() => provider.toggleFavorite(drink)), 1);
      expect(await fires(() => provider.setRating(drink, 4)), 1);
      expect(await fires(() => provider.toggleTasted(drink)), 1);
      expect(await fires(() async => provider.addTasting(other)), 1);
      expect(
        await fires(() => provider.setUserNotes(other, 'Malty, moreish')),
        1,
      );
    });

    test(
      'a catalogue load fires two: the loading flip, then the data',
      () async {
        final provider = harness.provider;

        expect(
          await fires(provider.loadDrinks),
          2,
          reason:
              'One for isRefreshing/isLoading going true, one for the loaded '
              'catalogue. A third would mean an intermediate state is being '
              'broadcast that no widget needs.',
        );
        expect(
          await fires(() => provider.setFestival(_otherFestival)),
          2,
          reason: 'A festival switch is one catalogue load, not two',
        );
        expect(
          provider.currentFestival.id,
          _otherFestival.id,
          reason: 'Test setup check: the switch must actually have happened',
        );
        expect(
          provider.allDrinks,
          hasLength(30),
          reason: "…and served the new festival's catalogue, not the old one",
        );
      },
    );

    test('a realistic session stays in the tens, not the hundreds', () async {
      // Browse: land, search, narrow by category, sort.
      final provider = harness.provider
        ..setSearchQuery('test')
        ..toggleCategory('beer')
        ..setSort(DrinkSort.abvHigh)
        ..setSearchQuery('');

      // Drink: rate and log five of them, the way a festival session goes.
      for (var i = 0; i < 5; i++) {
        await provider.toggleFavorite(provider.allDrinks[i]);
        await provider.setRating(provider.allDrinks[i], 4);
        await provider.addTasting(provider.allDrinks[i]);
      }

      // Fiddle: switch festival and back, flip the theme.
      await provider.setFestival(_otherFestival);
      await provider.setFestival(defaultTestFestival);
      await provider.setThemeMode(ThemeMode.dark);

      expect(
        notifications,
        lessThanOrEqualTo(30),
        reason:
            'ADR 0007 measured ~20 for a session of this shape. The margin is '
            'for added actions, not for an action that fans out — if this '
            'fails, find which one now fires more than once.',
      );
    });
  });
}
