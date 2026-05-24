import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinksScreen refresh status', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final testDrinks = [
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Alpha IPA',
          abv: 5.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [testFestival],
          defaultFestivalId: 'cbf2025',
          baseUrl: 'https://example.com',
          version: '1.0.0',
        ),
      );
      when(mockFestivalRepository.getSelectedFestivalId())
          .thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => testDrinks);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() => provider.dispose());

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: DrinksScreen(festivalId: 'cbf2025'),
        ),
      );
    }

    testWidgets('shows a dismissible notice when a refresh fails with cache',
        (tester) async {
      // bySemanticsLabel requires an active semantics tree; dispose explicitly
      // before the test ends so Flutter's end-of-test verifier is happy.
      final semantics = tester.ensureSemantics();
      try {
        // A refresh fails while cached drinks remain on screen.
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(TimeoutException('offline'));
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(provider.refreshNotice, isNotNull);
        expect(find.textContaining('saved data'), findsOneWidget);

        // The drinks list is still shown, not a full-screen error.
        expect(find.text('Alpha IPA'), findsOneWidget);
        expect(find.text('Error loading drinks'), findsNothing);

        // Tapping dismiss removes the notice.
        await tester.tap(find.bySemanticsLabel('Dismiss saved data notice'));
        await tester.pumpAndSettle();

        expect(provider.refreshNotice, isNull);
        expect(find.textContaining('saved data'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('shows a progress bar while refreshing with data on screen',
        (tester) async {
      // Hold the network refresh open so isRefreshing stays true.
      final pending = Completer<List<Drink>>();
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) => pending.future);

      final future = provider.loadDrinks();

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(provider.isRefreshing, isTrue);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      pending.complete(testDrinks);
      await future;
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
