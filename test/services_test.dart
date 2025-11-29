import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('BeerApiException', () {
    test('creates exception with message only', () {
      const exception = BeerApiException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.statusCode, isNull);
    });

    test('creates exception with message and status code', () {
      const exception = BeerApiException('Not found', 404);

      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
    });

    test('toString returns formatted message', () {
      const exception = BeerApiException('Server error', 500);

      expect(exception.toString(), 'BeerApiException: Server error');
    });
  });

  group('FestivalServiceException', () {
    test('creates exception with message only', () {
      const exception = FestivalServiceException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.statusCode, isNull);
    });

    test('creates exception with message and status code', () {
      const exception = FestivalServiceException('Not found', 404);

      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
    });

    test('toString returns formatted message', () {
      const exception = FestivalServiceException('Server error', 500);

      expect(exception.toString(), 'FestivalServiceException: Server error');
    });
  });

  group('FestivalsResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
            'is_active': true,
          },
          {
            'id': 'cbfw2025',
            'name': 'Cambridge Winter Beer Festival 2025',
            'data_base_url': 'https://example.com/cbfw2025',
            'is_active': false,
          },
        ],
        'default_festival_id': 'cbf2025',
        'version': '1.0.0',
        'last_updated': '2025-01-15T12:00:00.000Z',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.festivals.length, 2);
      expect(response.defaultFestivalId, 'cbf2025');
      expect(response.version, '1.0.0');
      expect(response.lastUpdated, isNotNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'festivals': [
          {
            'id': 'test',
            'name': 'Test Festival',
            'data_base_url': 'https://example.com/test',
          },
        ],
        'default_festival_id': 'test',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.festivals.length, 1);
      expect(response.version, '1.0.0');
      expect(response.lastUpdated, isNull);
    });

    test('defaultFestival returns correct festival', () {
      final json = {
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
          },
          {
            'id': 'cbfw2025',
            'name': 'Cambridge Winter Beer Festival 2025',
            'data_base_url': 'https://example.com/cbfw2025',
          },
        ],
        'default_festival_id': 'cbfw2025',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.defaultFestival, isNotNull);
      expect(response.defaultFestival!.id, 'cbfw2025');
    });

    test('defaultFestival returns first festival when default not found', () {
      final json = {
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
          },
        ],
        'default_festival_id': 'nonexistent',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.defaultFestival, isNotNull);
      expect(response.defaultFestival!.id, 'cbf2025');
    });

    test('defaultFestival returns null when festivals list is empty', () {
      final json = {
        'festivals': <Map<String, dynamic>>[],
        'default_festival_id': 'cbf2025',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.defaultFestival, isNull);
    });

    test('activeFestivals returns only active festivals', () {
      final json = {
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
            'is_active': true,
          },
          {
            'id': 'cbfw2025',
            'name': 'Cambridge Winter Beer Festival 2025',
            'data_base_url': 'https://example.com/cbfw2025',
            'is_active': false,
          },
          {
            'id': 'cbf2026',
            'name': 'Cambridge Beer Festival 2026',
            'data_base_url': 'https://example.com/cbf2026',
            'is_active': true,
          },
        ],
        'default_festival_id': 'cbf2025',
      };

      final response = FestivalsResponse.fromJson(json);
      final activeFestivals = response.activeFestivals;

      expect(activeFestivals.length, 2);
      expect(activeFestivals.map((f) => f.id), contains('cbf2025'));
      expect(activeFestivals.map((f) => f.id), contains('cbf2026'));
      expect(activeFestivals.map((f) => f.id), isNot(contains('cbfw2025')));
    });

    test('activeFestivals returns empty list when none are active', () {
      final json = {
        'festivals': [
          {
            'id': 'cbf2024',
            'name': 'Cambridge Beer Festival 2024',
            'data_base_url': 'https://example.com/cbf2024',
            'is_active': false,
          },
        ],
        'default_festival_id': 'cbf2024',
      };

      final response = FestivalsResponse.fromJson(json);

      expect(response.activeFestivals, isEmpty);
    });
  });

  group('BeerApiService', () {
    test('can be instantiated without client', () {
      final service = BeerApiService();
      expect(service, isNotNull);
      service.dispose();
    });
  });

  group('FestivalService', () {
    test('can be instantiated without client', () {
      final service = FestivalService();
      expect(service, isNotNull);
      service.dispose();
    });
  });
}
