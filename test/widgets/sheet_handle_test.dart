import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SheetHandle', () {
    testWidgets('renders a 32x4 rounded container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SheetHandle())),
      );

      final container = tester.widget<Container>(find.byType(Container));
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
        find.ancestor(
          of: find.byType(Container),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('honours a passed key on the inner container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SheetHandle(key: Key('my_drag_handle'))),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const Key('my_drag_handle')),
      );
      expect(
        container.constraints,
        const BoxConstraints.tightFor(width: 32, height: 4),
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

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, lightTheme.colorScheme.onSurfaceVariant);
    });
  });
}
