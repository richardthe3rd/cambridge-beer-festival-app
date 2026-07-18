import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/your_take_card.dart';

void main() {
  const product = Product(
    id: 'drink1',
    name: 'Test Beer',
    category: 'beer',
    dispense: 'cask',
    abv: 5.0,
  );

  const producer = Producer(
    id: 'brewery1',
    name: 'Test Brewery',
    location: 'Cambridge, UK',
    products: [],
  );

  Drink createSampleDrink({String? notes}) {
    return Drink(
      product: product,
      producer: producer,
      festivalId: 'cbf2025',
      userState: notes == null
          ? null
          : UserDrinkState(
              notes: notes,
              createdAt: DateTime(2025, 6, 10),
              updatedAt: DateTime(2025, 6, 10),
            ),
    );
  }

  Widget buildWidget({
    Drink? drink,
    VoidCallback? onWantToTryTap,
    ValueChanged<int?>? onRatingChanged,
    Future<void> Function(String? notes)? onNotesChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: YourTakeCard(
          drink: drink ?? createSampleDrink(),
          onWantToTryTap: onWantToTryTap ?? () {},
          onRatingChanged: onRatingChanged ?? (_) {},
          onNotesChanged: onNotesChanged ?? (_) async {},
        ),
      ),
    );
  }

  group('YourTakeCard notes', () {
    testWidgets('shows a placeholder when there are no notes', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Tap to add your notes'), findsOneWidget);
    });

    testWidgets('shows the note text when notes are present', (tester) async {
      await tester.pumpWidget(
        buildWidget(drink: createSampleDrink(notes: 'Lovely and hoppy')),
      );
      expect(find.text('Lovely and hoppy'), findsOneWidget);
      expect(find.text('Tap to add your notes'), findsNothing);
    });

    testWidgets('tapping the note row opens an inline, prefilled field', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(drink: createSampleDrink(notes: 'Lovely and hoppy')),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('user-notes-field')),
      );
      expect(field.controller?.text, 'Lovely and hoppy');
    });

    testWidgets('does not autosave before the debounce window elapses', (
      tester,
    ) async {
      final calls = <String?>[];
      await tester.pumpWidget(
        buildWidget(onNotesChanged: (notes) async => calls.add(notes)),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        'Nice IPA',
      );
      // Well within the debounce window.
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, isEmpty);

      // Let the pending timer resolve so it doesn't leak past the test body.
      await tester.pump(YourTakeCard.notesDebounceDuration);
    });

    testWidgets('autosaves the trimmed text once the debounce elapses', (
      tester,
    ) async {
      final calls = <String?>[];
      await tester.pumpWidget(
        buildWidget(onNotesChanged: (notes) async => calls.add(notes)),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        '  Nice IPA  ',
      );
      await tester.pump(
        YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
      );

      expect(calls, ['Nice IPA']);
    });

    testWidgets('whitespace-only text autosaves as null', (tester) async {
      final calls = <String?>[];
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(notes: 'Existing'),
          onNotesChanged: (notes) async => calls.add(notes),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        '   ',
      );
      await tester.pump(
        YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
      );

      expect(calls, [null]);
    });

    testWidgets('unfocusing before the debounce elapses saves immediately', (
      tester,
    ) async {
      final calls = <String?>[];
      await tester.pumpWidget(
        buildWidget(onNotesChanged: (notes) async => calls.add(notes)),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        'Quick save',
      );
      // Well before the debounce window would otherwise fire.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(calls, ['Quick save']);
    });

    testWidgets(
      'clearing an existing note is persisted even when the widget is '
      'disposed before the debounce fires',
      (tester) async {
        final calls = <String?>[];
        await tester.pumpWidget(
          buildWidget(
            drink: createSampleDrink(notes: 'Existing'),
            onNotesChanged: (notes) async => calls.add(notes),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          '',
        );

        // Dispose the card before the debounce window elapses — the cleared
        // note must still be flushed exactly once, not silently dropped.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

        expect(calls, [null]);
      },
    );

    testWidgets('a failed save is not reported as Saved and is retried', (
      tester,
    ) async {
      var shouldFail = true;
      var attempts = 0;
      final saved = <String?>[];
      await tester.pumpWidget(
        buildWidget(
          onNotesChanged: (notes) async {
            attempts++;
            if (shouldFail) throw Exception('write failed');
            saved.add(notes);
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        'Nice IPA',
      );
      await tester.pump(
        YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
      );
      await tester.pump();

      expect(attempts, 1);
      expect(find.text('Saved'), findsNothing);

      // The edit stays pending: the next keystroke's flush retries it.
      shouldFail = false;
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        'Nice IPA indeed',
      );
      await tester.pump(
        YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
      );
      await tester.pump();

      expect(saved, ['Nice IPA indeed']);
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(YourTakeCard.savedIndicatorDuration);
    });

    testWidgets(
      'the note just typed stays visible after blur while the save is '
      'still in flight',
      (tester) async {
        final completer = Completer<void>();
        await tester.pumpWidget(
          buildWidget(onNotesChanged: (_) => completer.future),
        );

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'Great beer',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        // Back in display mode with the save unresolved — the new text must
        // not flash back to the placeholder while the write is in flight.
        expect(find.byKey(const ValueKey('user-notes-field')), findsNothing);
        expect(find.text('Great beer'), findsOneWidget);
        expect(find.text('Tap to add your notes'), findsNothing);

        completer.complete();
        await tester.pump();
        await tester.pump(YourTakeCard.savedIndicatorDuration);
      },
    );

    testWidgets('the Saved indicator appears after a save and clears itself', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('user-notes-field')),
        'Nice IPA',
      );
      await tester.pump(
        YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
      );
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(YourTakeCard.savedIndicatorDuration);
      await tester.pump();

      expect(find.text('Saved'), findsNothing);
    });
  });

  group('YourTakeCard notes semantics', () {
    testWidgets('display-mode note row is a labelled button (add state)', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Add your notes for Test Beer' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('display-mode note row is a labelled button (edit state)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(drink: createSampleDrink(notes: 'Lovely and hoppy')),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Edit your notes for Test Beer' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('the inline note field exposes a text-field semantics node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();

        expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsOne);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the Saved indicator is announced as a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'Nice IPA',
        );
        await tester.pump(
          YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
        );
        await tester.pump();

        final savedNodeFinder = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Saved',
        );
        expect(savedNodeFinder, findsOneWidget);

        final node = tester.getSemantics(savedNodeFinder);
        expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      } finally {
        handle.dispose();
      }
    });
  });
}
