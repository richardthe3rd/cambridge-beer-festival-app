import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/tasting_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TastingLogService', () {
    late TastingLogService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = TastingLogService(prefs);
    });

    test('hasTasted returns false for an untasted drink', () {
      expect(service.hasTasted('cbf2025', 'drink-1'), isFalse);
    });

    test('markAsTasted records a drink as tasted', () async {
      await service.markAsTasted('cbf2025', 'drink-1');

      expect(service.hasTasted('cbf2025', 'drink-1'), isTrue);
    });

    test('unmarkAsTasted clears a tasted drink', () async {
      await service.markAsTasted('cbf2025', 'drink-1');
      await service.unmarkAsTasted('cbf2025', 'drink-1');

      expect(service.hasTasted('cbf2025', 'drink-1'), isFalse);
    });

    test('unmarkAsTasted is a no-op for an untasted drink', () async {
      await service.unmarkAsTasted('cbf2025', 'drink-1');

      expect(service.hasTasted('cbf2025', 'drink-1'), isFalse);
    });

    group('getTastedTimestamp', () {
      test('returns null for an untasted drink', () {
        expect(service.getTastedTimestamp('cbf2025', 'drink-1'), isNull);
      });

      test('returns the time the drink was marked', () async {
        // Stored timestamps are truncated to whole milliseconds, so compare
        // against millisecond bounds rather than the raw DateTime instances.
        final beforeMs = DateTime.now().millisecondsSinceEpoch;
        await service.markAsTasted('cbf2025', 'drink-1');
        final afterMs = DateTime.now().millisecondsSinceEpoch;

        final timestamp = service.getTastedTimestamp('cbf2025', 'drink-1');

        expect(timestamp, isNotNull);
        expect(
          timestamp!.millisecondsSinceEpoch,
          inInclusiveRange(beforeMs, afterMs),
        );
      });
    });

    group('toggleTasted', () {
      test('marks an untasted drink as tasted', () async {
        await service.toggleTasted('cbf2025', 'drink-1');

        expect(service.hasTasted('cbf2025', 'drink-1'), isTrue);
      });

      test('unmarks an already tasted drink', () async {
        await service.markAsTasted('cbf2025', 'drink-1');
        await service.toggleTasted('cbf2025', 'drink-1');

        expect(service.hasTasted('cbf2025', 'drink-1'), isFalse);
      });
    });

    group('getTastedDrinkIds', () {
      test('returns an empty list when nothing is tasted', () {
        expect(service.getTastedDrinkIds('cbf2025'), isEmpty);
      });

      test('returns all tasted drink IDs for a festival', () async {
        await service.markAsTasted('cbf2025', 'drink-1');
        await service.markAsTasted('cbf2025', 'drink-2');

        final ids = service.getTastedDrinkIds('cbf2025');

        expect(ids, hasLength(2));
        expect(ids, containsAll(['drink-1', 'drink-2']));
      });

      test('strips the storage prefix from returned IDs', () async {
        await service.markAsTasted('cbf2025', 'drink-with-dashes-1');

        expect(
          service.getTastedDrinkIds('cbf2025'),
          equals(['drink-with-dashes-1']),
        );
      });
    });

    test('getTastedCount reflects the number of tasted drinks', () async {
      expect(service.getTastedCount('cbf2025'), 0);

      await service.markAsTasted('cbf2025', 'drink-1');
      await service.markAsTasted('cbf2025', 'drink-2');

      expect(service.getTastedCount('cbf2025'), 2);
    });

    test('tasting logs are scoped per festival', () async {
      await service.markAsTasted('cbf2025', 'drink-1');
      await service.markAsTasted('cbf2024', 'drink-2');

      expect(service.hasTasted('cbf2025', 'drink-1'), isTrue);
      expect(service.hasTasted('cbf2025', 'drink-2'), isFalse);
      expect(service.hasTasted('cbf2024', 'drink-2'), isTrue);
      expect(service.getTastedDrinkIds('cbf2025'), equals(['drink-1']));
      expect(service.getTastedDrinkIds('cbf2024'), equals(['drink-2']));
    });

    test('tasting logs isolate festivals with overlapping prefixes', () async {
      await service.markAsTasted('cbf2025', 'drink-1');
      await service.markAsTasted('cbf2025-extra', 'drink-2');

      expect(service.hasTasted('cbf2025', 'drink-1'), isTrue);
      expect(service.hasTasted('cbf2025', 'drink-2'), isFalse);
      expect(service.hasTasted('cbf2025-extra', 'drink-2'), isTrue);
      expect(service.getTastedDrinkIds('cbf2025'), equals(['drink-1']));
      expect(service.getTastedDrinkIds('cbf2025-extra'), equals(['drink-2']));
    });

    group('clearFestivalLog', () {
      test('removes only the targeted festival\'s logs', () async {
        await service.markAsTasted('cbf2025', 'drink-1');
        await service.markAsTasted('cbf2024', 'drink-2');

        await service.clearFestivalLog('cbf2025');

        expect(service.getTastedCount('cbf2025'), 0);
        expect(service.hasTasted('cbf2024', 'drink-2'), isTrue);
      });

      test(
        'does not clear logs from festivals with overlapping prefixes',
        () async {
          await service.markAsTasted('cbf2025', 'drink-1');
          await service.markAsTasted('cbf2025-extra', 'drink-2');

          await service.clearFestivalLog('cbf2025');

          expect(service.getTastedCount('cbf2025'), 0);
          expect(service.hasTasted('cbf2025-extra', 'drink-2'), isTrue);
        },
      );

      test('is a no-op when the festival has no logs', () async {
        await service.clearFestivalLog('cbf2025');

        expect(service.getTastedCount('cbf2025'), 0);
      });
    });

    test('clearAllLogs removes logs across every festival', () async {
      await service.markAsTasted('cbf2025', 'drink-1');
      await service.markAsTasted('cbf2024', 'drink-2');

      await service.clearAllLogs();

      expect(service.getTastedCount('cbf2025'), 0);
      expect(service.getTastedCount('cbf2024'), 0);
    });
  });
}
