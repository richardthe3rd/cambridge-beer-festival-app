import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Builders', () {
    group('buildLoadingScaffold', () {
      testWidgets('creates scaffold with loading indicator', (tester) async {
        await tester.pumpWidget(MaterialApp(home: buildLoadingScaffold()));

        // Verify AppBar with "Loading..." title
        expect(find.text('Loading...'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify it's centered
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('has correct widget structure', (tester) async {
        await tester.pumpWidget(MaterialApp(home: buildLoadingScaffold()));

        // Verify Scaffold is the root
        expect(find.byType(Scaffold), findsOneWidget);

        // Verify structure: Scaffold > AppBar + body
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.appBar, isNotNull);
        expect(scaffold.body, isNotNull);
      });
    });

    group('buildHomeLeadingButton', () {
      testWidgets('returns widget with home icon when called', (tester) async {
        Widget? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                result = buildHomeLeadingButton(context, 'cbf2025');
                // If result is null, show placeholder
                return Scaffold(
                  appBar: AppBar(leading: result ?? const Icon(Icons.error)),
                  body: const Text('Test'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // In test environment without GoRouter, canPopNavigation returns false
        // So buildHomeLeadingButton should return a home button widget
        expect(result, isNotNull);

        // Verify home icon is present
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('home button has correct semantics', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final widget = buildHomeLeadingButton(context, 'cbf2025');
                return Scaffold(
                  appBar: AppBar(leading: widget),
                  body: const Text('Test'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find all Semantics widgets that are ancestors of the home icon
        final semanticsList = tester.widgetList<Semantics>(
          find.ancestor(
            of: find.byIcon(Icons.home),
            matching: find.byType(Semantics),
          ),
        );

        // Find the one with our custom label
        final customSemantics = semanticsList.firstWhere(
          (s) => s.properties.label == 'Go to home screen',
        );

        expect(customSemantics.properties.label, equals('Go to home screen'));
        expect(
          customSemantics.properties.hint,
          equals('Double tap to return to drinks list'),
        );
        expect(customSemantics.properties.button, isTrue);
      });

      testWidgets('home button has tooltip', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final widget = buildHomeLeadingButton(context, 'cbf2025');
                return Scaffold(
                  appBar: AppBar(leading: widget),
                  body: const Text('Test'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find IconButton and check tooltip
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals('Home'));
      });
    });
  });
}
