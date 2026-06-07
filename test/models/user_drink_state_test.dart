import 'package:cambridge_beer_festival/models/user_drink_state.dart';
import 'package:flutter_test/flutter_test.dart';

UserDrinkState createSampleUserDrinkState({
  bool wantToTry = false,
  List<DateTime>? tastingEvents,
  int? rating,
  String? notes,
  List<String>? photoIds,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 6, 6, 12, 0, 0);
  return UserDrinkState(
    wantToTry: wantToTry,
    tastingEvents: tastingEvents,
    rating: rating,
    notes: notes,
    photoIds: photoIds,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  group('UserDrinkState', () {
    group('constructor', () {
      test('defaults to empty record with required timestamps', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state = UserDrinkState(createdAt: now, updatedAt: now);

        expect(state.wantToTry, false);
        expect(state.tastingEvents, isEmpty);
        expect(state.rating, isNull);
        expect(state.notes, isNull);
        expect(state.photoIds, isEmpty);
        expect(state.createdAt, now);
        expect(state.updatedAt, now);
      });

      test('accepts all fields', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final tasting1 = DateTime(2026, 5, 18);
        final tasting2 = DateTime(2026, 5, 19);

        final state = UserDrinkState(
          wantToTry: true,
          tastingEvents: [tasting1, tasting2],
          rating: 4,
          notes: 'Excellent hoppy notes',
          photoIds: ['photo1', 'photo2'],
          createdAt: now,
          updatedAt: now,
        );

        expect(state.wantToTry, true);
        expect(state.tastingEvents, [tasting1, tasting2]);
        expect(state.rating, 4);
        expect(state.notes, 'Excellent hoppy notes');
        expect(state.photoIds, ['photo1', 'photo2']);
      });

      test('defensively copies tastingEvents list to unmodifiable', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final inputEvents = [DateTime(2026, 5, 18)];

        final state = UserDrinkState(
          tastingEvents: inputEvents,
          createdAt: now,
          updatedAt: now,
        );

        // Mutating the input list does not affect the stored list
        inputEvents.add(DateTime(2026, 5, 19));
        expect(state.tastingEvents, hasLength(1));

        // The stored list is unmodifiable
        expect(
          () => state.tastingEvents.add(DateTime(2026, 5, 20)),
          throwsUnsupportedError,
        );
      });

      test('defensively copies photoIds list to unmodifiable', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final inputPhotos = ['photo1'];

        final state = UserDrinkState(
          photoIds: inputPhotos,
          createdAt: now,
          updatedAt: now,
        );

        // Mutating the input list does not affect the stored list
        inputPhotos.add('photo2');
        expect(state.photoIds, hasLength(1));

        // The stored list is unmodifiable
        expect(() => state.photoIds.add('photo2'), throwsUnsupportedError);
      });
    });

    group('factory initial()', () {
      test('returns empty record with timestamps', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state = UserDrinkState.initial(now: now);

        expect(state.isEmpty, true);
        expect(state.isTasted, false);
        expect(state.tastingCount, 0);
        expect(state.lastTastedAt, isNull);
        expect(state.wantToTry, false);
        expect(state.rating, isNull);
        expect(state.notes, isNull);
        expect(state.photoIds, isEmpty);
        expect(state.createdAt, now);
        expect(state.updatedAt, now);
      });

      test('uses DateTime.now() when now is null', () {
        final beforeCreation = DateTime.now();
        final state = UserDrinkState.initial();
        final afterCreation = DateTime.now();

        expect(state.createdAt.isAfter(beforeCreation), true);
        expect(state.updatedAt.isAfter(beforeCreation), true);
        expect(
          state.createdAt.isBefore(
            afterCreation.add(const Duration(seconds: 1)),
          ),
          true,
        );
        expect(
          state.updatedAt.isBefore(
            afterCreation.add(const Duration(seconds: 1)),
          ),
          true,
        );
      });
    });

    group('isTasted', () {
      test('returns false when tastingEvents is empty', () {
        final state = createSampleUserDrinkState();
        expect(state.isTasted, false);
      });

      test('returns true when tastingEvents is not empty', () {
        final state = createSampleUserDrinkState(
          tastingEvents: [DateTime(2026, 5, 18)],
        );
        expect(state.isTasted, true);
      });
    });

    group('tastingCount', () {
      test('returns 0 when tastingEvents is empty', () {
        final state = createSampleUserDrinkState();
        expect(state.tastingCount, 0);
      });

      test('returns the length of tastingEvents', () {
        final state = createSampleUserDrinkState(
          tastingEvents: [
            DateTime(2026, 5, 18),
            DateTime(2026, 5, 19),
            DateTime(2026, 5, 20),
          ],
        );
        expect(state.tastingCount, 3);
      });
    });

    group('lastTastedAt', () {
      test('returns null when tastingEvents is empty', () {
        final state = createSampleUserDrinkState();
        expect(state.lastTastedAt, isNull);
      });

      test('returns the most recent tasting event when they are in order', () {
        final tasting1 = DateTime(2026, 5, 18);
        final tasting2 = DateTime(2026, 5, 19);
        final tasting3 = DateTime(2026, 5, 20);

        final state = createSampleUserDrinkState(
          tastingEvents: [tasting1, tasting2, tasting3],
        );

        expect(state.lastTastedAt, tasting3);
      });

      test(
        'returns the most recent tasting event regardless of input order',
        () {
          final tasting1 = DateTime(2026, 5, 18);
          final tasting2 = DateTime(2026, 5, 19);
          final tasting3 = DateTime(2026, 5, 20);

          final state = createSampleUserDrinkState(
            tastingEvents: [tasting3, tasting1, tasting2],
          );

          expect(state.lastTastedAt, tasting3);
        },
      );

      test('handles a single tasting event', () {
        final tasting = DateTime(2026, 5, 18);
        final state = createSampleUserDrinkState(tastingEvents: [tasting]);

        expect(state.lastTastedAt, tasting);
      });
    });

    group('isEmpty', () {
      test('returns true when all fields are empty', () {
        final state = createSampleUserDrinkState();
        expect(state.isEmpty, true);
      });

      test('returns false when wantToTry is true', () {
        final state = createSampleUserDrinkState(wantToTry: true);
        expect(state.isEmpty, false);
      });

      test('returns false when tastingEvents is not empty', () {
        final state = createSampleUserDrinkState(
          tastingEvents: [DateTime(2026, 5, 18)],
        );
        expect(state.isEmpty, false);
      });

      test('returns false when rating is set', () {
        final state = createSampleUserDrinkState(rating: 4);
        expect(state.isEmpty, false);
      });

      test('returns false when notes is not empty', () {
        final state = createSampleUserDrinkState(notes: 'Great beer');
        expect(state.isEmpty, false);
      });

      test('returns true when notes is empty string', () {
        final state = createSampleUserDrinkState(notes: '');
        expect(state.isEmpty, true);
      });

      test('returns false when photoIds is not empty', () {
        final state = createSampleUserDrinkState(photoIds: ['photo1']);
        expect(state.isEmpty, false);
      });

      test('returns false when any combination of fields is set', () {
        final state = createSampleUserDrinkState(
          wantToTry: true,
          tastingEvents: [DateTime(2026, 5, 18)],
          rating: 3,
          notes: 'Good',
          photoIds: ['photo1'],
        );
        expect(state.isEmpty, false);
      });
    });

    group('copyWith', () {
      test('updates wantToTry when provided', () {
        final original = createSampleUserDrinkState(wantToTry: false);
        final updated = original.copyWith(wantToTry: true);

        expect(updated.wantToTry, true);
        expect(original.wantToTry, false);
      });

      test('updates tastingEvents when provided', () {
        final original = createSampleUserDrinkState(tastingEvents: []);
        final newEvents = [DateTime(2026, 5, 18), DateTime(2026, 5, 19)];
        final updated = original.copyWith(tastingEvents: newEvents);

        expect(updated.tastingEvents, newEvents);
        expect(original.tastingEvents, isEmpty);
      });

      test('updates rating when provided', () {
        final original = createSampleUserDrinkState(rating: null);
        final updated = original.copyWith(rating: 4);

        expect(updated.rating, 4);
        expect(original.rating, isNull);
      });

      test('clears rating when explicitly set to null', () {
        final original = createSampleUserDrinkState(rating: 4);
        final updated = original.copyWith(rating: null);

        expect(updated.rating, isNull);
        expect(original.rating, 4);
      });

      test('leaves rating unchanged when omitted', () {
        final original = createSampleUserDrinkState(rating: 3);
        final updated = original.copyWith(wantToTry: true);

        expect(updated.rating, 3);
      });

      test('updates notes when provided', () {
        final original = createSampleUserDrinkState(notes: 'Original notes');
        final updated = original.copyWith(notes: 'Updated notes');

        expect(updated.notes, 'Updated notes');
        expect(original.notes, 'Original notes');
      });

      test('clears notes when explicitly set to null', () {
        final original = createSampleUserDrinkState(notes: 'Some notes');
        final updated = original.copyWith(notes: null);

        expect(updated.notes, isNull);
        expect(original.notes, 'Some notes');
      });

      test('leaves notes unchanged when omitted', () {
        final original = createSampleUserDrinkState(notes: 'Original notes');
        final updated = original.copyWith(wantToTry: true);

        expect(updated.notes, 'Original notes');
      });

      test('updates photoIds when provided', () {
        final original = createSampleUserDrinkState(photoIds: ['old1']);
        final updated = original.copyWith(photoIds: ['new1', 'new2']);

        expect(updated.photoIds, ['new1', 'new2']);
        expect(original.photoIds, ['old1']);
      });

      test('updates createdAt when provided', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final later = DateTime(2026, 6, 7, 12, 0, 0);
        final original = createSampleUserDrinkState(createdAt: now);
        final updated = original.copyWith(createdAt: later);

        expect(updated.createdAt, later);
        expect(original.createdAt, now);
      });

      test('updates updatedAt when provided', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final later = DateTime(2026, 6, 7, 12, 0, 0);
        final original = createSampleUserDrinkState(updatedAt: now);
        final updated = original.copyWith(updatedAt: later);

        expect(updated.updatedAt, later);
        expect(original.updatedAt, now);
      });

      test('returns a new instance', () {
        final original = createSampleUserDrinkState();
        final updated = original.copyWith(wantToTry: true);

        expect(updated, isNot(same(original)));
      });
    });

    group('toJson and fromJson', () {
      test('round-trip preserves all fields', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final tasting1 = DateTime(2026, 5, 18, 10, 30, 0);
        final tasting2 = DateTime(2026, 5, 19, 14, 15, 0);

        final original = UserDrinkState(
          wantToTry: true,
          tastingEvents: [tasting1, tasting2],
          rating: 4,
          notes: 'Excellent hoppy notes',
          photoIds: ['photo1', 'photo2'],
          createdAt: now,
          updatedAt: now,
        );

        final json = original.toJson();
        final restored = UserDrinkState.fromJson(json);

        expect(restored, original);
        expect(restored.wantToTry, true);
        expect(restored.tastingEvents, [tasting1, tasting2]);
        expect(restored.rating, 4);
        expect(restored.notes, 'Excellent hoppy notes');
        expect(restored.photoIds, ['photo1', 'photo2']);
        expect(restored.createdAt, now);
        expect(restored.updatedAt, now);
      });

      test('toJson serialises DateTimes as millisecondsSinceEpoch', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state = createSampleUserDrinkState(
          createdAt: now,
          updatedAt: now,
        );
        final json = state.toJson();

        expect(json['createdAt'], now.millisecondsSinceEpoch);
        expect(json['updatedAt'], now.millisecondsSinceEpoch);
      });

      test('toJson serialises tastingEvents as List<int> of millis', () {
        final tasting1 = DateTime(2026, 5, 18, 10, 30, 0);
        final tasting2 = DateTime(2026, 5, 19, 14, 15, 0);
        final state = createSampleUserDrinkState(
          tastingEvents: [tasting1, tasting2],
        );
        final json = state.toJson();

        expect(json['tastingEvents'], [
          tasting1.millisecondsSinceEpoch,
          tasting2.millisecondsSinceEpoch,
        ]);
      });

      test('fromJson handles missing wantToTry as false', () {
        final json = {'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.wantToTry, false);
      });

      test('fromJson handles missing tastingEvents as empty list', () {
        final json = {'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.tastingEvents, isEmpty);
      });

      test('fromJson handles missing rating as null', () {
        final json = {'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.rating, isNull);
      });

      test('fromJson handles missing notes as null', () {
        final json = {'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.notes, isNull);
      });

      test('fromJson handles missing photoIds as empty list', () {
        final json = {'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.photoIds, isEmpty);
      });

      test('fromJson handles missing createdAt as epoch', () {
        final json = {'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      });

      test('fromJson handles missing updatedAt as epoch', () {
        final json = {'createdAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
      });

      test('fromJson handles null tastingEvents list', () {
        final json = {
          'wantToTry': false,
          'tastingEvents': null,
          'createdAt': 0,
          'updatedAt': 0,
        };
        final state = UserDrinkState.fromJson(json);

        expect(state.tastingEvents, isEmpty);
      });

      test('fromJson parses rating as int when num is provided', () {
        final json = {'rating': 4.7, 'createdAt': 0, 'updatedAt': 0};
        final state = UserDrinkState.fromJson(json);

        expect(state.rating, 4);
      });

      test('fromJson converts photoIds list elements to String', () {
        final json = {
          'photoIds': ['photo1', 'photo2'],
          'createdAt': 0,
          'updatedAt': 0,
        };
        final state = UserDrinkState.fromJson(json);

        expect(state.photoIds, ['photo1', 'photo2']);
      });

      test('fromJson coerces num-valued tastingEvents millis to int', () {
        // dart2js JSON decoding can hand back whole numbers as doubles; parse
        // defensively rather than crashing and dropping the whole record.
        final json = {
          'tastingEvents': [1747526400000.0],
          'createdAt': 0,
          'updatedAt': 0,
        };
        final state = UserDrinkState.fromJson(json);

        expect(
          state.tastingEvents.single,
          DateTime.fromMillisecondsSinceEpoch(1747526400000),
        );
      });
    });

    group('equality', () {
      test('two records with equal fields are equal', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state1 = UserDrinkState(
          wantToTry: true,
          tastingEvents: [DateTime(2026, 5, 18)],
          rating: 4,
          notes: 'Good beer',
          photoIds: ['photo1'],
          createdAt: now,
          updatedAt: now,
        );
        final state2 = UserDrinkState(
          wantToTry: true,
          tastingEvents: [DateTime(2026, 5, 18)],
          rating: 4,
          notes: 'Good beer',
          photoIds: ['photo1'],
          createdAt: now,
          updatedAt: now,
        );

        expect(state1, state2);
      });

      test('two records differing in any field are not equal', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final base = UserDrinkState(
          wantToTry: true,
          rating: 4,
          createdAt: now,
          updatedAt: now,
        );

        expect(base, isNot(base.copyWith(wantToTry: false)));
        expect(base, isNot(base.copyWith(rating: 3)));
        expect(base, isNot(base.copyWith(notes: 'Different')));
      });

      test('identical instances are equal', () {
        final state = createSampleUserDrinkState();
        expect(state, state);
      });

      test('equal records have equal hashCode', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state1 = UserDrinkState(
          wantToTry: true,
          rating: 4,
          createdAt: now,
          updatedAt: now,
        );
        final state2 = UserDrinkState(
          wantToTry: true,
          rating: 4,
          createdAt: now,
          updatedAt: now,
        );

        expect(state1.hashCode, state2.hashCode);
      });

      test('records with different tastingEvents are not equal', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state1 = UserDrinkState(
          tastingEvents: [DateTime(2026, 5, 18)],
          createdAt: now,
          updatedAt: now,
        );
        final state2 = UserDrinkState(
          tastingEvents: [DateTime(2026, 5, 19)],
          createdAt: now,
          updatedAt: now,
        );

        expect(state1, isNot(state2));
      });

      test('records with different photoIds are not equal', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state1 = UserDrinkState(
          photoIds: ['photo1'],
          createdAt: now,
          updatedAt: now,
        );
        final state2 = UserDrinkState(
          photoIds: ['photo2'],
          createdAt: now,
          updatedAt: now,
        );

        expect(state1, isNot(state2));
      });
    });

    group('toString', () {
      test('includes all relevant fields', () {
        final now = DateTime(2026, 6, 6, 12, 0, 0);
        final state = UserDrinkState(
          wantToTry: true,
          tastingEvents: [DateTime(2026, 5, 18)],
          rating: 4,
          notes: 'Good beer',
          photoIds: ['photo1', 'photo2'],
          createdAt: now,
          updatedAt: now,
        );

        final str = state.toString();

        expect(str, contains('wantToTry: true'));
        expect(str, contains('tastingCount: 1'));
        expect(str, contains('rating: 4'));
        expect(str, contains('notes: Good beer'));
      });
    });
  });
}
