import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/environment_badge.dart';

void main() {
  group('EnvironmentBadge', () {
    testWidgets('renders without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(child: Text('Content')),
                EnvironmentBadge(),
              ],
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('badge shows environment name when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EnvironmentBadge(environmentName: 'Staging'),
              ],
            ),
          ),
        ),
      );

      // Badge should be visible when environment name is provided
      expect(find.text('Staging'), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    });

    testWidgets('badge is hidden in production (no environment name)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EnvironmentBadge(),
              ],
            ),
          ),
        ),
      );

      // Badge should not display when there's no environment name
      // (production environment)
      expect(find.byType(Positioned), findsNothing);
    });
  });
}
