// Shared harness for tests that drive a multi-screen *user journey* through
// the real production router, rather than mounting one screen in isolation.
//
// Before this file existed, the two tests that worked at this scope
// (drinks_screen_scroll_position_test.dart, navigation_stack_rebuild_test.dart)
// each hand-rolled ~60 lines of identical mockito wiring in their own setUp.
// That boilerplate — not the tooling — is why the repo has so few journey
// tests: ADR 0005 deferred Flutter's `integration_test` package, and the
// widget layer can already drive these flows in-process, in ~100ms, with no
// device or chromedriver in CI (issue #314).
//
// Usage:
//
// ```dart
// late AppHarness harness;
// setUp(() async => harness = await AppHarness.create());
// tearDown(() => harness.dispose());
//
// testWidgets('...', (tester) async {
//   await harness.pump(tester);
//   await tester.tap(find.byKey(const ValueKey('drink-3')));
//   await tester.pumpAndSettle();
// });
// ```
library;

import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';
import '../router_test_constants.dart';

/// Builds [count] drinks that all share one brewery and one style, so every
/// drink detail screen renders a full Similar Drinks carousel — the widest
/// subtree a journey can put on screen.
///
/// The carousel is capped at ten entries taken in list order, so only
/// `drink-0`..`drink-10` ever appear in one. Any index above that is
/// guaranteed to be displayed by no screen in the stack, which is what
/// navigation_stack_rebuild_test.dart's "unrelated drink" relies on.
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

/// The festival every harness serves unless [AppHarness.create] is given
/// others. Matches [testFestivalId] so paths built by the typed helpers in
/// `lib/utils/navigation_helpers.dart` resolve against it.
const Festival defaultTestFestival = Festival(
  id: testFestivalId,
  name: 'Cambridge Beer Festival 2025',
  dataBaseUrl: 'https://test.example.com/cbf2025',
);

/// A mounted app under test: mocked repositories, a real [BeerProvider] that
/// has completed `initialize()`/`loadDrinks()`, and the real production route
/// table from [buildAppRouter].
class AppHarness {
  AppHarness._({
    required this.provider,
    required this.drinkRepository,
    required this.festivalRepository,
    required this.analyticsService,
    required this.drinks,
    required this.festivals,
  });

  final BeerProvider provider;
  final MockDrinkRepository drinkRepository;
  final MockFestivalRepository festivalRepository;
  final MockAnalyticsService analyticsService;
  final List<Drink> drinks;
  final List<Festival> festivals;

  GoRouter? _router;

  /// The router mounted by [pump]. Throws if read before [pump].
  GoRouter get router {
    final router = _router;
    if (router == null) {
      throw StateError(
        'AppHarness.pump() must be called before reading router',
      );
    }
    return router;
  }

  /// The festival the app opens at.
  Festival get festival => festivals.first;

  /// Wires the mocks, builds a [BeerProvider] over them, and drives it through
  /// `initialize()` and `loadDrinks()` so the drinks list has content before
  /// the first frame.
  ///
  /// Call from `setUp`; pair with [dispose] in `tearDown`.
  static Future<AppHarness> create({
    int drinkCount = 40,
    List<Drink>? drinks,
    List<Festival>? festivals,
    String? selectedFestivalId,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final drinkRepository = MockDrinkRepository();
    final festivalRepository = MockFestivalRepository();
    final analyticsService = MockAnalyticsService();

    final resolvedFestivals = festivals ?? const [defaultTestFestival];
    final resolvedDrinks = drinks ?? createSampleDrinks(drinkCount);

    when(festivalRepository.getFestivals()).thenAnswer(
      (_) async => FestivalsResponse(
        festivals: resolvedFestivals,
        defaultFestivalId: resolvedFestivals.first.id,
        baseUrl: 'https://example.com',
        version: '1.0.0',
      ),
    );
    when(
      festivalRepository.getSelectedFestivalId(),
    ).thenAnswer((_) async => selectedFestivalId);
    when(
      drinkRepository.getDrinks(any),
    ).thenAnswer((_) async => resolvedDrinks);
    _stubFavouriteToggle(drinkRepository);

    final provider = BeerProvider(
      drinkRepository: drinkRepository,
      festivalRepository: festivalRepository,
      analyticsService: analyticsService,
    );
    await provider.initialize();
    await provider.loadDrinks();

    return AppHarness._(
      provider: provider,
      drinkRepository: drinkRepository,
      festivalRepository: festivalRepository,
      analyticsService: analyticsService,
      drinks: resolvedDrinks,
      festivals: resolvedFestivals,
    );
  }

  /// Stubs `toggleFavorite` with an in-memory store that flips per
  /// `(festivalId, drinkId)`, mirroring `ApiDrinkRepository.toggleFavorite`:
  /// it returns the resulting record when the drink is now want-to-try, and
  /// `null` when it is not — because the real store prunes a record carrying
  /// no user signal, and `BeerProvider.toggleFavorite` handles that null.
  ///
  /// A fixed stub (what the two callers used before) is only correct for a
  /// single add; anything that toggles twice needs this.
  static void _stubFavouriteToggle(MockDrinkRepository repository) {
    final wanted = <String>{};
    when(repository.toggleFavorite(any, any)).thenAnswer((invocation) async {
      final festivalId = invocation.positionalArguments[0] as String;
      final drinkId = invocation.positionalArguments[1] as String;
      final key = '$festivalId/$drinkId';
      if (!wanted.add(key)) {
        wanted.remove(key);
        return null;
      }
      final now = clock.now();
      return UserDrinkState(wantToTry: true, createdAt: now, updatedAt: now);
    });
  }

  /// Mounts the app at [location] (defaulting to the drinks list for
  /// [festival]) and settles.
  ///
  /// Always builds a fresh router via [buildAppRouter] rather than reusing the
  /// global `appRouter`, which retains its navigation stack between tests.
  ///
  /// Note: [location] is navigated to after the first frame, so this is a warm
  /// start. A true cold start — the route resolved before the first frame,
  /// which is what a deep link does — needs `buildAppRouter` to accept an
  /// initial location; that is a `lib/` change, deliberately not made here.
  Future<void> pump(WidgetTester tester, {String? location}) async {
    final router = buildAppRouter();
    _router = router;
    await tester.pumpWidget(
      ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(location ?? '/${festival.id}');
    await tester.pumpAndSettle();
  }

  void dispose() => provider.dispose();
}
