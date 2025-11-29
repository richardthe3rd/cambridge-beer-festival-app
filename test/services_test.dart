import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'services_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('BeerApiException', () {
    test('creates exception with message only', () {
      final exception = BeerApiException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.statusCode, isNull);
    });

    test('creates exception with message and status code', () {
      final exception = BeerApiException('Not found', 404);

      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
    });

    test('toString returns formatted message', () {
      final exception = BeerApiException('Server error', 500);

      expect(exception.toString(), 'BeerApiException: Server error');
    });
  });

  group('FestivalServiceException', () {
    test('creates exception with message only', () {
      final exception = FestivalServiceException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.statusCode, isNull);
    });

    test('creates exception with message and status code', () {
      final exception = FestivalServiceException('Not found', 404);

      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
    });

    test('toString returns formatted message', () {
      final exception = FestivalServiceException('Server error', 500);

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

    test('has default timeout of 30 seconds', () {
      final service = BeerApiService();
      expect(service.timeout, const Duration(seconds: 30));
      service.dispose();
    });

    test('accepts custom timeout', () {
      final customTimeout = const Duration(seconds: 10);
      final service = BeerApiService(timeout: customTimeout);
      expect(service.timeout, customTimeout);
      service.dispose();
    });

    test('timeout is enforced on HTTP requests', () async {
      final mockClient = MockClient();
      final service = BeerApiService(
        client: mockClient,
        timeout: const Duration(milliseconds: 100),
      );

      // Create a mock festival for testing
      final festival = Festival(
        id: 'test',
        name: 'Test Festival',
        dataBaseUrl: 'https://example.com',
        availableBeverageTypes: ['beer'],
      );

      // Mock a delayed response that exceeds the timeout
      when(mockClient.get(any)).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 200),
          () => http.Response('{}', 200),
        ),
      );

      // Expect a TimeoutException
      await expectLater(
        service.fetchDrinks(festival, 'beer'),
        throwsA(isA<TimeoutException>()),
      );

      service.dispose();
    });

    test('successful request completes within timeout', () async {
      final mockClient = MockClient();
      final service = BeerApiService(
        client: mockClient,
        timeout: const Duration(seconds: 5),
      );

      final festival = Festival(
        id: 'test',
        name: 'Test Festival',
        dataBaseUrl: 'https://example.com',
        availableBeverageTypes: ['beer'],
      );

      // Mock a quick successful response
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response('{"producers": []}', 200),
      );

      // Should complete successfully
      final result = await service.fetchDrinks(festival, 'beer');
      expect(result, isA<List<Drink>>());

      service.dispose();
    });
  });

  group('FestivalService', () {
    test('can be instantiated without client', () {
      final service = FestivalService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('has default timeout of 30 seconds', () {
      final service = FestivalService();
      expect(service.timeout, const Duration(seconds: 30));
      service.dispose();
    });

    test('accepts custom timeout', () {
      final customTimeout = const Duration(seconds: 15);
      final service = FestivalService(timeout: customTimeout);
      expect(service.timeout, customTimeout);
      service.dispose();
    });

    test('timeout is enforced on HTTP requests', () async {
      final mockClient = MockClient();
      final service = FestivalService(
        client: mockClient,
        timeout: const Duration(milliseconds: 100),
      );

      // Mock a delayed response that exceeds the timeout
      when(mockClient.get(any)).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 200),
          () => http.Response('{}', 200),
        ),
      );

      // Expect a TimeoutException
      await expectLater(
        service.fetchFestivals(),
        throwsA(isA<TimeoutException>()),
      );

      service.dispose();
    });

    test('successful request completes within timeout', () async {
      final mockClient = MockClient();
      final service = FestivalService(
        client: mockClient,
        timeout: const Duration(seconds: 5),
      );

      // Mock a quick successful response
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(
          '{"festivals": [], "default_festival_id": "test"}',
          200,
        ),
      );

      // Should complete successfully
      final result = await service.fetchFestivals();
      expect(result, isA<FestivalsResponse>());

      service.dispose();
    });
  });
}
