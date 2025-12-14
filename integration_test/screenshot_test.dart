import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cambridge_beer_festival/main.dart' as app;
import 'package:cambridge_beer_festival/providers/beer_provider.dart';

/// **Flutter Web Screenshot Integration Test**
///
/// This test captures screenshots of the app for visual PR reviews.
///
/// **SPLIT TEST APPROACH:**
/// Each screenshot is captured in a separate test to work around Flutter web bugs:
/// - Issue #131394: Only first test in group displays in browser with screenshots
/// - Issue #129041: flutter drive can report "All tests passed" when tests fail
/// - Issue #153588: Tests can stop executing partway through with incomplete Futures
///
/// **TRADEOFFS:**
/// - SLOWER: Each test initializes app independently (more overhead)
/// - MORE RELIABLE: If one screenshot fails, others still capture
/// - EASIER TO DEBUG: Clear which specific screenshot has issues
/// - WORKS AROUND BUGS: Avoids "test stops partway through" issue
///
/// Sources:
/// - https://github.com/flutter/flutter/issues/131394
/// - https://github.com/flutter/flutter/issues/129041
/// - https://github.com/flutter/flutter/issues/153588

// **TEST CONFIGURATION CONSTANTS**
const Timeout kScreenshotTestTimeout = Timeout(Duration(minutes: 2));
const Duration kPumpTimeout = Duration(seconds: 10);
const Duration kRenderDelay = Duration(seconds: 2);
const int kApiWaitSeconds = 20;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Capture Tests', () {

    // ============================================================
    // TEST 1: Drinks List (Home Screen)
    // ============================================================
    testWidgets('Screenshot 1: Drinks List', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization
      await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Wait for API data
      await _waitForContent(
        tester,
        description: 'drinks list data',
        finder: find.byType(RefreshIndicator),
        maxWaitSeconds: kApiWaitSeconds,
      );

      await Future.delayed(kRenderDelay);
      await binding.takeScreenshot('01-drinks-list');
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 2: Favorites Screen
    // ============================================================
    testWidgets('Screenshot 2: Favorites', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization
      await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Navigate to favorites tab
      final favoritesTab = find.byKey(const Key('favorites_tab'));
      if (favoritesTab.evaluate().isNotEmpty) {
        await tester.tap(favoritesTab);
        await tester.pumpAndSettle(kPumpTimeout);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await binding.takeScreenshot('02-favorites');
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 3: About Screen
    // ============================================================
    testWidgets('Screenshot 3: About', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization
      await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Tap about button
      final aboutButton = find.byKey(const Key('about_button'));
      if (aboutButton.evaluate().isNotEmpty) {
        await tester.tap(aboutButton);
        await tester.pumpAndSettle(kPumpTimeout);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await binding.takeScreenshot('03-about');
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 4: Drink Detail Screen
    // ============================================================
    testWidgets('Screenshot 4: Drink Detail', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization and API data
      final navFound = await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      if (!navFound) {
        // Skip if app didn't initialize
        return;
      }

      await _waitForContent(
        tester,
        description: 'drinks list data',
        finder: find.byType(RefreshIndicator),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Get first drink ID from provider
      // Use NavigationBar which we know exists
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isEmpty) {
        return; // Skip if NavigationBar not found
      }

      final provider = Provider.of<BeerProvider>(
        tester.element(navBar),
        listen: false,
      );

      if (provider.allDrinks.isNotEmpty) {
        final drinkId = provider.allDrinks.first.id;

        // Navigate to drink detail
        tester.element(navBar).go('/drink/$drinkId');
        await tester.pumpAndSettle(kPumpTimeout);
        await Future.delayed(kRenderDelay);

        await binding.takeScreenshot('04-drink-detail');
      }
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 5: Brewery Detail Screen
    // ============================================================
    testWidgets('Screenshot 5: Brewery Detail', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization and API data
      final navFound = await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      if (!navFound) {
        // Skip if app didn't initialize
        return;
      }

      await _waitForContent(
        tester,
        description: 'drinks list data',
        finder: find.byType(RefreshIndicator),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Get first brewery ID from provider
      // Use NavigationBar which we know exists
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isEmpty) {
        return; // Skip if NavigationBar not found
      }

      final provider = Provider.of<BeerProvider>(
        tester.element(navBar),
        listen: false,
      );

      if (provider.allDrinks.isNotEmpty) {
        final breweryId = provider.allDrinks.first.producer.id;

        // Navigate to brewery detail
        tester.element(navBar).go('/brewery/$breweryId');
        await tester.pumpAndSettle(kPumpTimeout);
        await Future.delayed(kRenderDelay);

        await binding.takeScreenshot('05-brewery-detail');
      }
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 6: Style Detail Screen
    // ============================================================
    testWidgets('Screenshot 6: Style Detail', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization and API data
      final navFound = await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      if (!navFound) {
        // Skip if app didn't initialize
        return;
      }

      await _waitForContent(
        tester,
        description: 'drinks list data',
        finder: find.byType(RefreshIndicator),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Get first drink with style from provider
      // Use NavigationBar which we know exists
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isEmpty) {
        return; // Skip if NavigationBar not found
      }

      final provider = Provider.of<BeerProvider>(
        tester.element(navBar),
        listen: false,
      );

      if (provider.allDrinks.isNotEmpty) {
        final style = provider.allDrinks.first.style;

        if (style != null && style.isNotEmpty) {
          final encodedStyle = Uri.encodeComponent(style);

          // Navigate to style detail
          tester.element(navBar).go('/style/$encodedStyle');
          await tester.pumpAndSettle(kPumpTimeout);
          await Future.delayed(kRenderDelay);

          await binding.takeScreenshot('06-style-detail');
        }
      }
    }, timeout: kScreenshotTestTimeout);

    // ============================================================
    // TEST 7: Festival Info Screen
    // ============================================================
    testWidgets('Screenshot 7: Festival Info', (tester) async {
      await _configureViewport(binding, tester);
      await tester.pumpWidget(const app.BeerFestivalApp());

      // Wait for app initialization
      await _waitForContent(
        tester,
        description: 'app initialization',
        finder: find.byType(NavigationBar),
        maxWaitSeconds: kApiWaitSeconds,
      );

      // Navigate to festival info
      tester.element(find.byType(NavigationBar)).go('/festival-info');
      await tester.pumpAndSettle(kPumpTimeout);
      await Future.delayed(kRenderDelay);

      await binding.takeScreenshot('07-festival-info');
    }, timeout: kScreenshotTestTimeout);
  });
}

/// Configure mobile viewport (iPhone 14 Pro dimensions)
Future<void> _configureViewport(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  const mobileWidth = 390.0;
  const mobileHeight = 844.0;
  await binding.setSurfaceSize(const Size(mobileWidth, mobileHeight));
  tester.view.physicalSize = const Size(mobileWidth, mobileHeight);
  tester.view.devicePixelRatio = 2.0;
}

/// Wait for widget to appear with timeout
Future<bool> _waitForContent(
  WidgetTester tester, {
  required Finder finder,
  required String description,
  int maxWaitSeconds = 10,
}) async {
  final startTime = DateTime.now();

  while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
    await tester.pump();

    if (finder.evaluate().isNotEmpty) {
      return true;
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  return false;
}
