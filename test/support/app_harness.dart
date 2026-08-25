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
/// The carousel is capped at ten entries taken in list order, so only the
/// first eleven generated drinks (indices 0-10, whatever [idPrefix] names
/// them) ever appear in one. Any index above that is guaranteed to be
/// displayed by no screen in the stack, which is what
/// navigation_stack_rebuild_test.dart's "unrelated drink" relies on.
List<Drink> createSampleDrinks(
  int count, {
  String festivalId = testFestivalId,
  String idPrefix = 'drink',
  String namePrefix = 'Test Drink',
  String breweryName = 'Test Brewery',
  String style = 'IPA',
}) {
  final producer = Producer.fromJson({
    'id': 'brewery-1',
    'name': breweryName,
    'location': 'Cambridge',
    'products': <Map<String, dynamic>>[],
  });

  return List.generate(count, (i) {
    final product = Product.fromJson({
      'id': '$idPrefix-$i',
      'name': '$namePrefix $i',
      'category': 'beer',
      'style': style,
      'dispense': 'cask',
      'abv': '5.0',
    });
    return Drink(product: product, producer: producer, festivalId: festivalId);
  });
}

/// One drink with a distinct identity, for journeys that need to tell drinks
/// apart on screen (search hits vs misses, one style vs another).
///
/// [createSampleDrinks] deliberately makes every drink alike; this is its
/// counterpart for the cases where sameness is the problem.
Drink createDrink({
  required String id,
  required String name,
  String style = 'IPA',
  String category = 'beer',
  String abv = '5.0',
  String dispense = 'cask',
  String breweryName = 'Test Brewery',
  String breweryId = 'brewery-1',
  String festivalId = testFestivalId,
}) {
  final producer = Producer.fromJson({
    'id': breweryId,
    'name': breweryName,
    'location': 'Cambridge',
    'products': <Map<String, dynamic>>[],
  });
  final product = Product.fromJson({
    'id': id,
    'name': name,
    'category': category,
    'style': style,
    'dispense': dispense,
    'abv': abv,
  });
  return Drink(product: product, producer: producer, festivalId: festivalId);
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
    required this.catalogue,
    required this.festivals,
    required this.personalStore,
  });

  final BeerProvider provider;
  final MockDrinkRepository drinkRepository;
  final MockFestivalRepository festivalRepository;
  final MockAnalyticsService analyticsService;

  /// The opening festival's drinks — shorthand for `catalogue[festival.id]`.
  final List<Drink> drinks;

  /// Every festival's drinks, keyed by festival id.
  final Map<String, List<Drink>> catalogue;

  final List<Festival> festivals;

  /// The in-memory personal-state store behind the repository stubs.
  ///
  /// Exposed so a test can read back what a journey wrote, or assert on it
  /// independently of the screen rendering it. It has no seeding API yet: a
  /// journey that must start from existing personal state should add one
  /// rather than reaching into its internals.
  final FakePersonalStore personalStore;

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
    Map<String, List<Drink>>? drinksByFestival,
    List<Festival>? festivals,
    String? selectedFestivalId,
    Object? drinksError,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final drinkRepository = MockDrinkRepository();
    final festivalRepository = MockFestivalRepository();
    final analyticsService = MockAnalyticsService();

    final resolvedFestivals = festivals ?? const [defaultTestFestival];
    // A festival with no catalogue of its own serves an empty list, the same
    // as a festival whose feed has no drinks yet — never another festival's.
    final catalogue =
        drinksByFestival ??
        <String, List<Drink>>{
          resolvedFestivals.first.id:
              drinks ??
              createSampleDrinks(
                drinkCount,
                festivalId: resolvedFestivals.first.id,
              ),
        };
    final resolvedDrinks =
        catalogue[resolvedFestivals.first.id] ?? const <Drink>[];

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
    // Stubbed explicitly rather than left to the nice-mock default, so the
    // "no cached data at all" case in an error journey is unambiguous.
    when(drinkRepository.getCachedDrinks(any)).thenAnswer((_) async => null);
    _stubDrinks(drinkRepository, catalogue, error: drinksError);
    final personalStore = FakePersonalStore();
    _stubPersonalState(drinkRepository, personalStore);

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
      catalogue: Map<String, List<Drink>>.of(catalogue),
      festivals: resolvedFestivals,
      personalStore: personalStore,
    );
  }

  /// Points `getDrinks` at [catalogue], or makes it throw [error] when one is
  /// given — the failing half of an error-recovery journey.
  static void _stubDrinks(
    MockDrinkRepository repository,
    Map<String, List<Drink>> catalogue, {
    Object? error,
  }) {
    when(repository.getDrinks(any)).thenAnswer((invocation) async {
      if (error != null) throw error;
      final festival = invocation.positionalArguments[0] as Festival;
      return catalogue[festival.id] ?? const <Drink>[];
    });
  }

  /// Makes `getDrinks` throw [error] from now on, so an already-loaded journey
  /// can have its next refresh fail.
  void failDrinks(Object error) =>
      _stubDrinks(drinkRepository, catalogue, error: error);

  /// Makes `getDrinks` succeed again, optionally serving [drinks] to
  /// [festival] instead of what it served before — so a recovery can be shown
  /// to deliver genuinely fresh data, not just to stop erroring.
  void recoverDrinks({List<Drink>? drinks, String? festivalId}) {
    if (drinks != null) {
      catalogue[festivalId ?? festival.id] = drinks;
    }
    _stubDrinks(drinkRepository, catalogue);
  }

  /// Wires the personal-state half of [MockDrinkRepository] to [store], so a
  /// journey that writes want-to-try can read it back the way the app does.
  ///
  /// Both methods must come from the same store: `BeerProvider.toggleFavorite`
  /// writes through `toggleFavorite`, but `myFestivalEntries` re-reads through
  /// `getPersonalEntries` rather than caching the write. Stubbing only the
  /// writer leaves My Festival permanently empty.
  static void _stubPersonalState(
    MockDrinkRepository repository,
    FakePersonalStore store,
  ) {
    when(repository.toggleFavorite(any, any)).thenAnswer(
      (invocation) async => store.toggleWantToTry(
        invocation.positionalArguments[0] as String,
        invocation.positionalArguments[1] as String,
      ),
    );
    when(repository.getPersonalEntries(any)).thenAnswer(
      (invocation) =>
          store.entriesFor(invocation.positionalArguments[0] as String),
    );
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

/// In-memory want-to-try store, shared by the repository stubs.
///
/// Not a general stand-in for `UserDataStore` — it models only the
/// want-to-try flag and the personal entries these journeys read back.
/// Ratings, tastings, notes and photos are absent; a journey needing any
/// of those has to add them.
///
/// It does mirror the one real-store behaviour these journeys depend on:
/// a record carrying no user signal is pruned, so unfavouriting an otherwise
/// untouched drink leaves no key behind and reads back as null — which is what
/// `ApiDrinkRepository.toggleFavorite` returns and `BeerProvider` handles.
class FakePersonalStore {
  final Map<String, Map<String, UserDrinkState>> _byFestival = {};

  /// Every non-pruned record for [festivalId], as `getPersonalEntries` returns.
  Map<String, UserDrinkState> entriesFor(String festivalId) => Map.unmodifiable(
    _byFestival[festivalId] ?? const <String, UserDrinkState>{},
  );

  /// Flips want-to-try for one drink, returning the resulting record, or null
  /// when the flip pruned it.
  UserDrinkState? toggleWantToTry(String festivalId, String drinkId) {
    final entries = _byFestival.putIfAbsent(
      festivalId,
      () => <String, UserDrinkState>{},
    );
    final now = clock.now();
    final existing = entries[drinkId] ?? UserDrinkState.initial(now: now);
    final updated = existing.copyWith(
      wantToTry: !existing.wantToTry,
      updatedAt: now,
    );
    if (updated.isEmpty) {
      entries.remove(drinkId);
      return null;
    }
    entries[drinkId] = updated;
    return updated;
  }
}
