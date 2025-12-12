import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cambridge_beer_festival/main.dart' as app;

/// Screenshot capture test for CI/PR visual review
///
/// This test captures screenshots of main app screens using Flutter's
/// integration_test package. Screenshots are saved to the configured output
/// directory for PR reviews.
///
/// Requirements:
///   - ChromeDriver must be running on port 4444
///   - For headless CI: Xvfb must be running with DISPLAY set
///
/// Usage (local with Chrome):
///   1. Start ChromeDriver: chromedriver --port=4444
///   2. Run test:
///      flutter drive \
///        --driver=test_driver/integration_test.dart \
///        --target=integration_test/screenshots_test.dart \
///        -d chrome
///
/// Usage (CI/headless with web-server):
///   export DISPLAY=:99
///   Xvfb :99 -screen 0 1920x1080x24 &
///   chromedriver --port=4444 &
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d web-server
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Screenshots', () {
    testWidgets('Capture all screens', (WidgetTester tester) async {
      // Start the app once
      await tester.pumpWidget(const app.BeerFestivalApp());
      await tester.pumpAndSettle();
      
      // Wait for initial data to load
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      // 01 - Drinks List (Home) - Default screen
      await binding.takeScreenshot('01-drinks-list');
      
      // 02 - Favorites - Navigate using bottom navigation
      final favoritesNavItem = find.byIcon(Icons.favorite);
      if (favoritesNavItem.evaluate().isNotEmpty) {
        await tester.tap(favoritesNavItem);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        
        await binding.takeScreenshot('02-favorites');
        
        // Navigate back to home
        final homeNavItem = find.byIcon(Icons.home);
        if (homeNavItem.evaluate().isNotEmpty) {
          await tester.tap(homeNavItem);
          await tester.pumpAndSettle();
        }
      }
      
      // 03 - Drink Detail - Tap on first drink card
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final drinkCards = find.byType(Card);
      if (drinkCards.evaluate().isNotEmpty) {
        await tester.tap(drinkCards.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        
        await binding.takeScreenshot('03-drink-detail');
        
        // Navigate back
        final backButton = find.byTooltip('Back');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
      
      // 04 - About Screen - Use drawer/menu navigation
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final menuButton = find.byIcon(Icons.menu);
      if (menuButton.evaluate().isNotEmpty) {
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        
        final aboutButton = find.text('About');
        if (aboutButton.evaluate().isNotEmpty) {
          await tester.tap(aboutButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          
          await binding.takeScreenshot('04-about');
          
          // Navigate back
          final backButton = find.byTooltip('Back');
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        }
      }
      
      // 05 - Festival Info Screen - Use drawer/menu navigation
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final menuButton2 = find.byIcon(Icons.menu);
      if (menuButton2.evaluate().isNotEmpty) {
        await tester.tap(menuButton2);
        await tester.pumpAndSettle();
        
        final festivalInfoButton = find.text('Festival Info');
        if (festivalInfoButton.evaluate().isNotEmpty) {
          await tester.tap(festivalInfoButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          
          await binding.takeScreenshot('05-festival-info');
        }
      }
    });
  });
}
