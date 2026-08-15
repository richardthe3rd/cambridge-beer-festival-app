// Regression/proof test for issue #523: FestivalInfoScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one this screen never renders, like themeMode —
// rebuilt the whole screen.
//
// This screen is narrowed with a Selector<BeerProvider, Festival> gated by
// `shouldRebuild: (prev, next) => !identical(prev, next)` rather than the
// id-select pattern used by BreweryScreen/DrinksScreen, because this screen's
// entire body is Festival metadata. The most important case here is the
// trap that pattern exists to avoid: FestivalController.setSource
// (festival_controller.dart:85-91) re-points currentFestival at a REFRESHED
// Festival object carrying the SAME id whenever the festivals list reloads.
// Festival.== is id-scoped (festival.dart:151), so an id-select (or a
// Festival-object select, which uses the same ==) would treat that refresh
// as "nothing changed" and this screen would keep showing stale metadata —
// which is exactly what the control test below guards against.
//
// FestivalInfoScreen has no debugBuildCount-style hook, and adding one is
// out of scope for this change. Instead this test proves rebuild activity
// from outside the widget: the Selector's builder always constructs a fresh
// (non-const) PageTitle instance when it re-runs, and Flutter's element
// diffing only swaps in that new instance if the builder actually ran.
// Comparing the PageTitle instance's identity across pumps is therefore an
// exact proxy for "did the Selector's builder execute again".
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

Festival createSampleFestival({
  String id = 'cbf2025',
  String name = 'Cambridge Beer Festival 2025',
  String? location,
  String? description,
}) => Festival(
  id: id,
  name: name,
  dataBaseUrl: 'https://data.cambeerfestival.app/$id',
  location: location,
  description: description,
);

void main() {
  group('FestivalInfoScreen narrowed rebuilds (#523)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    Future<void> pumpScreen(WidgetTester tester, Festival festival) async {
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [festival],
          defaultFestivalId: festival.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      await provider.initialize();

      final router = GoRouter(
        initialLocation: '/${festival.id}/info',
        routes: [
          GoRoute(
            path: '/:festivalId/info',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: FestivalInfoScreen(
                    festivalId: state.pathParameters['festivalId']!,
                  ),
                ),
          ),
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    PageTitle currentPageTitle(WidgetTester tester) =>
        tester.widget<PageTitle>(find.byType(PageTitle));

    testWidgets(
      'a provider change unrelated to the festival leaves the build count '
      'unchanged',
      (tester) async {
        await pumpScreen(tester, createSampleFestival());
        final pageTitleBefore = currentPageTitle(tester);

        // themeMode is never read by FestivalInfoScreen or its Selector.
        await provider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          identical(currentPageTitle(tester), pageTitleBefore),
          isTrue,
          reason:
              'An unrelated provider field change must not rebuild '
              'FestivalInfoScreen — this is the literal acceptance bar for '
              '#523',
        );
      },
    );

    testWidgets(
      'control: a same-id festival metadata refresh still re-renders with '
      'the new metadata visible',
      (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            location: 'Cambridge Guildhall',
            description: 'Original description',
          ),
        );

        expect(find.text('Cambridge Guildhall'), findsOneWidget);
        expect(find.text('Original description'), findsOneWidget);
        final pageTitleBefore = currentPageTitle(tester);

        // Same id, refreshed metadata — drives the refresh through the real
        // provider path (loadFestivals -> FestivalController.setSource) the
        // way a network refresh would, rather than reaching into private
        // state.
        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              createSampleFestival(
                location: 'Corn Exchange',
                description: 'Updated description',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            version: '1.0',
            baseUrl: 'https://data.cambeerfestival.app',
          ),
        );
        await provider.loadFestivals();
        await tester.pump();

        expect(
          identical(currentPageTitle(tester), pageTitleBefore),
          isFalse,
          reason: 'Test setup check: the counter must be provably live',
        );
        expect(find.text('Corn Exchange'), findsOneWidget);
        expect(find.text('Updated description'), findsOneWidget);
        expect(find.text('Cambridge Guildhall'), findsNothing);
        expect(find.text('Original description'), findsNothing);
      },
    );
  });
}
