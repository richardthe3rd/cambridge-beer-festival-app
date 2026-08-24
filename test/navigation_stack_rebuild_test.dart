// Rebuild-scope guard for the navigation push stack — the measurement that
// closed issue #477.
//
// Since #470 every drill-down uses context.push(), so a chain of
// drink → similar drink → similar drink hops leaves each previous
// DrinkDetailScreen mounted underneath the visible one. #477 asked whether
// that unbounded growth needs capping. The answer was no, but only because of
// where the rebuild boundary sits today, and that boundary is easy to move by
// accident. This file pins both halves of it:
//
//  * An unrelated provider change rebuilds NO screen in the stack, at any
//    depth. This is what #523's narrowing bought (#554/#557/#559/#569 replaced
//    the bare context.watch<BeerProvider>() in the detail screens with
//    per-concern selects); widening any of those subscriptions back out would
//    make the cost of a theme toggle scale with how deep the user has drilled.
//
//  * A personal-state write rebuilds EVERY screen in the stack — exactly
//    `depth` of them — even when the drink written to is displayed by none of
//    them. This is the residual cost #477 measured and accepted: allDrinks is
//    a fresh List on every _replaceDrink (beer_provider.dart:840), and the
//    screens' identity-based `shouldRebuild` cannot tell "my drink changed"
//    from "some other drink changed". It is pinned so the accepted cost stays
//    the measured one; if a future change makes detail screens observe their
//    own drink instead, this expectation is the thing that should be updated
//    deliberately (see #477 for that option and its trade-off).
//
// Exercises the real production appRouter rather than a stub route table, so
// the stack under test is the one users actually build up.
import 'dart:async';

import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';
import 'router_test_constants.dart';

/// Every drink shares a brewery and style so each detail screen renders a full
/// Similar Drinks carousel — the widest subtree a buried screen can rebuild.
///
/// The carousel is capped at ten entries taken in list order, so only
/// `drink-0`..`drink-10` ever appear in one. Anything above that index is
/// guaranteed to be displayed by no screen in the stack, which is what
/// [_unrelatedDrinkId] relies on.
List<Drink> createSampleDrinks(int count) {
  final producer = Producer.fromJson({
    'id': 'brewery-1',
    'name': 'Test Brewery',
    'location': 'Cambridge',
    'products': <Map<String, dynamic>>[],
  });

  return List.generate(count, (i) {
    final product = Product.fromJson({
      'id': 'drink-$i',
      'name': 'Test Drink $i',
      'category': 'beer',
      'style': 'IPA',
      'dispense': 'cask',
      'abv': '5.0',
    });
    return Drink(
      product: product,
      producer: producer,
      festivalId: testFestivalId,
    );
  });
}

/// A drink far enough down the catalogue that it is neither the subject of any
/// pushed screen nor a member of any screen's Similar Drinks carousel.
const String _unrelatedDrinkId = 'drink-30';

void main() {
  group('Rebuild scope across a pushed detail stack (#477)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;
    late List<Drink> drinks;

    setUp(() async {
      DrinkDetailScreen.debugBuildCount = 0;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      drinks = createSampleDrinks(40);

      const testFestival = Festival(
        id: testFestivalId,
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [testFestival],
          defaultFestivalId: testFestivalId,
          baseUrl: 'https://example.com',
          version: '1.0.0',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => drinks);
      when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
        (_) async => UserDrinkState(
          wantToTry: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    /// Pumps the real router at the drinks list, then pushes [depth] drink
    /// detail routes (`drink-0`, `drink-1`, …) the way tapping through Similar
    /// Drinks does. The visible screen ends up showing `drink-${depth - 1}`.
    Future<void> pushDetailStack(WidgetTester tester, int depth) async {
      final router = buildAppRouter();
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go('/$testFestivalId');
      await tester.pumpAndSettle();

      for (var i = 0; i < depth; i++) {
        unawaited(
          router.push<Object?>(
            buildDrinkDetailPath(testFestivalId, 'beer', 'drink-$i'),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.byType(DrinkDetailScreen, skipOffstage: false),
        findsNWidgets(depth),
        reason:
            'Test setup check: push() must leave every previous detail screen '
            'mounted underneath the visible one (#470)',
      );
    }

    /// Scopes a finder to one screen in the stack, using the ValueKey the
    /// router assigns each DrinkDetailScreen (`router.dart`).
    Finder inScreenFor(String drinkId, Finder matching) => find.descendant(
      of: find.byKey(ValueKey('$testFestivalId/$drinkId')),
      matching: matching,
    );

    testWidgets(
      'a provider change no detail screen renders rebuilds none of them, '
      'however deep the stack',
      (tester) async {
        const depth = 4;
        await pushDetailStack(tester, depth);

        final countBefore = DrinkDetailScreen.debugBuildCount;
        expect(
          countBefore,
          greaterThan(0),
          reason: 'Test setup check: the screens must have built at least once',
        );

        // searchQuery belongs to DrinksScreen; themeMode to the app shell.
        // Neither is selected by any detail screen.
        provider.setSearchQuery('ipa');
        await tester.pump();
        await provider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          DrinkDetailScreen.debugBuildCount,
          countBefore,
          reason:
              'An unrelated provider change must not rebuild any screen in '
              'the stack — otherwise the cost of a theme toggle scales with '
              'navigation depth (#523/#477)',
        );
      },
    );

    for (final depth in [1, 2, 4]) {
      testWidgets(
        'a personal-state write on an undisplayed drink rebuilds all $depth '
        'screen(s) in the stack and changes nothing on screen',
        (tester) async {
          await pushDetailStack(tester, depth);

          final visibleDrinkId = 'drink-${depth - 1}';
          expect(
            inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark_border)),
            findsOneWidget,
            reason: 'Test setup check: the visible drink starts un-favourited',
          );

          final unrelated = provider.getDrinkById(_unrelatedDrinkId)!;
          DrinkDetailScreen.debugBuildCount = 0;
          await provider.toggleFavorite(unrelated);
          await tester.pumpAndSettle();

          expect(
            DrinkDetailScreen.debugBuildCount,
            depth,
            reason:
                'Every screen in the stack rebuilds on any personal-state '
                'write, because allDrinks is a fresh List on every '
                '_replaceDrink. This is the accepted cost measured in #477; '
                'changing it is a deliberate decision, not a drive-by',
          );

          // Deep assertion: all that rebuilding changed nothing the user can
          // see, on the visible screen or on the one directly beneath it.
          expect(provider.getDrinkById(_unrelatedDrinkId)!.isFavorite, isTrue);
          expect(
            inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark_border)),
            findsOneWidget,
          );
          expect(
            inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark)),
            findsNothing,
          );
          expect(
            inScreenFor(visibleDrinkId, find.text('Test Drink ${depth - 1}')),
            findsWidgets,
          );
        },
      );
    }

    testWidgets(
      'control: a personal-state write on the visible drink rebuilds the same '
      'screens and does change what is on screen',
      (tester) async {
        const depth = 4;
        await pushDetailStack(tester, depth);

        const visibleDrinkId = 'drink-3';
        final visible = provider.getDrinkById(visibleDrinkId)!;
        expect(
          inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark_border)),
          findsOneWidget,
        );

        DrinkDetailScreen.debugBuildCount = 0;
        await provider.toggleFavorite(visible);
        await tester.pumpAndSettle();

        expect(
          DrinkDetailScreen.debugBuildCount,
          depth,
          reason:
              'The write path is the same whichever drink is written to, so '
              'the rebuild count does not depend on which one it was',
        );
        // The user-visible half: this drink's want-to-try actually flips.
        expect(provider.getDrinkById(visibleDrinkId)!.isFavorite, isTrue);
        expect(
          inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark)),
          findsOneWidget,
        );
        expect(
          inScreenFor(visibleDrinkId, find.byIcon(Icons.bookmark_border)),
          findsNothing,
        );
      },
    );
  });
}
