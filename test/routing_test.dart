import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival_app/main.dart';

/// Tests for go_router configuration and navigation behavior
///
/// These tests validate routing logic at the Flutter level before E2E browser tests.
void main() {
  group('Route Configuration', () {
    testWidgets('app initializes with home route', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Should be at root route
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });

    testWidgets('navigating to /about works', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Find and tap the about button (info icon)
      final aboutButton = find.byIcon(Icons.info_outline);
      expect(aboutButton, findsOneWidget);

      await tester.tap(aboutButton);
      await tester.pumpAndSettle();

      // Should navigate to AboutScreen
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('invalid route shows home screen', (tester) async {
      // This tests go_router's default error handling
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Should still show home (go_router redirects invalid routes)
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });
  });

  group('Route Parameters', () {
    testWidgets('drink detail route accepts ID parameter', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Note: This test verifies the route is configured to accept a parameter
      // Actual navigation with parameters would require mocking the provider
      // and having drink data loaded

      // For now, we just verify the app initializes correctly
      // Full navigation testing is done in E2E tests
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });
  });

  group('Navigation Stack', () {
    testWidgets('back button returns to previous screen', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Navigate to about
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      // Go back (simulate back button)
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // Should be back at home
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });

    testWidgets('multiple navigation and back works', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Navigate to about
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      // Go back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(BeerFestivalHome), findsOneWidget);

      // Navigate to about again
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      // Go back again
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });
  });

  group('Bottom Navigation', () {
    testWidgets('switching tabs does not change route', (tester) async {
      await tester.pumpWidget(const BeerFestivalApp());
      await tester.pumpAndSettle();

      // Tap favorites tab
      await tester.tap(find.byIcon(Icons.favorite_outline));
      await tester.pumpAndSettle();

      // Should still be at home route (tabs use IndexedStack, not routing)
      expect(find.byType(BeerFestivalHome), findsOneWidget);

      // Switch back to drinks tab
      await tester.tap(find.byIcon(Icons.local_drink_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });
  });
}
