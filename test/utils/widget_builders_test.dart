import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Builders', () {
    group('buildLoadingScaffold', () {
      testWidgets('creates scaffold with loading indicator', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: buildLoadingScaffold(),
          ),
        );

        // Verify AppBar with "Loading..." title
        expect(find.text('Loading...'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify it's centered
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('has correct widget structure', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: buildLoadingScaffold(),
          ),
        );

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
                  appBar: AppBar(
                    leading: result ?? const Icon(Icons.error),
                  ),
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
        expect(customSemantics.properties.hint, equals('Double tap to return to drinks list'));
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

    group('buildBreadcrumbTitle', () {
      testWidgets('displays title and festival name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    title: buildBreadcrumbTitle(
                      context,
                      title: 'IPA Beers',
                      festivalName: 'Cambridge Beer Festival 2025',
                    ),
                  ),
                  body: const Text('Body'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('IPA Beers'), findsOneWidget);
        expect(find.text('Cambridge Beer Festival 2025'), findsOneWidget);
      });

      testWidgets('uses correct text styles', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    title: buildBreadcrumbTitle(
                      context,
                      title: 'Test Title',
                      festivalName: 'Test Festival',
                    ),
                  ),
                  body: const Text('Body'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the Column widget that contains both texts
        final column = tester.widget<Column>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Column),
          ),
        );

        expect(column.mainAxisSize, equals(MainAxisSize.min));
        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));

        // Verify two Text widgets exist
        final textWidgets = find.descendant(
          of: find.byType(Column),
          matching: find.byType(Text),
        );
        expect(textWidgets, findsNWidgets(2));
      });

      testWidgets('handles long text with ellipsis', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    title: buildBreadcrumbTitle(
                      context,
                      title: 'A' * 100, // Very long title
                      festivalName: 'B' * 100, // Very long festival name
                    ),
                  ),
                  body: const Text('Body'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find all Text widgets in the AppBar
        final textWidgets = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Text),
          ),
        );

        // Both text widgets should have ellipsis overflow
        for (final text in textWidgets) {
          expect(text.overflow, equals(TextOverflow.ellipsis));
        }
      });

      testWidgets('uses theme-appropriate colors', (tester) async {
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return Scaffold(
                  appBar: AppBar(
                    title: buildBreadcrumbTitle(
                      context,
                      title: 'Test Title',
                      festivalName: 'Test Festival',
                    ),
                  ),
                  body: const Text('Body'),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final theme = Theme.of(capturedContext);

        // Find the festival name text (should be the second Text widget)
        final textWidgets = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Text),
          ),
        ).toList();

        expect(textWidgets.length, equals(2));

        // First text should use titleLarge
        expect(textWidgets[0].style?.fontSize, equals(theme.textTheme.titleLarge?.fontSize));

        // Second text should use bodySmall with onSurfaceVariant color
        expect(textWidgets[1].style?.fontSize, equals(theme.textTheme.bodySmall?.fontSize));
        expect(textWidgets[1].style?.color, equals(theme.colorScheme.onSurfaceVariant));
      });
    });
  });
}
