import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/collapsing_detail_app_bar.dart';

void main() {
  group('CollapsingDetailAppBar', () {
    const contextText = 'Cambridge Beer Festival 2026';
    const collapsedText = 'Bishops Farewell';
    const subtitleText = 'Oakham Ales';
    final collapsedKey = find.byKey(const ValueKey('appbar-collapsed-title'));

    // Opacity of the collapsed identity layer (only present once revealing).
    double collapsedOpacity(WidgetTester tester) {
      final opacity = find.ancestor(
        of: collapsedKey,
        matching: find.byType(Opacity),
      );
      return tester.widget<Opacity>(opacity.first).opacity;
    }

    // Plain text of the collapsed identity (name, plus brewery inline when set).
    String collapsedPlainText(WidgetTester tester) {
      final text = tester.widget<Text>(
        find.descendant(of: collapsedKey, matching: find.byType(Text)),
      );
      return text.textSpan?.toPlainText() ?? text.data ?? '';
    }

    // Pumps the bar above a keyed hero and a tall list, so the hero can scroll
    // up under the bar. Returns the controller so tests can drive the offset.
    Future<ScrollController> pumpBar(
      WidgetTester tester, {
      double heroHeight = 300,
      String? subtitle = subtitleText,
      ScrollController? controller,
    }) async {
      final scroll = controller ?? ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                CollapsingDetailAppBar(
                  scrollController: scroll,
                  contextTitle: contextText,
                  collapsedTitle: collapsedText,
                  collapsedSubtitle: subtitle,
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: heroHeight,
                    child: const Text('hero'),
                  ),
                ),
                SliverList.builder(
                  itemCount: 20,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 100, child: Text('row $i')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return scroll;
    }

    testWidgets('shows the context title, not the identity, at the top', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.text(contextText), findsOneWidget);
      expect(collapsedKey, findsNothing);
    });

    testWidgets('reveals the identity as the hero scrolls under the bar', (
      tester,
    ) async {
      final controller = await pumpBar(tester);

      controller.jumpTo(300);
      await tester.pumpAndSettle();

      expect(collapsedKey, findsOneWidget);
      expect(collapsedOpacity(tester), 1.0);
      // Name plus the brewery inline on the one line.
      expect(collapsedPlainText(tester), contains(collapsedText));
      expect(collapsedPlainText(tester), contains(subtitleText));
    });

    testWidgets('shows only the name when no brewery subtitle is given', (
      tester,
    ) async {
      final controller = await pumpBar(tester, subtitle: null);

      controller.jumpTo(300);
      await tester.pumpAndSettle();

      expect(collapsedPlainText(tester), collapsedText);
    });

    testWidgets('fade tracks scroll position continuously (no hard toggle)', (
      tester,
    ) async {
      final controller = await pumpBar(tester);

      // Part-way through the reveal span the identity is partially faded in —
      // proof the transition is scroll-linked, not an all-or-nothing switch.
      controller.jumpTo(36);
      await tester.pumpAndSettle();

      expect(collapsedKey, findsOneWidget);
      final opacity = collapsedOpacity(tester);
      expect(opacity, greaterThan(0.0));
      expect(opacity, lessThan(1.0));
    });

    testWidgets('reflects a non-zero initial scroll offset on first build', (
      tester,
    ) async {
      // A screen that restores its scroll position should show the collapsed
      // identity immediately, not the context title.
      await pumpBar(
        tester,
        controller: ScrollController(initialScrollOffset: 300),
      );

      expect(collapsedKey, findsOneWidget);
      expect(collapsedOpacity(tester), 1.0);
    });

    testWidgets('returns to the context title when scrolled back to the top', (
      tester,
    ) async {
      final controller = await pumpBar(tester);

      controller.jumpTo(300);
      await tester.pumpAndSettle();
      expect(collapsedKey, findsOneWidget);

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(collapsedKey, findsNothing);
      expect(find.text(contextText), findsOneWidget);
    });

    testWidgets('keeps the identity a single line at large text scale', (
      tester,
    ) async {
      // A fixed-height toolbar can't grow, so the title must stay one line.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final controller = await pumpBar(tester);
      controller.jumpTo(300);
      await tester.pumpAndSettle();

      final line = tester.widget<Text>(
        find.descendant(of: collapsedKey, matching: find.byType(Text)),
      );
      expect(line.maxLines, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
