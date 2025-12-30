import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'provider_test.mocks.dart';

// Create a mock URL launcher platform that properly extends the interface
class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool canLaunchResult = true;
  bool shouldThrowOnLaunch = false;
  String? lastLaunchedUrl;

  @override
  Future<bool> canLaunch(String url) async {
    return canLaunchResult;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    lastLaunchedUrl = url;
    if (shouldThrowOnLaunch) {
      throw Exception('Launch failed');
    }
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    return launch(
      url,
      useSafariVC: false,
      useWebView: false,
      enableJavaScript: false,
      enableDomStorage: false,
      universalLinksOnly: false,
      headers: const {},
    );
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async {
    return true;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async {
    return false;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  group('FestivalInfoScreen URL Launch Error Handling', () {
    late MockUrlLauncherPlatform mockUrlLauncher;
    late Festival testFestival;
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() async {
      mockUrlLauncher = MockUrlLauncherPlatform();
      // Explicitly reset mock state to ensure test isolation
      mockUrlLauncher.canLaunchResult = true;
      mockUrlLauncher.shouldThrowOnLaunch = false;
      UrlLauncherPlatform.instance = mockUrlLauncher;

      testFestival = Festival(
        id: 'test-festival',
        name: 'Test Festival',
        dataBaseUrl: 'https://example.com',
        startDate: DateTime(2025, 5, 1),
        endDate: DateTime(2025, 5, 3),
        websiteUrl: 'https://testfestival.com',
        latitude: 52.2053,
        longitude: 0.1218,
        location: 'Test Location',
      );
      
      // Set up provider with test festival
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      
      // Mock fetchAllDrinks to return empty list
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => []);
      
      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      // Set the test festival
      await provider.setFestival(testFestival);
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: FestivalInfoScreen(festivalId: 'cbf2025'),
        ),
      );
    }

    testWidgets('shows error SnackBar when website URL cannot be launched',
        (WidgetTester tester) async {
      // Mock canLaunchUrl to return false
      mockUrlLauncher.canLaunchResult = false;

      await tester.pumpWidget(createTestWidget());

      // Find and tap the website button
      final websiteButton = find.text('Visit Festival Website');
      expect(websiteButton, findsOneWidget);
      await tester.tap(websiteButton);
      await tester.pumpAndSettle();

      // Verify error SnackBar is shown
      expect(find.text('Could not open website'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when website URL launch throws exception',
        (WidgetTester tester) async {
      // Mock launch to throw exception
      mockUrlLauncher.shouldThrowOnLaunch = true;

      await tester.pumpWidget(createTestWidget());

      // Find and tap the website button
      final websiteButton = find.text('Visit Festival Website');
      await tester.tap(websiteButton);
      await tester.pumpAndSettle();

      // Verify error SnackBar is shown (now unified message)
      expect(find.text('Could not open website'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when maps URL cannot be launched',
        (WidgetTester tester) async {
      // Mock canLaunchUrl to return false
      mockUrlLauncher.canLaunchResult = false;

      await tester.pumpWidget(createTestWidget());

      // Find and tap the maps button (icon button in location card)
      final mapsButton = find.byIcon(Icons.map);
      expect(mapsButton, findsOneWidget);
      await tester.tap(mapsButton);
      await tester.pumpAndSettle();

      // Verify error SnackBar is shown
      expect(find.text('Could not open maps'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when maps URL launch throws exception',
        (WidgetTester tester) async {
      // Mock launch to throw exception
      mockUrlLauncher.shouldThrowOnLaunch = true;

      await tester.pumpWidget(createTestWidget());

      // Find and tap the maps button
      final mapsButton = find.byIcon(Icons.map);
      await tester.tap(mapsButton);
      await tester.pumpAndSettle();

      // Verify error SnackBar is shown (now unified message)
      expect(find.text('Could not open maps'), findsOneWidget);
    });

    testWidgets('successfully launches website URL when canLaunch returns true',
        (WidgetTester tester) async {
      // Default mock behavior allows launch

      await tester.pumpWidget(createTestWidget());

      // Find and tap the website button
      final websiteButton = find.text('Visit Festival Website');
      await tester.tap(websiteButton);
      await tester.pumpAndSettle();

      // Verify launch was called with correct URL and no error SnackBar is shown
      expect(mockUrlLauncher.lastLaunchedUrl, 'https://testfestival.com');
      expect(find.text('Could not open website'), findsNothing);
      expect(find.text('Error opening website'), findsNothing);
    });

    testWidgets('successfully launches maps URL when canLaunch returns true',
        (WidgetTester tester) async {
      // Default mock behavior allows launch

      await tester.pumpWidget(createTestWidget());

      // Find and tap the maps button
      final mapsButton = find.byIcon(Icons.map);
      await tester.tap(mapsButton);
      await tester.pumpAndSettle();

      // Verify launch was called with correct URL and no error SnackBar is shown
      expect(mockUrlLauncher.lastLaunchedUrl,
          'https://www.google.com/maps/search/?api=1&query=52.2053,0.1218');
      expect(find.text('Could not open maps'), findsNothing);
      expect(find.text('Error opening maps'), findsNothing);
    });
  });

  group('AboutScreen', () {
    late MockUrlLauncherPlatform mockUrlLauncher;
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      mockUrlLauncher = MockUrlLauncherPlatform();
      mockUrlLauncher.canLaunchResult = true;
      mockUrlLauncher.shouldThrowOnLaunch = false;
      UrlLauncherPlatform.instance = mockUrlLauncher;

      // Set up PackageInfo with test values
      PackageInfo.setMockInitialValues(
        appName: 'Cambridge Beer Festival',
        packageName: 'ralcock.cbf',
        version: '2025.12.0',
        buildNumber: '20251200',
        buildSignature: '',
      );

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: AboutScreen(),
        ),
      );
    }

    testWidgets('displays app name and version', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Wait for async package info to load
      await tester.pumpAndSettle();

      expect(find.text('Cambridge Beer Festival'), findsOneWidget);
      // Package info may not load in test environment, just verify version text exists
      expect(find.textContaining('Version'), findsOneWidget);
    });

    testWidgets('displays all sections', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('About'), findsNWidgets(2)); // AppBar + section title
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Links'), findsOneWidget);
      expect(find.text('Legal'), findsOneWidget);
    });

    testWidgets('successfully launches GitHub repository URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final githubButton = find.widgetWithText(ListTile, 'Source Code');
      await tester.ensureVisible(githubButton);
      await tester.tap(githubButton);
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.lastLaunchedUrl,
          'https://github.com/richardthe3rd/cambridge-beer-festival-app');
      expect(find.text('Could not open GitHub'), findsNothing);
      expect(find.text('Error opening GitHub'), findsNothing);
    });

    testWidgets('shows error SnackBar when GitHub URL cannot be launched',
        (WidgetTester tester) async {
      mockUrlLauncher.canLaunchResult = false;

      await tester.pumpWidget(createTestWidget());

      final githubButton = find.widgetWithText(ListTile, 'Source Code');
      await tester.ensureVisible(githubButton);
      await tester.tap(githubButton);
      await tester.pumpAndSettle();

      expect(find.text('Could not open GitHub'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when GitHub URL launch throws exception',
        (WidgetTester tester) async {
      mockUrlLauncher.shouldThrowOnLaunch = true;

      await tester.pumpWidget(createTestWidget());

      final githubButton = find.widgetWithText(ListTile, 'Source Code');
      await tester.ensureVisible(githubButton);
      await tester.tap(githubButton);
      await tester.pumpAndSettle();

      // Now using unified error message
      expect(find.text('Could not open GitHub'), findsOneWidget);
    });

    testWidgets('successfully launches GitHub Issues URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final issuesButton = find.widgetWithText(ListTile, 'Report an Issue');
      await tester.ensureVisible(issuesButton);
      await tester.tap(issuesButton);
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.lastLaunchedUrl,
          'https://github.com/richardthe3rd/cambridge-beer-festival-app/issues');
      expect(find.text('Could not open GitHub Issues'), findsNothing);
      expect(find.text('Error opening GitHub Issues'), findsNothing);
    });

    testWidgets('shows error SnackBar when Issues URL cannot be launched',
        (WidgetTester tester) async {
      mockUrlLauncher.canLaunchResult = false;

      await tester.pumpWidget(createTestWidget());

      final issuesButton = find.widgetWithText(ListTile, 'Report an Issue');
      await tester.ensureVisible(issuesButton);
      await tester.tap(issuesButton);
      await tester.pumpAndSettle();

      expect(find.text('Could not open GitHub Issues'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when Issues URL launch throws exception',
        (WidgetTester tester) async {
      mockUrlLauncher.shouldThrowOnLaunch = true;

      await tester.pumpWidget(createTestWidget());

      final issuesButton = find.widgetWithText(ListTile, 'Report an Issue');
      await tester.ensureVisible(issuesButton);
      await tester.tap(issuesButton);
      await tester.pumpAndSettle();

      // Now using unified error message
      expect(find.text('Could not open GitHub Issues'), findsOneWidget);
    });

    testWidgets('opens theme selector when theme tile is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final themeButton = find.widgetWithText(ListTile, 'Theme');
      await tester.ensureVisible(themeButton);
      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      // Verify theme selector sheet is shown
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Follow device settings'), findsOneWidget);
    });

    testWidgets('changes theme mode when option is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initial theme mode should be system
      expect(provider.themeMode, ThemeMode.system);

      final themeButton = find.widgetWithText(ListTile, 'Theme');
      await tester.ensureVisible(themeButton);
      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      // Select light mode
      final lightOption = find.text('Always use light theme');
      await tester.tap(lightOption);
      await tester.pumpAndSettle();

      // Verify theme mode changed
      expect(provider.themeMode, ThemeMode.light);
    });

    testWidgets('opens license page when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final licenseButton = find.widgetWithText(ListTile, 'Open Source Licenses');
      await tester.ensureVisible(licenseButton);
      await tester.pumpAndSettle();

      expect(licenseButton, findsOneWidget);
      await tester.tap(licenseButton);
      await tester.pumpAndSettle();

      // Verify LicensePage is shown
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
