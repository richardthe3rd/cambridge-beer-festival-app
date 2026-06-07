import 'package:cambridge_beer_festival/domain/controllers/controllers.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Festival createSampleFestival({
  String id = 'cbf2025',
  String name = 'Test Festival',
  List<String> beverageTypes = const ['beer'],
}) {
  return Festival(
    id: id,
    name: name,
    availableBeverageTypes: beverageTypes,
    dataBaseUrl: 'https://data.example.com/$id',
  );
}

void main() {
  group('FestivalController', () {
    late FestivalController controller;

    setUp(() {
      controller = FestivalController();
    });

    group('initial state', () {
      test('festivals is empty list', () {
        expect(controller.festivals, isEmpty);
      });

      test('hasFestivals is false', () {
        expect(controller.hasFestivals, isFalse);
      });

      test('isFestivalsDataStale is true when no refresh recorded', () {
        expect(controller.isFestivalsDataStale, isTrue);
      });

      test('lastFestivalsRefresh is null', () {
        expect(controller.lastFestivalsRefresh, isNull);
      });

      test('lastFestivalsRefreshAttempt is null', () {
        expect(controller.lastFestivalsRefreshAttempt, isNull);
      });
    });

    group('setSource', () {
      test('sets festivals list', () {
        final festivals = [
          createSampleFestival(id: 'cbf2025'),
          createSampleFestival(id: 'cbf2024'),
        ];
        controller.setSource(festivals, defaultFestival: festivals.first);
        expect(controller.festivals, hasLength(2));
        expect(
          controller.festivals.map((f) => f.id),
          containsAll(['cbf2025', 'cbf2024']),
        );
      });

      test(
        'sets currentFestival to defaultFestival when none previously selected',
        () {
          final festivals = [createSampleFestival(id: 'cbf2025')];
          final defaultFestival = festivals.first;
          controller.setSource(festivals, defaultFestival: defaultFestival);
          expect(controller.currentFestival.id, equals('cbf2025'));
        },
      );

      test(
        'does not overwrite existing currentFestival with defaultFestival',
        () {
          final first = createSampleFestival(id: 'cbf2025');
          final second = createSampleFestival(id: 'cbf2024');
          // set source, select second explicitly, then refresh with first as default
          controller
            ..setSource([first, second], defaultFestival: first)
            ..selectFestival(second)
            ..setSource([first, second], defaultFestival: first);
          // should keep cbf2024 because it was explicitly selected
          expect(controller.currentFestival.id, equals('cbf2024'));
        },
      );

      test('re-points currentFestival to refreshed object when id matches', () {
        final original = createSampleFestival(
          id: 'cbf2025',
          beverageTypes: ['beer'],
        );
        controller
          ..setSource([original], defaultFestival: original)
          ..selectFestival(original);

        final refreshed = createSampleFestival(
          id: 'cbf2025',
          beverageTypes: ['beer', 'cider'],
        );
        controller.setSource([refreshed], defaultFestival: refreshed);

        // The current festival should now be the refreshed object
        expect(
          controller.currentFestival.availableBeverageTypes,
          containsAll(['beer', 'cider']),
        );
      });

      test(
        'returns true (beverageTypesChanged) when beverage types differ',
        () {
          final original = createSampleFestival(
            id: 'cbf2025',
            beverageTypes: ['beer'],
          );
          controller
            ..setSource([original], defaultFestival: original)
            ..selectFestival(original);

          final refreshed = createSampleFestival(
            id: 'cbf2025',
            beverageTypes: ['beer', 'cider'],
          );
          final changed = controller.setSource([
            refreshed,
          ], defaultFestival: refreshed);
          expect(changed, isTrue);
        },
      );

      test('returns false when beverage types unchanged', () {
        final original = createSampleFestival(
          id: 'cbf2025',
          beverageTypes: ['beer'],
        );
        controller
          ..setSource([original], defaultFestival: original)
          ..selectFestival(original);

        final refreshed = createSampleFestival(
          id: 'cbf2025',
          beverageTypes: ['beer'],
        );
        final changed = controller.setSource([
          refreshed,
        ], defaultFestival: refreshed);
        expect(changed, isFalse);
      });

      test('sets lastFestivalsRefresh to non-null after call', () {
        final festivals = [createSampleFestival()];
        controller.setSource(festivals, defaultFestival: festivals.first);
        expect(controller.lastFestivalsRefresh, isNotNull);
      });
    });

    group('selectFestival', () {
      test('sets currentFestival', () {
        final festival = createSampleFestival(id: 'cbf2025');
        controller
          ..setSource([festival], defaultFestival: festival)
          ..selectFestival(festival);
        expect(controller.currentFestival.id, equals('cbf2025'));
      });

      test('overrides previous selection', () {
        final first = createSampleFestival(id: 'cbf2025');
        final second = createSampleFestival(id: 'cbf2024');
        controller
          ..setSource([first, second], defaultFestival: first)
          ..selectFestival(first);
        expect(controller.currentFestival.id, equals('cbf2025'));

        controller.selectFestival(second);
        expect(controller.currentFestival.id, equals('cbf2024'));
      });
    });

    group('restoreSelection', () {
      test('sets currentFestival to matching festival in list', () {
        final f1 = createSampleFestival(id: 'cbf2025');
        final f2 = createSampleFestival(id: 'cbf2024');
        controller
          ..setSource([f1, f2], defaultFestival: f1)
          ..restoreSelection('cbf2024');
        expect(controller.currentFestival.id, equals('cbf2024'));
      });

      test('no-op when savedId not in list (no exception)', () {
        final f = createSampleFestival(id: 'cbf2025');
        controller.setSource([f], defaultFestival: f);
        expect(
          () => controller.restoreSelection('nonexistent'),
          returnsNormally,
        );
      });

      test('no-op when savedId is null (no exception)', () {
        final f = createSampleFestival(id: 'cbf2025');
        controller.setSource([f], defaultFestival: f);
        expect(() => controller.restoreSelection(null), returnsNormally);
      });
    });

    group('applyFallback', () {
      test('sets currentFestival when not yet selected', () {
        final f = createSampleFestival(id: 'cbf2025');
        controller
          ..setSource([f])
          ..applyFallback(defaultFestival: f);
        expect(controller.currentFestival.id, equals('cbf2025'));
      });

      test('no-op when currentFestival already set', () {
        final first = createSampleFestival(id: 'cbf2025');
        final second = createSampleFestival(id: 'cbf2024');
        controller
          ..setSource([first, second], defaultFestival: first)
          ..selectFestival(first)
          // try to apply second as fallback — should not change
          ..applyFallback(defaultFestival: second);
        expect(controller.currentFestival.id, equals('cbf2025'));
      });

      test('no-op when defaultFestival is null', () {
        // No festivals set, no current selection — apply null fallback
        expect(
          () => controller.applyFallback(defaultFestival: null),
          returnsNormally,
        );
      });
    });

    group('isFestivalsDataStale', () {
      test('false immediately after setSource', () {
        final f = createSampleFestival();
        controller.setSource([f]);
        expect(controller.isFestivalsDataStale, isFalse);
      });

      test(
        'true when lastFestivalsRefresh is forced to >24h ago via @visibleForTesting setter',
        () {
          final f = createSampleFestival();
          // Set source then force the timestamp to be 25 hours ago
          controller
            ..setSource([f])
            ..lastFestivalsRefresh = DateTime.now().subtract(
              const Duration(hours: 25),
            );
          expect(controller.isFestivalsDataStale, isTrue);
        },
      );
    });

    group('isValidFestivalId', () {
      setUp(() {
        final festivals = [
          createSampleFestival(id: 'cbf2025'),
          createSampleFestival(id: 'cbf2024'),
        ];
        controller.setSource(festivals, defaultFestival: festivals.first);
      });

      test('true for id in list', () {
        expect(controller.isValidFestivalId('cbf2025'), isTrue);
      });

      test('false for id not in list', () {
        expect(controller.isValidFestivalId('cbf2099'), isFalse);
      });

      test('false for null', () {
        expect(controller.isValidFestivalId(null), isFalse);
      });

      test('false for empty string', () {
        expect(controller.isValidFestivalId(''), isFalse);
      });
    });

    group('getFestivalById', () {
      test('returns festival when found', () {
        final f = createSampleFestival(id: 'cbf2025');
        controller.setSource([f], defaultFestival: f);
        final found = controller.getFestivalById('cbf2025');
        expect(found, isNotNull);
        expect(found!.id, equals('cbf2025'));
      });

      test('returns null when not found', () {
        final f = createSampleFestival(id: 'cbf2025');
        controller.setSource([f], defaultFestival: f);
        expect(controller.getFestivalById('cbf9999'), isNull);
      });
    });

    group('clearFestivals', () {
      test('empties festival list', () {
        final f = createSampleFestival();
        controller.setSource([f], defaultFestival: f);
        expect(controller.festivals, isNotEmpty);
        controller.clearFestivals();
        expect(controller.festivals, isEmpty);
      });
    });

    group('recordAttempt', () {
      test('sets lastFestivalsRefreshAttempt to non-null and recent', () {
        expect(controller.lastFestivalsRefreshAttempt, isNull);
        controller.recordAttempt();
        expect(controller.lastFestivalsRefreshAttempt, isNotNull);
        final diff = DateTime.now().difference(
          controller.lastFestivalsRefreshAttempt!,
        );
        expect(diff.inSeconds, lessThan(5));
      });
    });

    group('sortedFestivals', () {
      test('returns festivals in date order', () {
        final past = Festival(
          id: 'cbf2024',
          name: 'Festival 2024',
          startDate: DateTime(2024, 5, 20),
          endDate: DateTime(2024, 5, 25),
          availableBeverageTypes: const ['beer'],
          dataBaseUrl: 'https://data.example.com/cbf2024',
        );
        final upcoming = Festival(
          id: 'cbf2026',
          name: 'Festival 2026',
          startDate: DateTime(2026, 5, 18),
          endDate: DateTime(2026, 5, 23),
          availableBeverageTypes: const ['beer'],
          dataBaseUrl: 'https://data.example.com/cbf2026',
        );
        controller.setSource([past, upcoming], defaultFestival: upcoming);
        final sorted = controller.sortedFestivals;
        // upcoming (2026) should come before past (2024)
        expect(sorted.first.id, equals('cbf2026'));
        expect(sorted.last.id, equals('cbf2024'));
      });
    });
  });
}
