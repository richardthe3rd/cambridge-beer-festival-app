import 'dart:convert';

import 'package:cambridge_beer_festival/constants/preference_keys.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/user_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesUserDataStore', () {
    late SharedPreferencesUserDataStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = SharedPreferencesUserDataStore(prefs);
    });

    LogEntry tasting(
      String drinkId,
      DateTime when, {
      String id = 'e',
      int? rating,
      String? note,
      List<String>? photoIds,
    }) => LogEntry(
      id: id,
      when: when,
      drinkId: drinkId,
      rating: rating,
      note: note,
      photoIds: photoIds,
    );

    group('entries', () {
      test('writeEntry then readEntries round-trips a record', () async {
        final entry = tasting(
          'd1',
          DateTime(2026, 6, 10, 14, 30),
          id: 'e1',
          rating: 4,
          note: 'Lovely',
          photoIds: const ['p1'],
        );
        await store.writeEntry('cbf2025', entry);

        final entries = store.readEntries('cbf2025');
        expect(entries, hasLength(1));
        expect(entries.single, equals(entry));
      });

      test('removeEntry deletes a single entry by id', () async {
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
        );
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 11), id: 'e2'),
        );

        await store.removeEntry('cbf2025', 'e1');

        final ids = store.readEntries('cbf2025').map((e) => e.id);
        expect(ids, equals(['e2']));
      });

      test('entries are scoped per festival', () async {
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
        );
        expect(store.readEntries('cbf2025'), hasLength(1));
        expect(store.readEntries('cbf2024'), isEmpty);
      });

      test(
        'does not match a festival whose id is a prefix of another',
        () async {
          await store.writeEntry(
            'cbf2025x',
            tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
          );
          expect(store.readEntries('cbf2025'), isEmpty);
        },
      );

      test(
        'a corrupt stored entry is treated as absent, not a crash',
        () async {
          SharedPreferences.setMockInitialValues({
            'log_entry_cbf2025_e1': 'not valid json',
          });
          final prefs = await SharedPreferences.getInstance();
          final corrupt = SharedPreferencesUserDataStore(prefs);

          expect(corrupt.readEntries('cbf2025'), isEmpty);
          expect(corrupt.read('cbf2025', 'd1'), isNull);
        },
      );
    });

    group('want-to-try', () {
      test('setWantToTry adds then removes a drink', () async {
        await store.setWantToTry('cbf2025', 'd1', value: true);
        expect(store.readWantToTry('cbf2025'), equals({'d1'}));

        await store.setWantToTry('cbf2025', 'd1', value: false);
        expect(store.readWantToTry('cbf2025'), isEmpty);
      });

      test('removes the key entirely once the set empties', () async {
        await store.setWantToTry('cbf2025', 'd1', value: true);
        await store.setWantToTry('cbf2025', 'd1', value: false);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('want_to_try_cbf2025'), isFalse);
      });

      test('is scoped per festival', () async {
        await store.setWantToTry('cbf2025', 'd1', value: true);
        expect(store.readWantToTry('cbf2025'), equals({'d1'}));
        expect(store.readWantToTry('cbf2024'), isEmpty);
      });
    });

    group('drink detail (rating / notes, independent of tastings)', () {
      test('setDrinkRating preserves existing notes', () async {
        await store.setDrinkNotes('cbf2025', 'd1', notes: 'zesty');
        await store.setDrinkRating('cbf2025', 'd1', rating: 4);

        final state = store.read('cbf2025', 'd1')!;
        expect(state.rating, 4);
        expect(state.notes, 'zesty');
      });

      test('clearing rating and notes prunes the record', () async {
        await store.setDrinkRating('cbf2025', 'd1', rating: 4);
        await store.setDrinkNotes('cbf2025', 'd1', notes: 'zesty');

        await store.setDrinkRating('cbf2025', 'd1', rating: null);
        await store.setDrinkNotes('cbf2025', 'd1', notes: null);

        expect(store.read('cbf2025', 'd1'), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('drink_detail_cbf2025_d1'), isFalse);
      });

      test('is scoped per festival', () async {
        await store.setDrinkRating('cbf2025', 'd1', rating: 3);
        expect(store.read('cbf2025', 'd1')!.rating, 3);
        expect(store.read('cbf2024', 'd1'), isNull);
      });
    });

    group('derived per-drink views', () {
      test('rating and notes come from the detail record', () async {
        await store.setDrinkRating('cbf2025', 'd1', rating: 4);
        await store.setDrinkNotes('cbf2025', 'd1', notes: 'hoppy');

        final state = store.read('cbf2025', 'd1')!;
        expect(state.rating, 4);
        expect(state.notes, 'hoppy');
      });

      test('rating is independent of the tasting timeline', () async {
        // Rate a drink that has no tastings: it is rated but not tasted.
        await store.setDrinkRating('cbf2025', 'd1', rating: 5);
        var state = store.read('cbf2025', 'd1')!;
        expect(state.rating, 5);
        expect(state.isTasted, isFalse);
        expect(state.tastingCount, 0);

        // Add tastings: the rating is unchanged and pours accumulate.
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10, 10, 0), id: 'e1'),
        );
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10, 18, 0), id: 'e2'),
        );
        state = store.read('cbf2025', 'd1')!;
        expect(state.rating, 5);
        expect(state.tastingCount, 2);
        expect(state.lastTastedAt, DateTime(2026, 6, 10, 18, 0));
      });

      test('want-to-try-only drink derives a non-tasted view', () async {
        await store.setWantToTry('cbf2025', 'd1', value: true);

        final state = store.read('cbf2025', 'd1')!;
        expect(state.wantToTry, isTrue);
        expect(state.isTasted, isFalse);
        expect(state.rating, isNull);
      });

      test('read returns null when there is no signal', () {
        expect(store.read('cbf2025', 'd1'), isNull);
      });

      test('readAll keys every drink with a signal on any axis', () async {
        // d1: tasted, d2: want-to-try only, d3: rating-only (no tasting).
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
        );
        await store.setWantToTry('cbf2025', 'd2', value: true);
        await store.setDrinkRating('cbf2025', 'd3', rating: 4);
        // A different festival must not leak in.
        await store.writeEntry(
          'cbf2024',
          tasting('d9', DateTime(2026, 6, 10), id: 'e9'),
        );

        final all = store.readAll('cbf2025');
        expect(all.keys, containsAll(['d1', 'd2', 'd3']));
        expect(all.keys, isNot(contains('d9')));
        expect(all['d1']!.isTasted, isTrue);
        expect(all['d2']!.wantToTry, isTrue);
        expect(all['d3']!.rating, 4);
        expect(all['d3']!.isTasted, isFalse);
      });

      test('readAll returns an empty map when there is no data', () {
        expect(store.readAll('cbf2025'), isEmpty);
      });
    });

    test('clearFestival removes only that festival\'s data', () async {
      await store.writeEntry(
        'cbf2025',
        tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
      );
      await store.setWantToTry('cbf2025', 'd1', value: true);
      await store.setDrinkRating('cbf2025', 'd1', rating: 4);
      await store.writeEntry(
        'cbf2024',
        tasting('d1', DateTime(2026, 6, 10), id: 'e2'),
      );
      await store.setWantToTry('cbf2024', 'd1', value: true);
      await store.setDrinkRating('cbf2024', 'd1', rating: 5);

      await store.clearFestival('cbf2025');

      expect(store.readEntries('cbf2025'), isEmpty);
      expect(store.readWantToTry('cbf2025'), isEmpty);
      expect(store.read('cbf2025', 'd1'), isNull);
      expect(store.readEntries('cbf2024'), hasLength(1));
      expect(store.readWantToTry('cbf2024'), equals({'d1'}));
      expect(store.read('cbf2024', 'd1')!.rating, 5);
    });

    group('entry schema versioning', () {
      test('writeEntry embeds the current schema version', () async {
        await store.writeEntry(
          'cbf2025',
          tasting('d1', DateTime(2026, 6, 10), id: 'e1'),
        );

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('log_entry_cbf2025_e1');
        expect(raw, isNotNull);
        final decoded = jsonDecode(raw!) as Map<String, dynamic>;
        expect(
          decoded[SharedPreferencesUserDataStore.schemaKey],
          SharedPreferencesUserDataStore.currentSchemaVersion,
        );
      });

      test(
        'an entry newer than this build is treated as absent, not a crash',
        () async {
          final future = jsonEncode(
            tasting('d1', DateTime(2026, 6, 10), id: 'e1').toJson()
              ..[SharedPreferencesUserDataStore.schemaKey] =
                  SharedPreferencesUserDataStore.currentSchemaVersion + 1,
          );
          SharedPreferences.setMockInitialValues({
            'log_entry_cbf2025_e1': future,
          });
          final prefs = await SharedPreferences.getInstance();
          final newer = SharedPreferencesUserDataStore(prefs);

          expect(newer.readEntries('cbf2025'), isEmpty);
          expect(newer.read('cbf2025', 'd1'), isNull);
          // The stored payload is left intact for a build that understands it.
          expect(prefs.containsKey('log_entry_cbf2025_e1'), isTrue);
        },
      );
    });

    group('migrate (v1 blob decode guard)', () {
      test('is a no-op for the current schema (round-trips the payload)', () {
        final payload = UserDrinkState.initial().copyWith(rating: 3).toJson()
          ..[SharedPreferencesUserDataStore.schemaKey] =
              SharedPreferencesUserDataStore.currentSchemaVersion;

        final migrated = SharedPreferencesUserDataStore.migrate(
          Map<String, dynamic>.from(payload),
        );

        expect(
          UserDrinkState.fromJson(migrated),
          UserDrinkState.fromJson(payload),
        );
      });

      test('treats a missing version as v1 without throwing', () {
        final payload = UserDrinkState.initial()
            .copyWith(wantToTry: true)
            .toJson();
        expect(
          () => SharedPreferencesUserDataStore.migrate(payload),
          returnsNormally,
        );
      });

      test('throws on a payload newer than the current schema', () {
        final payload = UserDrinkState.initial().copyWith(rating: 3).toJson()
          ..[SharedPreferencesUserDataStore.schemaKey] =
              SharedPreferencesUserDataStore.currentSchemaVersion + 1;
        expect(
          () => SharedPreferencesUserDataStore.migrate(payload),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('migrateLegacyData → v2 (pre-#391 → LogEntry)', () {
      // The production sequence runs migrateLegacyData (legacy → v1 blob) then
      // migrateToLogEntries (v1 blob → v2). These tests exercise both, then read
      // through the derived v2 views.
      Future<SharedPreferencesUserDataStore> migrated(
        Map<String, Object> initial,
      ) async {
        SharedPreferences.setMockInitialValues(initial);
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);
        await s.migrateLegacyData();
        await s.migrateToLogEntries();
        return s;
      }

      test('folds favourites, ratings and tasting into the v2 model', () async {
        final s = await migrated({
          'favorites_cbf2025': ['d1', 'd2'],
          'ratings_cbf2025_d2': 3,
          'tasting_log_cbf2025|d3': 1747526400000,
        });

        expect(s.read('cbf2025', 'd1')!.wantToTry, isTrue);
        expect(s.read('cbf2025', 'd2')!.wantToTry, isTrue);
        expect(s.read('cbf2025', 'd2')!.rating, 3);
        final d3 = s.read('cbf2025', 'd3')!;
        expect(d3.isTasted, isTrue);
        expect(
          d3.tastingEvents.single,
          DateTime.fromMillisecondsSinceEpoch(1747526400000),
        );
      });

      test('deletes the legacy keys after migrating', () async {
        final s = await migrated({
          'favorites_cbf2025': ['d1'],
          'ratings_cbf2025_d1': 4,
          'tasting_log_cbf2025|d1': 1747526400000,
        });

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('favorites_cbf2025'), isFalse);
        expect(prefs.containsKey('ratings_cbf2025_d1'), isFalse);
        expect(prefs.containsKey('tasting_log_cbf2025|d1'), isFalse);
        // No leftover v1 blob either.
        expect(prefs.containsKey('user_state_cbf2025_d1'), isFalse);

        final d1 = s.read('cbf2025', 'd1')!;
        expect(d1.wantToTry, isTrue);
        expect(d1.rating, 4); // detail record
        expect(d1.isTasted, isTrue); // from the tasting-log pour
      });

      test('migrates across multiple festivals', () async {
        final s = await migrated({
          'favorites_cbf2025': ['d1'],
          'favorites_cbf2024': ['d9'],
          'ratings_cbf2024_d9': 5,
        });

        expect(s.read('cbf2025', 'd1')!.wantToTry, isTrue);
        expect(s.read('cbf2024', 'd9')!.rating, 5);
      });

      test('sets both completion flags', () async {
        await migrated({});
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(PreferenceKeys.legacyMigrationComplete), isTrue);
        expect(prefs.getBool(PreferenceKeys.logEntryMigrationComplete), isTrue);
      });

      test(
        'merges legacy data onto an existing v1 blob, losing neither',
        () async {
          // A v1 blob already carries a rating; a legacy favourites key adds
          // want-to-try for the same drink. Both must survive the fold.
          final s = await migrated({
            'user_state_cbf2025_d1': jsonEncode(
              UserDrinkState.initial().copyWith(rating: 2).toJson()
                ..['version'] = 1,
            ),
            'favorites_cbf2025': ['d1'],
          });

          final d1 = s.read('cbf2025', 'd1')!;
          expect(d1.rating, 2); // preserved from the pre-existing blob
          expect(d1.wantToTry, isTrue); // folded in from the legacy favourite
        },
      );

      test('malformed legacy keys are skipped without error', () async {
        final s = await migrated({
          'ratings_cbf2025': 4, // no _drinkId segment
          'tasting_log_cbf2025': 1747526400000, // no |drinkId segment
        });
        expect(s.readAll('cbf2025'), isEmpty);
      });
    });

    group('migrateToLogEntries (v1 blob → v2 LogEntry)', () {
      String v1Blob(UserDrinkState state) =>
          jsonEncode(state.toJson()..['version'] = 1);

      test('moves want-to-try into the plan set, no tasting entry', () async {
        SharedPreferences.setMockInitialValues({
          'user_state_cbf2025_d1': v1Blob(
            UserDrinkState.initial().copyWith(wantToTry: true),
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);

        await s.migrateToLogEntries();

        expect(s.readWantToTry('cbf2025'), equals({'d1'}));
        expect(s.readEntries('cbf2025'), isEmpty);
        expect(s.read('cbf2025', 'd1')!.isTasted, isFalse);
        expect(prefs.containsKey('user_state_cbf2025_d1'), isFalse);
      });

      test(
        'carries tasting timestamps to entries at millisecond precision',
        () async {
          final t1 = DateTime(2025, 5, 17, 10, 0);
          final t2 = DateTime(2025, 5, 17, 18, 30);
          SharedPreferences.setMockInitialValues({
            'user_state_cbf2025_d1': v1Blob(
              UserDrinkState.initial().copyWith(tastingEvents: [t2, t1]),
            ),
          });
          final prefs = await SharedPreferences.getInstance();
          final s = SharedPreferencesUserDataStore(prefs);

          await s.migrateToLogEntries();

          final state = s.read('cbf2025', 'd1')!;
          expect(state.tastingEvents, equals([t1, t2]));
          expect(state.tastingCount, 2);
        },
      );

      test(
        'puts rating/notes/photos in the detail record, pours as bare entries',
        () async {
          final t1 = DateTime(2025, 5, 17, 10, 0);
          final t2 = DateTime(2025, 5, 17, 18, 30);
          SharedPreferences.setMockInitialValues({
            'user_state_cbf2025_d1': v1Blob(
              UserDrinkState.initial().copyWith(
                tastingEvents: [t1, t2],
                rating: 5,
                notes: 'great',
                photoIds: const ['p1'],
              ),
            ),
          });
          final prefs = await SharedPreferences.getInstance();
          final s = SharedPreferencesUserDataStore(prefs);

          await s.migrateToLogEntries();

          // Tasting entries are bare pours — rating/notes live in the detail
          // record, not on the timeline.
          final entries = s.readEntries('cbf2025');
          expect(entries, hasLength(2));
          expect(
            entries.every((e) => e.rating == null && e.note == null),
            isTrue,
          );

          final state = s.read('cbf2025', 'd1')!;
          expect(state.rating, 5);
          expect(state.notes, 'great');
          expect(state.photoIds, equals(['p1']));
          expect(state.tastingCount, 2);
        },
      );

      test(
        'a rated-but-never-tasted drink keeps its rating and stays not-tasted',
        () async {
          SharedPreferences.setMockInitialValues({
            'user_state_cbf2025_d1': v1Blob(
              UserDrinkState(
                rating: 4,
                notes: 'from memory',
                createdAt: DateTime(2025, 5, 1),
                updatedAt: DateTime(2025, 5, 20, 12, 0),
              ),
            ),
          });
          final prefs = await SharedPreferences.getInstance();
          final s = SharedPreferencesUserDataStore(prefs);

          await s.migrateToLogEntries();

          // No tasting is fabricated — the rating lives in the detail record.
          expect(s.readEntries('cbf2025'), isEmpty);
          final state = s.read('cbf2025', 'd1')!;
          expect(state.isTasted, isFalse);
          expect(state.tastingCount, 0);
          expect(state.rating, 4);
          expect(state.notes, 'from memory');
        },
      );

      test('a want-to-try-only blob writes no entry', () async {
        SharedPreferences.setMockInitialValues({
          'user_state_cbf2025_d1': v1Blob(
            UserDrinkState.initial().copyWith(wantToTry: true),
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);

        await s.migrateToLogEntries();

        expect(s.readEntries('cbf2025'), isEmpty);
        expect(s.readWantToTry('cbf2025'), equals({'d1'}));
      });

      test(
        'idempotent: re-processing the same blob does not duplicate entries',
        () async {
          final t = DateTime(2025, 5, 17, 10, 0);
          final blob = v1Blob(
            UserDrinkState.initial().copyWith(tastingEvents: [t], rating: 4),
          );
          SharedPreferences.setMockInitialValues({
            'user_state_cbf2025_d1': blob,
          });
          final prefs = await SharedPreferences.getInstance();
          final s = SharedPreferencesUserDataStore(prefs);

          await s.migrateToLogEntries();
          final first = s.readEntries('cbf2025');
          expect(first, hasLength(1));

          // Simulate a crash after entries were written but before the blob
          // delete / completion flag persisted: restore the blob, clear the
          // flag, and re-run. Deterministic ids overwrite, never duplicate.
          await prefs.setString('user_state_cbf2025_d1', blob);
          await prefs.setBool(PreferenceKeys.logEntryMigrationComplete, false);
          await s.migrateToLogEntries();

          final second = s.readEntries('cbf2025');
          expect(second, hasLength(1));
          expect(second.single.id, first.single.id);
          // The detail record (deterministic per-drink key) also survives
          // re-processing without duplication.
          expect(s.read('cbf2025', 'd1')!.rating, 4);
        },
      );

      test('resumes a partial migration without touching done work', () async {
        // d1 was migrated in a prior (crashed) run: its blob is gone and an
        // entry already exists. d2 still has its blob. The flag is unset.
        final t = DateTime(2025, 5, 17, 10, 0);
        SharedPreferences.setMockInitialValues({
          'log_entry_cbf2025_already-migrated': jsonEncode(
            LogEntry(id: 'already-migrated', when: t, drinkId: 'd1').toJson()
              ..['version'] = 2,
          ),
          'user_state_cbf2025_d2': v1Blob(
            UserDrinkState.initial().copyWith(tastingEvents: [t]),
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);

        await s.migrateToLogEntries();

        // d1's pre-existing entry is untouched; d2 got migrated.
        expect(s.read('cbf2025', 'd1')!.isTasted, isTrue);
        expect(s.read('cbf2025', 'd2')!.isTasted, isTrue);
        expect(
          s.readEntries('cbf2025').where((e) => e.drinkId == 'd1'),
          hasLength(1),
        );
        expect(prefs.containsKey('user_state_cbf2025_d2'), isFalse);
      });

      test('quarantines a corrupt blob rather than crashing', () async {
        SharedPreferences.setMockInitialValues({
          'user_state_cbf2025_d1': 'not valid json',
        });
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);

        await s.migrateToLogEntries();

        // Left on disk, not migrated, no entries produced.
        expect(prefs.containsKey('user_state_cbf2025_d1'), isTrue);
        expect(s.readEntries('cbf2025'), isEmpty);
        expect(prefs.getBool(PreferenceKeys.logEntryMigrationComplete), isTrue);
      });

      test('is a no-op after completion (flag short-circuits)', () async {
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.logEntryMigrationComplete: true,
          'user_state_cbf2025_d1': jsonEncode(
            (UserDrinkState.initial().copyWith(wantToTry: true).toJson())
              ..['version'] = 1,
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final s = SharedPreferencesUserDataStore(prefs);

        await s.migrateToLogEntries();

        // The blob is untouched because the migration already ran.
        expect(prefs.containsKey('user_state_cbf2025_d1'), isTrue);
        expect(s.readWantToTry('cbf2025'), isEmpty);
      });
    });
  });
}
