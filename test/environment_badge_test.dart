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

    testWidgets('badge is positioned in top-right corner', (WidgetTester tester) async {
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

      // Find the Positioned widget
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      
      // Verify it's positioned at top-right
      expect(positioned.top, equals(0));
      expect(positioned.right, equals(0));
    });
  });
}
