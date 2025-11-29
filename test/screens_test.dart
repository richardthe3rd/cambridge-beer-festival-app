import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

    setUp(() {
      mockUrlLauncher = MockUrlLauncherPlatform();
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
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: FestivalInfoScreen(festival: testFestival),
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

      // Verify error SnackBar is shown
      expect(find.text('Error opening website'), findsOneWidget);
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

      // Verify error SnackBar is shown
      expect(find.text('Error opening maps'), findsOneWidget);
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
}
