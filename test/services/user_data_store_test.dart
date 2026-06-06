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
  });
}
