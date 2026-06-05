import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/festival_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FestivalStatusBadge', () {
    Widget wrap(
      FestivalStatus status, {
      Brightness brightness = Brightness.light,
    }) {
      // Wrap the badge in an explicit Theme so brightness is deterministic
      // regardless of the test platform's system brightness.
      return MaterialApp(
        home: Theme(
          data: ThemeData(brightness: brightness),
          child: Scaffold(
            body: Center(child: FestivalStatusBadge(status: status)),
          ),
        ),
      );
    }

    const expectedLabels = {
      FestivalStatus.live: 'LIVE',
      FestivalStatus.upcoming: 'SOON',
      FestivalStatus.mostRecent: 'RECENT',
      FestivalStatus.past: 'PAST',
    };

    for (final entry in expectedLabels.entries) {
      testWidgets('renders ${entry.value} label for ${entry.key}', (
        tester,
      ) async {
        await tester.pumpWidget(wrap(entry.key));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('badge colour adapts to light and dark themes', (tester) async {
      Color colorOf(WidgetTester t) {
        final container = t.widget<Container>(
          find.ancestor(
            of: find.text('LIVE'),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      await tester.pumpWidget(wrap(FestivalStatus.live));
      expect(colorOf(tester), const Color(0xFF2E7D32));

      await tester.pumpWidget(
        wrap(FestivalStatus.live, brightness: Brightness.dark),
      );
      expect(colorOf(tester), const Color(0xFF4CAF50));
    });
  });
}
