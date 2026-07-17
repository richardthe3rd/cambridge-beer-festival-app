import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

/// Finds the [Title] whose composed [Title.title] equals [expected].
///
/// A [MaterialApp] inserts its own [Title] widget, so we can't just grab the
/// first — we assert on the specific title our widget composed.
Title _titleWith(WidgetTester tester, String expected) {
  return tester
      .widgetList<Title>(find.byType(Title))
      .firstWhere((t) => t.title == expected);
}

void main() {
  group('PageTitle', () {
    testWidgets('shows only pageTitle when no contextLabel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageTitle(
            pageTitle: 'Cambridge Beer Festival 2025',
            child: Scaffold(),
          ),
        ),
      );

      expect(_titleWith(tester, 'Cambridge Beer Festival 2025'), isNotNull);
    });

    testWidgets('joins pageTitle and contextLabel with a separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageTitle(
            pageTitle: 'Adnams Ghost Ship',
            contextLabel: 'Cambridge Beer Festival 2025',
            child: Scaffold(),
          ),
        ),
      );

      expect(
        _titleWith(tester, 'Adnams Ghost Ship · Cambridge Beer Festival 2025'),
        isNotNull,
      );
    });

    testWidgets('treats an empty contextLabel like no context', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageTitle(
            pageTitle: 'About',
            contextLabel: '',
            child: Scaffold(),
          ),
        ),
      );

      expect(_titleWith(tester, 'About'), isNotNull);
    });

    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageTitle(
            pageTitle: 'About',
            child: Scaffold(body: Text('body content')),
          ),
        ),
      );

      expect(find.text('body content'), findsOneWidget);
    });
  });
}
