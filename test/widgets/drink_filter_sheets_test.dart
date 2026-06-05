import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/drink_filter_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

void main() {
  group('drink filter sheets', () {
    late BeerProvider provider;

    Drink beer(String id, String name, String style) => Drink(
      product: Product(
        id: id,
        name: name,
        abv: 5.0,
        category: 'beer',
        dispense: 'cask',
        style: style,
      ),
      producer: const Producer(
        id: 'b1',
        name: 'Test Brewery',
        location: 'Cambridge',
        products: [],
      ),
      festivalId: 'cbf2025',
    );

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
          beer('d1', 'Zeta IPA', 'IPA'),
          beer('d2', 'Alpha Bitter', 'Bitter'),
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

    Widget host(Widget sheet) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: sheet)),
      );
    }

    testWidgets('CategoryFilterSheet lists categories with counts', (
      tester,
    ) async {
      await tester.pumpWidget(host(CategoryFilterSheet(provider: provider)));
      await tester.pumpAndSettle();

      expect(find.text('Filter by Category'), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.textContaining('Beer'), findsOneWidget);
    });

    testWidgets('SortOptionsSheet lists every sort option label', (
      tester,
    ) async {
      await tester.pumpWidget(host(SortOptionsSheet(provider: provider)));
      await tester.pumpAndSettle();

      expect(find.text('Sort By'), findsOneWidget);
      expect(find.text('Name (A-Z)'), findsOneWidget);
      expect(find.text('ABV (High to Low)'), findsOneWidget);
    });

    testWidgets('StyleFilterSheet shows styles in locale-aware order', (
      tester,
    ) async {
      await tester.pumpWidget(host(const StyleFilterSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Filter by Style'), findsOneWidget);

      // Provider supplies the sorted order; Bitter precedes IPA on screen.
      final bitterY = tester.getTopLeft(find.text('Bitter (1)')).dy;
      final ipaY = tester.getTopLeft(find.text('IPA (1)')).dy;
      expect(bitterY, lessThan(ipaY));
    });

    testWidgets('StyleFilterSheet toggles a style on the provider', (
      tester,
    ) async {
      await tester.pumpWidget(host(const StyleFilterSheet()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('IPA (1)'));
      await tester.pumpAndSettle();

      expect(provider.selectedStyles, contains('IPA'));
    });

    testWidgets('VisibilityFilterSheet renders the standard toggles', (
      tester,
    ) async {
      await tester.pumpWidget(host(const VisibilityFilterSheet()));
      await tester.pumpAndSettle();

      expect(find.text('View Filters'), findsOneWidget);
      expect(find.text('Available only'), findsOneWidget);
      expect(find.text('Not tasted'), findsOneWidget);
      expect(find.text('Vegan only'), findsOneWidget);
    });
  });
}
