import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/availability_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvailabilityBadge', () {
    Widget buildBadge(
      AvailabilityStatus status, {
      bool compact = true,
      String? customText,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AvailabilityBadge(
            status: status,
            compact: compact,
            customText: customText,
          ),
        ),
      );
    }

    group('compact mode (default)', () {
      testWidgets('shows Available with check icon for plenty status', (
        tester,
      ) async {
        await tester.pumpWidget(buildBadge(AvailabilityStatus.plenty));
        expect(find.text('Available'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsNothing);
      });

      testWidgets('shows Available for low status', (tester) async {
        await tester.pumpWidget(buildBadge(AvailabilityStatus.low));
        expect(find.text('Available'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('shows Sold Out with cancel icon for out status', (
        tester,
      ) async {
        await tester.pumpWidget(buildBadge(AvailabilityStatus.out));
        expect(find.text('Sold Out'), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });

      testWidgets('shows custom text instead of status-based text', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildBadge(AvailabilityStatus.plenty, customText: 'Just Tapped'),
        );
        expect(find.text('Just Tapped'), findsOneWidget);
        expect(find.text('Available'), findsNothing);
      });

      testWidgets('custom text overrides sold-out text', (tester) async {
        await tester.pumpWidget(
          buildBadge(AvailabilityStatus.out, customText: 'Gone'),
        );
        expect(find.text('Gone'), findsOneWidget);
        expect(find.text('Sold Out'), findsNothing);
      });
    });

    group('full-width banner mode', () {
      testWidgets('renders full-width banner with available status', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildBadge(AvailabilityStatus.plenty, compact: false),
        );
        expect(find.text('Available'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('renders full-width banner with sold-out status', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildBadge(AvailabilityStatus.out, compact: false),
        );
        expect(find.text('Sold Out'), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsOneWidget);
      });

      testWidgets('full-width banner uses different icon size than compact', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildBadge(AvailabilityStatus.plenty, compact: false),
        );
        final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(icon.size, 20);
      });

      testWidgets('compact mode uses smaller icon', (tester) async {
        await tester.pumpWidget(buildBadge(AvailabilityStatus.plenty));
        final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(icon.size, 14);
      });
    });
  });
}
