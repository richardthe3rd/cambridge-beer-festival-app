import 'dart:convert';

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

    test('read returns null when nothing is stored', () {
      expect(store.read('cbf2025', 'd1'), isNull);
    });

    test('write then read round-trips a record', () async {
      final state = UserDrinkState.initial().copyWith(
        wantToTry: true,
        rating: 4,
        notes: 'Lovely',
      );
      await store.write('cbf2025', 'd1', state);

      final read = store.read('cbf2025', 'd1');
      expect(read, isNotNull);
      expect(read!.wantToTry, isTrue);
      expect(read.rating, 4);
      expect(read.notes, 'Lovely');
    });

    test('writing an empty record removes the entry', () async {
      await store.write(
        'cbf2025',
        'd1',
        UserDrinkState.initial().copyWith(wantToTry: true),
      );
      expect(store.read('cbf2025', 'd1'), isNotNull);

      // An empty record prunes the key rather than persisting noise.
      await store.write('cbf2025', 'd1', UserDrinkState.initial());
      expect(store.read('cbf2025', 'd1'), isNull);
    });

    test('remove deletes a stored record', () async {
      await store.write(
        'cbf2025',
        'd1',
        UserDrinkState.initial().copyWith(rating: 3),
      );
      await store.remove('cbf2025', 'd1');
      expect(store.read('cbf2025', 'd1'), isNull);
    });

    test('records are scoped per festival', () async {
      await store.write(
        'cbf2025',
        'd1',
        UserDrinkState.initial().copyWith(wantToTry: true),
      );

      expect(store.read('cbf2025', 'd1'), isNotNull);
      expect(store.read('cbf2024', 'd1'), isNull);
    });

    group('readAll', () {
      test(
        'returns every stored record for a festival, keyed by drink id',
        () async {
          await store.write(
            'cbf2025',
            'd1',
            UserDrinkState.initial().copyWith(wantToTry: true),
          );
          await store.write(
            'cbf2025',
            'd2',
            UserDrinkState.initial().copyWith(rating: 5),
          );
          // A different festival must not leak in.
          await store.write(
            'cbf2024',
            'd9',
            UserDrinkState.initial().copyWith(wantToTry: true),
          );

          final all = store.readAll('cbf2025');
          expect(all.keys, containsAll(['d1', 'd2']));
          expect(all.keys, isNot(contains('d9')));
          expect(all['d1']!.wantToTry, isTrue);
          expect(all['d2']!.rating, 5);
        },
      );

      test(
        'does not match a festival whose id is a prefix of another',
        () async {
          await store.write(
            'cbf2025x',
            'd1',
            UserDrinkState.initial().copyWith(wantToTry: true),
          );

          expect(store.readAll('cbf2025'), isEmpty);
        },
      );

      test('returns an empty map when the festival has no records', () {
        expect(store.readAll('cbf2025'), isEmpty);
      });
    });

    test('clearFestival removes only that festival\'s records', () async {
      await store.write(
        'cbf2025',
        'd1',
        UserDrinkState.initial().copyWith(wantToTry: true),
      );
      await store.write(
        'cbf2024',
        'd1',
        UserDrinkState.initial().copyWith(wantToTry: true),
      );

      await store.clearFestival('cbf2025');

      expect(store.readAll('cbf2025'), isEmpty);
      expect(store.read('cbf2024', 'd1'), isNotNull);
    });

    test('a corrupt stored entry is treated as absent, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        'user_state_cbf2025_d1': 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final corruptStore = SharedPreferencesUserDataStore(prefs);

      expect(corruptStore.read('cbf2025', 'd1'), isNull);
      expect(corruptStore.readAll('cbf2025'), isEmpty);
    });

    group('schema versioning', () {
      test('write embeds the current schema version in the payload', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final versioned = SharedPreferencesUserDataStore(prefs);

        await versioned.write(
          'cbf2025',
          'd1',
          UserDrinkState.initial().copyWith(rating: 4),
        );

        final raw = prefs.getString('user_state_cbf2025_d1');
        expect(raw, isNotNull);
        final decoded = jsonDecode(raw!) as Map<String, dynamic>;
        expect(
          decoded[SharedPreferencesUserDataStore.schemaKey],
          SharedPreferencesUserDataStore.currentSchemaVersion,
        );
      });

      test(
        'reads a legacy payload that has no version field (treated as v1)',
        () async {
          // The original #391 format wrote no version key.
          final legacy = jsonEncode(
            UserDrinkState.initial().copyWith(wantToTry: true).toJson(),
          );
          SharedPreferences.setMockInitialValues({
            'user_state_cbf2025_d1': legacy,
          });
          final prefs = await SharedPreferences.getInstance();
          final versioned = SharedPreferencesUserDataStore(prefs);

          final read = versioned.read('cbf2025', 'd1');
          expect(read, isNotNull);
          expect(read!.wantToTry, isTrue);
        },
      );
    });

    group('migrateLegacyData', () {
      test(
        'folds favourites, ratings and tasting into unified records',
        () async {
          SharedPreferences.setMockInitialValues({
            'favorites_cbf2025': ['d1', 'd2'],
            'ratings_cbf2025_d2': 3,
            'tasting_log_cbf2025|d3': 1747526400000,
          });
          final prefs = await SharedPreferences.getInstance();
          final migrating = SharedPreferencesUserDataStore(prefs);

          await migrating.migrateLegacyData();

          final d1 = migrating.read('cbf2025', 'd1');
          final d2 = migrating.read('cbf2025', 'd2');
          final d3 = migrating.read('cbf2025', 'd3');
          expect(d1!.wantToTry, isTrue);
          expect(d2!.wantToTry, isTrue);
          expect(d2.rating, 3);
          expect(
            d3!.tastingEvents.single,
            DateTime.fromMillisecondsSinceEpoch(1747526400000),
          );
          expect(d3.isTasted, isTrue);
        },
      );

      test('deletes the legacy keys after migrating', () async {
        SharedPreferences.setMockInitialValues({
          'favorites_cbf2025': ['d1'],
          'ratings_cbf2025_d1': 4,
          'tasting_log_cbf2025|d1': 1747526400000,
        });
        final prefs = await SharedPreferences.getInstance();
        final migrating = SharedPreferencesUserDataStore(prefs);

        await migrating.migrateLegacyData();

        expect(prefs.containsKey('favorites_cbf2025'), isFalse);
        expect(prefs.containsKey('ratings_cbf2025_d1'), isFalse);
        expect(prefs.containsKey('tasting_log_cbf2025|d1'), isFalse);
        // All three legacy facets merged onto one record.
        final d1 = migrating.read('cbf2025', 'd1')!;
        expect(d1.wantToTry, isTrue);
        expect(d1.rating, 4);
        expect(d1.isTasted, isTrue);
      });

      test('migrates across multiple festivals', () async {
        SharedPreferences.setMockInitialValues({
          'favorites_cbf2025': ['d1'],
          'favorites_cbf2024': ['d9'],
          'ratings_cbf2024_d9': 5,
        });
        final prefs = await SharedPreferences.getInstance();
        final migrating = SharedPreferencesUserDataStore(prefs);

        await migrating.migrateLegacyData();

        expect(migrating.read('cbf2025', 'd1')!.wantToTry, isTrue);
        expect(migrating.read('cbf2024', 'd9')!.rating, 5);
      });

      test('is idempotent and a no-op when there is no legacy data', () async {
        SharedPreferences.setMockInitialValues({
          'favorites_cbf2025': ['d1'],
        });
        final prefs = await SharedPreferences.getInstance();
        final migrating = SharedPreferencesUserDataStore(prefs);

        await migrating.migrateLegacyData();
        // Second pass finds no legacy keys and must not duplicate or change state.
        await migrating.migrateLegacyData();

        expect(migrating.read('cbf2025', 'd1')!.wantToTry, isTrue);
        expect(migrating.read('cbf2025', 'd1')!.tastingEvents, isEmpty);
      });

      test('does not overwrite an existing unified record', () async {
        SharedPreferences.setMockInitialValues({
          'favorites_cbf2025': ['d1'],
        });
        final prefs = await SharedPreferences.getInstance();
        final migrating = SharedPreferencesUserDataStore(prefs);
        // A record already exists in the new format with a rating.
        await migrating.write(
          'cbf2025',
          'd1',
          UserDrinkState.initial().copyWith(rating: 2),
        );

        await migrating.migrateLegacyData();

        final d1 = migrating.read('cbf2025', 'd1')!;
        expect(d1.rating, 2); // preserved
        expect(d1.wantToTry, isTrue); // legacy favourite folded in
      });
    });

    group('migrate', () {
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
    });
  });
}
