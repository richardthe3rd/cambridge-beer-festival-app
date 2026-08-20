import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

/// Local factory, shaped like the one in `festival_info_screen_test.dart`,
/// but here always populated so every conditional section on the screen
/// renders — the golden is a meaningful guard rather than a near-empty
/// screen.
Festival createSampleFestival({
  String id = 'cbf2025',
  String name = 'Cambridge Beer Festival 2025',
  String? hashtag = '#cbf2025',
  DateTime? startDate,
  DateTime? endDate,
  String? location = 'Jesus Green, Cambridge',
  String? address = 'Jesus Green, Cambridge CB5 8AB',
  double? latitude = 52.2127,
  double? longitude = 0.1234,
  String? description =
      'The best beer festival in the world, run by CAMRA '
      'volunteers on Jesus Green every May.',
  String? websiteUrl = 'https://www.cambridgebeerfestival.com',
  Map<String, String>? hours = const {
    'Monday': '12:00 - 22:00',
    'Tuesday': '11:00 - 22:00',
    'Wednesday': '11:00 - 22:00',
  },
  List<String> availableBeverageTypes = const ['beer', 'cider'],
  bool isActive = true,
  String? charityPartnerName = 'Water Aid',
  String? charityDonationUrl = 'https://wateraid.org/donate',
}) => Festival(
  id: id,
  name: name,
  dataBaseUrl: 'https://data.cambeerfestival.app/$id',
  hashtag: hashtag,
  startDate: startDate ?? DateTime(2025, 5, 19),
  endDate: endDate ?? DateTime(2025, 5, 24),
  location: location,
  address: address,
  latitude: latitude,
  longitude: longitude,
  description: description,
  websiteUrl: websiteUrl,
  hours: hours,
  availableBeverageTypes: availableBeverageTypes,
  isActive: isActive,
  charityPartnerName: charityPartnerName,
  charityDonationUrl: charityDonationUrl,
);

void main() {
  group('FestivalInfoScreen Screenshot Tests', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() async {
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

    Widget buildApp(Brightness brightness) {
      final festival = createSampleFestival();

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

      return MaterialApp.router(
        // Use the real app theme so these goldens cover `appBarTheme` and
        // the text theme, not just the colour scheme (#520).
        theme: buildAppTheme(brightness),
        routerConfig: router,
      );
    }

    Future<void> pumpFestivalInfoScreen(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      final festival = createSampleFestival();
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [festival],
          defaultFestivalId: festival.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      await provider.initialize();

      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(brightness));
      await tester.pumpAndSettle();
    }

    testWidgets('FestivalInfoScreen - light theme', (tester) async {
      await pumpFestivalInfoScreen(tester, Brightness.light);

      await expectLater(
        find.byType(FestivalInfoScreen),
        matchesGoldenFile('goldens/festival_info_screen_light.png'),
      );
    });

    testWidgets('FestivalInfoScreen - dark theme', (tester) async {
      await pumpFestivalInfoScreen(tester, Brightness.dark);

      await expectLater(
        find.byType(FestivalInfoScreen),
        matchesGoldenFile('goldens/festival_info_screen_dark.png'),
      );
    });
  });
}
