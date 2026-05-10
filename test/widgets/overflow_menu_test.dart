import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildOverflowMenu', () {
    Widget buildMenuWidget() {
      return MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: buildOverflowMenu(context),
            ),
          ),
        ),
      );
    }

    testWidgets('displays overflow menu button', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('has correct semantics', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      // Find all Semantics widgets that are ancestors of the icon
      final semanticsList = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.byIcon(Icons.more_vert),
          matching: find.byType(Semantics),
        ),
      );

      // Find the one with the label we set
      final menuSemantics = semanticsList.firstWhere(
        (s) => s.properties.label == 'Menu',
      );

      expect(menuSemantics.properties.label, 'Menu');
      expect(menuSemantics.properties.hint, 'Double tap to open menu');
      expect(menuSemantics.properties.button, isTrue);
    });

    testWidgets('shows three menu items when opened', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Browse Festivals'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('shows festival icon for festivals option', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

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
      await tester.pumpWidget(buildMenuWidget());

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
      await tester.pumpWidget(buildMenuWidget());

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

    testWidgets('uses high-contrast menu item colors in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: buildOverflowMenu(context),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final expectedColor = buildAppTheme(Brightness.light).colorScheme.onSurface;

      final festivalIcon = tester.widget<Icon>(find.byIcon(Icons.festival));
      expect(festivalIcon.color, expectedColor);

      final festivalText = tester.widget<Text>(find.text('Browse Festivals'));
      expect(festivalText.style?.color, expectedColor);
    });


    testWidgets('has proper tooltip', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      final menuButton = tester.widget<PopupMenuButton>(
        find.byType(PopupMenuButton<String>),
      );

      expect(menuButton.tooltip, 'Menu');
    });
  });
}
