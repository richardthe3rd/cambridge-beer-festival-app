import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FestivalStorageService', () {
    late FestivalStorageService festivalStorageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'getSelectedFestivalId returns null when no festival is selected',
      () async {
        final prefs = await SharedPreferences.getInstance();
        festivalStorageService = FestivalStorageService(prefs);

        final festivalId = festivalStorageService.getSelectedFestivalId();

        expect(festivalId, isNull);
      },
    );

    test('setSelectedFestivalId saves festival ID', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2025');

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, 'cbf2025');
    });

    test('setSelectedFestivalId overwrites previous selection', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2024');
      await festivalStorageService.setSelectedFestivalId('cbf2025');

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, 'cbf2025');
    });

    test('clearSelectedFestival removes saved festival', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2025');
      await festivalStorageService.clearSelectedFestival();

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, isNull);
    });

    test(
      'clearSelectedFestival handles no saved festival gracefully',
      () async {
        final prefs = await SharedPreferences.getInstance();
        festivalStorageService = FestivalStorageService(prefs);

        // Should not throw
        await festivalStorageService.clearSelectedFestival();

        final festivalId = festivalStorageService.getSelectedFestivalId();
        expect(festivalId, isNull);
      },
    );

    test('festival selection persists across service instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final service1 = FestivalStorageService(prefs);

      await service1.setSelectedFestivalId('cbf2025');

      // Create new instance with same prefs
      final service2 = FestivalStorageService(prefs);
      final festivalId = service2.getSelectedFestivalId();

      expect(festivalId, 'cbf2025');
    });
  });
}
