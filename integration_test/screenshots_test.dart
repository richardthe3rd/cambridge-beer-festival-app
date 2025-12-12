import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:cambridge_beer_festival/main.dart' as app;

/// Screenshot capture test for CI/PR visual review
///
/// This test captures screenshots of main app screens using golden_screenshot.
/// Screenshots are saved to the configured output directory for PR reviews.
///
/// Usage:
///   flutter test integration_test/screenshots_test.dart \
///     --platform=chrome \
///     --dart-define=GOLDEN_SCREENSHOT_DIR=screenshots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  // Configure screenshot settings - mobile viewport (iPhone 14 Pro size)
  final screenshotConfig = ScreenshotConfig(
    deviceConfig: DeviceConfig.iphone13(TargetPlatform.iOS),
  );

  group('App Screenshots', () {
    testWidgets('01 - Drinks List (Home)', (WidgetTester tester) async {
      await tester.pumpWidget(const app.BeerFestivalApp());
      
      // Wait for initial load and data fetch
      await tester.pumpAndSettle();
      
      // Additional wait for API data to load
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      await tester.takeGoldenScreenshot(
        '01-drinks-list',
        config: screenshotConfig,
      );
    });

    testWidgets('02 - Favorites', (WidgetTester tester) async {
      await tester.pumpWidget(const app.BeerFestivalApp());
      await tester.pumpAndSettle();
      
      // Navigate to favorites - look for bottom navigation
      final favoritesNavItem = find.byIcon(Icons.favorite);
      if (favoritesNavItem.evaluate().isNotEmpty) {
        await tester.tap(favoritesNavItem);
        await tester.pumpAndSettle();
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      await tester.takeGoldenScreenshot(
        '02-favorites',
        config: screenshotConfig,
      );
    });

    testWidgets('03 - About Screen', (WidgetTester tester) async {
      await tester.pumpWidget(const app.BeerFestivalApp());
      await tester.pumpAndSettle();
      
      // Look for app bar menu or about navigation
      final menuButton = find.byIcon(Icons.menu);
      if (menuButton.evaluate().isNotEmpty) {
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        
        final aboutButton = find.text('About');
        if (aboutButton.evaluate().isNotEmpty) {
          await tester.tap(aboutButton);
          await tester.pumpAndSettle();
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      await tester.takeGoldenScreenshot(
        '03-about',
        config: screenshotConfig,
      );
    });

    testWidgets('04 - Drink Detail Screen', (WidgetTester tester) async {
      await tester.pumpWidget(const app.BeerFestivalApp());
      await tester.pumpAndSettle();
      
      // Wait for data to load
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      // Find and tap first drink card
      final drinkCards = find.byType(Card);
      if (drinkCards.evaluate().isNotEmpty) {
        await tester.tap(drinkCards.first);
        await tester.pumpAndSettle();
        
        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        
        await tester.takeGoldenScreenshot(
          '04-drink-detail',
          config: screenshotConfig,
        );
      }
    });

    testWidgets('05 - Festival Info Screen', (WidgetTester tester) async {
      await tester.pumpWidget(const app.BeerFestivalApp());
      await tester.pumpAndSettle();
      
      // Look for menu button to navigate to festival info
      final menuButton = find.byIcon(Icons.menu);
      if (menuButton.evaluate().isNotEmpty) {
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        
        final festivalInfoButton = find.text('Festival Info');
        if (festivalInfoButton.evaluate().isNotEmpty) {
          await tester.tap(festivalInfoButton);
          await tester.pumpAndSettle();
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      await tester.takeGoldenScreenshot(
        '05-festival-info',
        config: screenshotConfig,
      );
    });
  });
}
