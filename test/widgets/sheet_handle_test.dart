import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SheetHandle', () {
    // Scoped to SheetHandle's own subtree so the finders stay unambiguous
    // if the surrounding test scaffolding ever gains its own Containers.
    final handleContainer = find.descendant(
      of: find.byType(SheetHandle),
      matching: find.byType(Container),
    );

    testWidgets('renders a 32x4 rounded container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SheetHandle())),
      );

      expect(handleContainer, findsOneWidget);
      final container = tester.widget<Container>(handleContainer);
      expect(
        container.constraints,
        const BoxConstraints.tightFor(width: 32, height: 4),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(2));
    });

    testWidgets('centres the handle in its available space', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SheetHandle())),
      );

      expect(
        find.ancestor(of: handleContainer, matching: find.byType(Center)),
        findsOneWidget,
      );
    });

    testWidgets('applies handleKey to the inner container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SheetHandle(handleKey: Key('my_drag_handle'))),
        ),
      );

      // Exactly one match: the key lands on the Container only, never on the
      // SheetHandle itself, so tester.widget<Container>() stays unambiguous.
      expect(find.byKey(const Key('my_drag_handle')), findsOneWidget);

      final container = tester.widget<Container>(
        find.byKey(const Key('my_drag_handle')),
      );
      expect(
        container.constraints,
        const BoxConstraints.tightFor(width: 32, height: 4),
      );
    });

    testWidgets('keys the widget itself normally via key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SheetHandle(key: Key('handle_widget'))),
        ),
      );

      expect(find.byKey(const Key('handle_widget')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('handle_widget'))),
        isA<SheetHandle>(),
      );
    });

    testWidgets('uses onSurfaceVariant from the current theme', (tester) async {
      final lightTheme = buildAppTheme(Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: const Scaffold(body: SheetHandle()),
        ),
      );

      expect(handleContainer, findsOneWidget);
      final container = tester.widget<Container>(handleContainer);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, lightTheme.colorScheme.onSurfaceVariant);
    });
  });
}
