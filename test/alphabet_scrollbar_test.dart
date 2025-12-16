import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

void main() {
  group('AlphabetScrollbar', () {
    testWidgets('displays all 26 letters of the alphabet', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (_) {},
            ),
          ),
        ),
      );

      // Should find all 26 letters
      for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        expect(find.text(letter), findsOneWidget);
      }
    });

    testWidgets('calls onLetterTapped when letter is tapped', (WidgetTester tester) async {
      String? tappedLetter;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (letter) {
                tappedLetter = letter;
              },
            ),
          ),
        ),
      );

      // Tap on letter 'A'
      await tester.tap(find.text('A'));
      await tester.pump();

      expect(tappedLetter, equals('A'));
      
      // Wait for the timer to clear active letter (500ms + a bit extra)
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('highlights tapped letter temporarily', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (_) {},
            ),
          ),
        ),
      );

      // Tap on letter 'M'
      await tester.tap(find.text('M'));
      await tester.pump();

      // Letter should be highlighted (bold and with primary color)
      final textWidget = tester.widget<Text>(find.text('M'));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));

      // After delay, highlight should be removed
      await tester.pump(const Duration(milliseconds: 600));
      final textWidgetAfter = tester.widget<Text>(find.text('M'));
      expect(textWidgetAfter.style?.fontWeight, equals(FontWeight.normal));
    });

    testWidgets('shows unavailable letters with reduced opacity', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (_) {},
              availableLetters: const {'A', 'B', 'C'}, // Only A, B, C available
            ),
          ),
        ),
      );

      // Find text widgets for available and unavailable letters
      final aText = tester.widget<Text>(find.text('A'));
      final zText = tester.widget<Text>(find.text('Z'));

      // Available letters should have full opacity
      expect(aText.style?.color?.a, greaterThan(0.5));
      
      // Unavailable letters should have reduced opacity
      expect(zText.style?.color?.a, lessThan(0.5));
    });

    testWidgets('does not call onLetterTapped for unavailable letters', (WidgetTester tester) async {
      String? tappedLetter;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (letter) {
                tappedLetter = letter;
              },
              availableLetters: const {'A', 'B', 'C'}, // Only A, B, C available
            ),
          ),
        ),
      );

      // Try to tap on unavailable letter 'Z'
      await tester.tap(find.text('Z'));
      await tester.pump();

      // Callback should not be called
      expect(tappedLetter, isNull);

      // Tap on available letter 'A'
      await tester.tap(find.text('A'));
      await tester.pump();

      // Callback should be called
      expect(tappedLetter, equals('A'));
      
      // Wait for the timer to clear active letter (500ms + a bit extra)
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('has correct semantics for accessibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScrollbar(
              onLetterTapped: (_) {},
              availableLetters: const {'A', 'M', 'Z'},
            ),
          ),
        ),
      );

      // Check semantics for available letter
      final aSemanticsNode = tester.getSemantics(find.text('A'));
      expect(aSemanticsNode.label, contains('Jump to letter A'));

      // Check semantics for unavailable letter
      final bSemanticsNode = tester.getSemantics(find.text('B'));
      expect(bSemanticsNode.label, contains('Jump to letter B'));
    });
  });
}
