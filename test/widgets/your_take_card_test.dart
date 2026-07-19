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

  Drink createSampleDrink({
    String? notes,
    bool wantToTry = false,
    List<DateTime>? tastingEvents,
  }) {
    final hasState = notes != null || wantToTry || tastingEvents != null;
    return Drink(
      product: product,
      producer: producer,
      festivalId: 'cbf2025',
      userState: !hasState
          ? null
          : UserDrinkState(
              notes: notes,
              wantToTry: wantToTry,
              tastingEvents: tastingEvents ?? const [],
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
    ValueChanged<bool>? onEditingChanged,
    VoidCallback? onLogTasting,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: YourTakeCard(
          drink: drink ?? createSampleDrink(),
          onWantToTryTap: onWantToTryTap ?? () {},
          onRatingChanged: onRatingChanged ?? (_) {},
          onNotesChanged: onNotesChanged ?? (_) async {},
          onEditingChanged: onEditingChanged,
          onLogTasting: onLogTasting,
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

    testWidgets('reports editing state changes to the host', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(buildWidget(onEditingChanged: changes.add));

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();
      expect(changes, [true]);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(changes, [true, false]);
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

    testWidgets(
      'the Saved indicator is suppressed while a newer edit is pending',
      (tester) async {
        final completers = <Completer<void>>[];
        await tester.pumpWidget(
          buildWidget(
            onNotesChanged: (_) {
              final completer = Completer<void>();
              completers.add(completer);
              return completer.future;
            },
          ),
        );

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'First',
        );
        await tester.pump(
          YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
        );
        expect(completers, hasLength(1));

        // Type again while the first save is still in flight, then let the
        // first save complete — 'Saved' would misrepresent the newest text.
        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'First and second',
        );
        completers[0].complete();
        await tester.pump();
        expect(find.text('Saved'), findsNothing);

        // Once the newer edit's own save lands, the indicator shows.
        await tester.pump(
          YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
        );
        expect(completers, hasLength(2));
        completers[1].complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Saved'), findsOneWidget);

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

  group('YourTakeCard My Festival nudge', () {
    testWidgets('appears for a note-only drink with a Drunk it! action', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(notes: 'Dave said try this'),
          onLogTasting: () {},
        ),
      );

      expect(find.text('Show it in My Festival?'), findsOneWidget);
      expect(find.byKey(const ValueKey('nudge-drunk-it')), findsOneWidget);
      // Want-to-try is NOT repeated in the nudge — the header pill is the
      // one control for that signal, so exactly one exists in the card.
      expect(find.text('Want to Try'), findsOneWidget);
    });

    testWidgets('is absent when there is no note', (tester) async {
      await tester.pumpWidget(buildWidget(onLogTasting: () {}));
      expect(find.text('Show it in My Festival?'), findsNothing);
    });

    testWidgets('is absent once the drink is want-to-try', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(
            notes: 'Dave said try this',
            wantToTry: true,
          ),
          onLogTasting: () {},
        ),
      );
      expect(find.text('Show it in My Festival?'), findsNothing);
    });

    testWidgets('is absent once the drink has a tasting', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(
            notes: 'Loved it',
            tastingEvents: [DateTime(2025, 6, 11, 18, 45)],
          ),
          onLogTasting: () {},
        ),
      );
      expect(find.text('Show it in My Festival?'), findsNothing);
    });

    testWidgets('appears as soon as note editing begins', (tester) async {
      await tester.pumpWidget(buildWidget(onLogTasting: () {}));

      await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
      await tester.pump();

      // The prompt is offered at writing time, above the field (below the
      // field it would be clipped by the keyboard on a phone), so a
      // note-only capture is classifiable in the moment.
      expect(find.byKey(const ValueKey('user-notes-field')), findsOneWidget);
      expect(find.text('Show it in My Festival?'), findsOneWidget);
    });

    testWidgets(
      'is absent while editing a note on an already-signalled drink',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(
            drink: createSampleDrink(notes: 'Loved it', wantToTry: true),
            onLogTasting: () {},
          ),
        );

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pump();

        expect(find.text('Show it in My Festival?'), findsNothing);
      },
    );

    testWidgets('the Drunk it! button invokes the log-tasting callback', (
      tester,
    ) async {
      var logTastingTaps = 0;
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(notes: 'Dave said try this'),
          onLogTasting: () => logTastingTaps++,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('nudge-drunk-it')));

      expect(logTastingTaps, 1);
    });

    testWidgets('is absent entirely when no log callback is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(drink: createSampleDrink(notes: 'Dave said try this')),
      );

      expect(find.text('Show it in My Festival?'), findsNothing);
      expect(find.byKey(const ValueKey('nudge-drunk-it')), findsNothing);
    });

    testWidgets('the Drunk it! button is a labelled button', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          drink: createSampleDrink(notes: 'Dave said try this'),
          onLogTasting: () {},
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Log a tasting of Test Beer' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
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
