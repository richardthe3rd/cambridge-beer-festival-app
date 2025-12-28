import 'package:cambridge_beer_festival_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('buildOverflowMenu', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Home'),
            ),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const Scaffold(
              body: Text('About'),
            ),
          ),
        ],
      );
    });

    Widget buildTestWidget() {
      return MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Scaffold(
          appBar: AppBar(
            actions: [
              buildOverflowMenu(context),
            ],
          ),
          body: child,
        ),
      );
    }

    testWidgets('displays overflow menu button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.byIcon(Icons.more_vert),
          matching: find.byType(Semantics),
        ).first,
      );

      expect(semantics.properties.label, 'Menu');
      expect(semantics.properties.hint, 'Double tap to open menu');
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('shows three menu items when opened', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Browse Festivals'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('shows festival icon for festivals option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Find the festivals menu item row
      final festivalsRow = find.ancestor(
        of: find.text('Browse Festivals'),
        matching: find.byType(Row),
      );

      expect(
        find.descendant(
          of: festivalsRow,
          matching: find.byIcon(Icons.festival),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows settings icon for settings option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final settingsRow = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(Row),
      );

      expect(
        find.descendant(
          of: settingsRow,
          matching: find.byIcon(Icons.settings),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows info icon for about option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final aboutRow = find.ancestor(
        of: find.text('About'),
        matching: find.byType(Row),
      );

      expect(
        find.descendant(
          of: aboutRow,
          matching: find.byIcon(Icons.info_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('navigates to about page when about selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/about');
    });

    testWidgets('has proper tooltip', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final menuButton = tester.widget<PopupMenuButton>(
        find.byType(PopupMenuButton<String>),
      );

      expect(menuButton.tooltip, 'Menu');
    });
  });
}
