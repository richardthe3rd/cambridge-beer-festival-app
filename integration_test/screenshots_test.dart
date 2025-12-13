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
      print('Taking screenshot 01-drinks-list');
      await binding.takeScreenshot('01-drinks-list');
      
      // 02 - Favorites - Navigate using bottom navigation
      print('Navigating to Favorites');
      final favoritesNavItem = find.byIcon(Icons.favorite);
      expect(favoritesNavItem, findsOneWidget, reason: 'Favorites nav item should exist');
      await tester.tap(favoritesNavItem);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      print('Taking screenshot 02-favorites');
      await binding.takeScreenshot('02-favorites');
      
      // Navigate back to home
      print('Navigating back to home');
      final homeNavItem = find.byIcon(Icons.home);
      expect(homeNavItem, findsOneWidget, reason: 'Home nav item should exist');
      await tester.tap(homeNavItem);
      await tester.pumpAndSettle();
      
      // 03 - Drink Detail - Tap on first drink card
      print('Navigating to Drink Detail');
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final drinkCards = find.byType(Card);
      expect(drinkCards, findsWidgets, reason: 'Drink cards should exist');
      await tester.tap(drinkCards.first);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      
      print('Taking screenshot 03-drink-detail');
      await binding.takeScreenshot('03-drink-detail');
      
      // Navigate back
      print('Navigating back from drink detail');
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget, reason: 'Back button should exist');
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      
      // 04 - About Screen - Use drawer/menu navigation
      print('Navigating to About');
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final menuButton = find.byIcon(Icons.menu);
      expect(menuButton, findsOneWidget, reason: 'Menu button should exist');
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      
      final aboutButton = find.text('About');
      expect(aboutButton, findsOneWidget, reason: 'About button should exist in menu');
      await tester.tap(aboutButton);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      print('Taking screenshot 04-about');
      await binding.takeScreenshot('04-about');
      
      // Navigate back
      print('Navigating back from about');
      final backButton2 = find.byTooltip('Back');
      expect(backButton2, findsOneWidget, reason: 'Back button should exist');
      await tester.tap(backButton2);
      await tester.pumpAndSettle();
      
      // 05 - Festival Info Screen - Use drawer/menu navigation
      print('Navigating to Festival Info');
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      final menuButton2 = find.byIcon(Icons.menu);
      expect(menuButton2, findsOneWidget, reason: 'Menu button should exist');
      await tester.tap(menuButton2);
      await tester.pumpAndSettle();
      
      final festivalInfoButton = find.text('Festival Info');
      expect(festivalInfoButton, findsOneWidget, reason: 'Festival Info button should exist in menu');
      await tester.tap(festivalInfoButton);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      
      print('Taking screenshot 05-festival-info');
      await binding.takeScreenshot('05-festival-info');
      
      print('All screenshots completed successfully');
    });
  });
}
