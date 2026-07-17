import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

/// The composed titles of every [Title] widget in the tree.
///
/// A [MaterialApp] inserts its own [Title], so we assert that our composed
/// title is present among them rather than assuming ours is the only one.
/// Returning the full list lets `contains(...)` report every actual title on
/// failure, which is clearer than a `firstWhere` that throws before the
/// expectation runs.
Iterable<String> _titles(WidgetTester tester) {
  return tester.widgetList<Title>(find.byType(Title)).map((t) => t.title);
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

      expect(_titles(tester), contains('Cambridge Beer Festival 2025'));
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
        _titles(tester),
        contains('Adnams Ghost Ship · Cambridge Beer Festival 2025'),
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

      expect(_titles(tester), contains('About'));
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
