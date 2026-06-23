import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

Festival createSampleFestival({
  String id = 'cbf2025',
  String name = 'Cambridge Beer Festival 2025',
  String? hashtag,
  DateTime? startDate,
  DateTime? endDate,
  String? location,
  String? address,
  double? latitude,
  double? longitude,
  String? description,
  String? websiteUrl,
  Map<String, String>? hours,
  List<String> availableBeverageTypes = const ['beer'],
  bool isActive = false,
  String? charityPartnerName,
  String? charityDonationUrl,
}) => Festival(
  id: id,
  name: name,
  dataBaseUrl: 'https://data.cambeerfestival.app/cbf2025',
  hashtag: hashtag,
  startDate: startDate,
  endDate: endDate,
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
  group('FestivalInfoScreen', () {
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

    group('header content', () {
      testWidgets('displays festival name', (tester) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('Cambridge Beer Festival 2025'), findsOneWidget);
      });

      testWidgets('displays formatted dates when set', (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            startDate: DateTime(2025, 5, 19),
            endDate: DateTime(2025, 5, 24),
          ),
        );
        expect(find.text('May 19-24, 2025'), findsOneWidget);
      });

      testWidgets('does not show date row when no dates set', (tester) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.byIcon(Icons.calendar_today), findsNothing);
      });

      testWidgets('displays hashtag when set', (tester) async {
        await pumpScreen(tester, createSampleFestival(hashtag: '#cbf2025'));
        expect(find.text('#cbf2025'), findsOneWidget);
      });

      testWidgets('shows ACTIVE badge when festival is active', (tester) async {
        await pumpScreen(tester, createSampleFestival(isActive: true));
        expect(find.text('ACTIVE'), findsOneWidget);
      });

      testWidgets('does not show ACTIVE badge when festival is not active', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('ACTIVE'), findsNothing);
      });
    });

    group('overview section', () {
      testWidgets('shows beverage type chips', (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(availableBeverageTypes: ['beer', 'cider']),
        );
        expect(find.text('Overview'), findsOneWidget);
        expect(find.byType(Chip), findsNWidgets(2));
      });
    });

    group('location section', () {
      testWidgets('shows location section when location is set', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          createSampleFestival(location: 'Jesus Green, Cambridge'),
        );
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Jesus Green, Cambridge'), findsOneWidget);
      });

      testWidgets(
        'shows location section with fallback title when only address is set',
        (tester) async {
          await pumpScreen(
            tester,
            createSampleFestival(address: 'Jesus Green, Cambridge CB5 8AB'),
          );
          expect(find.text('Location'), findsOneWidget);
          expect(find.text('Jesus Green, Cambridge CB5 8AB'), findsOneWidget);
        },
      );

      testWidgets('shows address when set', (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            location: 'Jesus Green',
            address: 'Jesus Green, Cambridge CB5 8AB',
          ),
        );
        expect(find.text('Jesus Green, Cambridge CB5 8AB'), findsOneWidget);
      });

      testWidgets('does not show location section when neither location nor '
          'address is set', (tester) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('Location'), findsNothing);
      });

      testWidgets('shows map button with semantics when coordinates are set', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            location: 'Jesus Green, Cambridge',
            latitude: 52.2127,
            longitude: 0.1234,
          ),
        );
        expect(find.byIcon(Icons.map), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Open location in maps',
          ),
          findsOneWidget,
        );
      });

      testWidgets('does not show map button when coordinates are not set', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          createSampleFestival(location: 'Jesus Green, Cambridge'),
        );
        expect(find.byIcon(Icons.map), findsNothing);
      });
    });

    group('hours section', () {
      testWidgets('shows hours when set', (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            hours: {'Monday': '12:00 - 22:00', 'Tuesday': '11:00 - 22:00'},
          ),
        );
        expect(find.text('Festival Hours'), findsOneWidget);
        expect(find.text('Monday'), findsOneWidget);
        expect(find.text('12:00 - 22:00'), findsOneWidget);
      });

      testWidgets('does not show hours section when hours is null', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('Festival Hours'), findsNothing);
      });

      testWidgets('does not show hours section when hours is empty map', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival(hours: {}));
        expect(find.text('Festival Hours'), findsNothing);
      });
    });

    group('description section', () {
      testWidgets('shows description when set', (tester) async {
        await pumpScreen(
          tester,
          createSampleFestival(
            description: 'The best beer festival in the world.',
          ),
        );
        expect(find.text('About'), findsOneWidget);
        expect(
          find.text('The best beer festival in the world.'),
          findsOneWidget,
        );
      });

      testWidgets('does not show description section when not set', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('About'), findsNothing);
      });
    });

    group('action buttons', () {
      testWidgets('always shows GitHub button with semantics', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await pumpScreen(tester, createSampleFestival());
          expect(find.text('View App on GitHub'), findsOneWidget);
          expect(
            find.bySemanticsLabel('View app source code on GitHub'),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('shows website button with semantics when url is set', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          await pumpScreen(
            tester,
            createSampleFestival(
              websiteUrl: 'https://www.cambridgebeerfestival.com',
            ),
          );
          expect(find.text('Visit Festival Website'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Visit festival website'),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('does not show website button when url is not set', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('Visit Festival Website'), findsNothing);
      });

      testWidgets(
        'shows charity donation button with semantics when charity is set',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await pumpScreen(
              tester,
              createSampleFestival(
                charityPartnerName: 'Water Aid',
                charityDonationUrl: 'https://wateraid.org/donate',
              ),
            );
            expect(find.text('Donate to Water Aid'), findsOneWidget);
            expect(find.bySemanticsLabel('Donate to Water Aid'), findsWidgets);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('does not show charity button when charity fields not set', (
        tester,
      ) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.byIcon(Icons.favorite), findsNothing);
      });

      testWidgets(
        'does not show charity button when only name is set (url missing)',
        (tester) async {
          await pumpScreen(
            tester,
            createSampleFestival(charityPartnerName: 'Water Aid'),
          );
          expect(find.byIcon(Icons.favorite), findsNothing);
        },
      );
    });

    group('app bar', () {
      testWidgets('shows Festival Info title', (tester) async {
        await pumpScreen(tester, createSampleFestival());
        expect(find.text('Festival Info'), findsOneWidget);
      });
    });
  });
}
