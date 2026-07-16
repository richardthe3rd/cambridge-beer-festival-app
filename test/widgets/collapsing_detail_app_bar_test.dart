import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/collapsing_detail_app_bar.dart';

void main() {
  group('CollapsingDetailAppBar', () {
    // Pumps the bar above a tall list so there is room to scroll past the
    // threshold. Returns the controller so tests can drive the offset directly.
    Future<ScrollController> pumpBar(
      WidgetTester tester, {
      String contextTitle = 'Cambridge Beer Festival 2026',
      String collapsedTitle = 'Bishops Farewell',
      String? collapsedSubtitle = 'Oakham Ales',
      double threshold = 100,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                CollapsingDetailAppBar(
                  scrollController: controller,
                  contextTitle: contextTitle,
                  collapsedTitle: collapsedTitle,
                  collapsedSubtitle: collapsedSubtitle,
                  collapseThreshold: threshold,
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 100, child: Text('row $i')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('shows the context title, not the identity, at the top', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.text('Cambridge Beer Festival 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('appbar-collapsed-title')),
        findsNothing,
      );
    });

    testWidgets('fades to the identity once scrolled past the threshold', (
      tester,
    ) async {
      final controller = await pumpBar(tester, threshold: 100);

      controller.jumpTo(300);
      await tester.pumpAndSettle();

      final collapsed = find.byKey(const ValueKey('appbar-collapsed-title'));
      expect(collapsed, findsOneWidget);
      expect(
        find.descendant(of: collapsed, matching: find.text('Bishops Farewell')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: collapsed, matching: find.text('Oakham Ales')),
        findsOneWidget,
      );
      // The context line is gone once collapsed.
      expect(find.text('Cambridge Beer Festival 2026'), findsNothing);
    });

    testWidgets('returns to the context title when scrolled back to the top', (
      tester,
    ) async {
      final controller = await pumpBar(tester, threshold: 100);

      controller.jumpTo(300);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('appbar-collapsed-title')),
        findsOneWidget,
      );

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('appbar-collapsed-title')),
        findsNothing,
      );
      expect(find.text('Cambridge Beer Festival 2026'), findsOneWidget);
    });

    testWidgets('omits the subtitle line when none is given', (tester) async {
      final controller = await pumpBar(
        tester,
        collapsedSubtitle: null,
        threshold: 100,
      );

      controller.jumpTo(300);
      await tester.pumpAndSettle();

      final collapsed = find.byKey(const ValueKey('appbar-collapsed-title'));
      expect(
        find.descendant(of: collapsed, matching: find.text('Bishops Farewell')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: collapsed, matching: find.text('Oakham Ales')),
        findsNothing,
      );
    });
  });
}
