import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/festival_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

void main() {
  group('FestivalStatusBadge', () {
    Widget wrap(
      FestivalStatus status, {
      Brightness brightness = Brightness.light,
    }) {
      // Wrap the badge in an explicit Theme so brightness is deterministic
      // regardless of the test platform's system brightness.
      return MaterialApp(
        home: Theme(
          data: ThemeData(brightness: brightness),
          child: Scaffold(
            body: Center(child: FestivalStatusBadge(status: status)),
          ),
        ),
      );
    }

    const expectedLabels = {
      FestivalStatus.live: 'LIVE',
      FestivalStatus.upcoming: 'SOON',
      FestivalStatus.mostRecent: 'RECENT',
      FestivalStatus.past: 'PAST',
    };

    for (final entry in expectedLabels.entries) {
      testWidgets('renders ${entry.value} label for ${entry.key}', (
        tester,
      ) async {
        await tester.pumpWidget(wrap(entry.key));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('badge colour adapts to light and dark themes', (tester) async {
      Color colorOf(WidgetTester t) {
        final container = t.widget<Container>(
          find.ancestor(
            of: find.text('LIVE'),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      await tester.pumpWidget(wrap(FestivalStatus.live));
      expect(colorOf(tester), const Color(0xFF2E7D32));

      await tester.pumpWidget(
        wrap(FestivalStatus.live, brightness: Brightness.dark),
      );
      expect(colorOf(tester), const Color(0xFF4CAF50));
    });
  });

  group('FestivalHeader', () {
    late BeerProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final mockDrinkRepository = MockDrinkRepository();
      final mockFestivalRepository = MockFestivalRepository();
      final mockAnalyticsService = MockAnalyticsService();

      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: const [testFestival],
          defaultFestivalId: 'cbf2025',
          baseUrl: 'https://example.com',
          version: '1.0.0',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer(
        (_) async => [
          Drink(
            product: const Product(
              id: 'd1',
              name: 'Test IPA',
              abv: 5.0,
              category: 'beer',
              dispense: 'cask',
              style: 'IPA',
            ),
            producer: const Producer(
              id: 'b1',
              name: 'Test Brewery',
              location: 'Cambridge',
              products: [],
            ),
            festivalId: 'cbf2025',
          ),
        ],
      );

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() => provider.dispose());

    testWidgets('exposes one merged semantic label with name, count, and '
        'status, excluding child semantics', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: FestivalHeader(provider: provider)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere(
            (s) => s.properties.label?.startsWith('Current festival:') ?? false,
          );

      expect(semantics.excludeSemantics, isTrue);
      expect(
        semantics.properties.label,
        contains('Cambridge Beer Festival 2025'),
      );
      // Singular form for a single drink (not "1 drinks").
      expect(semantics.properties.label, contains('1 drink,'));
      expect(semantics.properties.label, isNot(contains('1 drinks')));
      // Status is folded into the label so it is not lost when child
      // semantics (the badge text) are excluded.
      expect(
        semantics.properties.label,
        anyOf(
          contains('live now'),
          contains('starting soon'),
          contains('most recent'),
          contains('past'),
        ),
      );
    });
  });
}
