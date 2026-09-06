import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'services_test.mocks.dart';

void main() {
  group('BeerApiService', () {
    late MockClient mockClient;
    late BeerApiService service;

    setUp(() {
      mockClient = MockClient();
    });

    tearDown(() {
      service.dispose();
    });

    group('fetchDrinksByType (single type)', () {
      test('parses drinks correctly from API response', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Test Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'drink-1',
                  'name': 'Test IPA',
                  'category': 'beer',
                  'style': 'IPA',
                  'dispense': 'cask',
                  'abv': '5.5',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);
        final drinks = result.drinksByType['beer']!;

        expect(drinks.length, 1);
        expect(drinks.first.name, 'Test IPA');
        expect(drinks.first.breweryName, 'Test Brewery');
        expect(drinks.first.abv, 5.5);
      });

      test('parses multiple producers and products', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Brewery One',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'drink-1',
                  'name': 'Beer 1',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
                {
                  'id': 'drink-2',
                  'name': 'Beer 2',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '5.0',
                },
              ],
            },
            {
              'id': 'brewery-2',
              'name': 'Brewery Two',
              'location': 'London',
              'products': [
                {
                  'id': 'drink-3',
                  'name': 'Beer 3',
                  'category': 'beer',
                  'dispense': 'keg',
                  'abv': '6.0',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);
        final drinks = result.drinksByType['beer']!;

        expect(drinks.length, 3);
        expect(drinks[0].breweryName, 'Brewery One');
        expect(drinks[1].breweryName, 'Brewery One');
        expect(drinks[2].breweryName, 'Brewery Two');
      });

      test('treats a 404 response as a soft omission, not an error', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['mead'],
        );

        when(
          mockClient.get(Uri.parse('https://example.com/mead.json')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final result = await service.fetchDrinksByType(festival);

        expect(result.drinksByType, isEmpty);
        expect(result.failedTypes, isEmpty);
      });

      test('captures a server error as a failed type', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response('Server error', 500));

        final result = await service.fetchDrinksByType(festival);

        expect(
          result.failedTypes['beer'],
          isA<BeerApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        );
      });

      test('handles empty producers list', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': <Map<String, dynamic>>[],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);

        expect(result.drinksByType['beer'], isEmpty);
      });

      test('handles missing producers key', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({});

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);

        expect(result.drinksByType['beer'], isEmpty);
      });

      test('sets correct festivalId on drinks', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'my-festival-id',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Test Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'drink-1',
                  'name': 'Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);

        expect(result.drinksByType['beer']!.first.festivalId, 'my-festival-id');
      });

      test('skips products with missing ids', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Test Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': null,
                  'name': 'No Id Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
                {
                  'id': 'drink-2',
                  'name': 'Valid Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.5',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);
        final drinks = result.drinksByType['beer']!;

        expect(drinks.length, 1);
        expect(drinks.first.id, 'drink-2');
      });

      test('skips producers with missing ids', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({
          'producers': [
            {
              'id': null,
              'name': 'Missing Id Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'drink-ignored',
                  'name': 'Ignored Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
              ],
            },
            {
              'id': 'brewery-2',
              'name': 'Valid Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'drink-2',
                  'name': 'Valid Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.5',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await service.fetchDrinksByType(festival);
        final drinks = result.drinksByType['beer']!;

        expect(drinks.length, 1);
        expect(drinks.first.id, 'drink-2');
        expect(drinks.first.producer.id, 'brewery-2');
      });
    });

    group('fetchDrinksByType (multiple types)', () {
      test('fetches all beverage types', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer', 'cider'],
        );

        final beerResponse = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Beer Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'beer-1',
                  'name': 'Test Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
              ],
            },
          ],
        });

        final ciderResponse = json.encode({
          'producers': [
            {
              'id': 'cidery-1',
              'name': 'Cider Mill',
              'location': 'Somerset',
              'products': [
                {
                  'id': 'cider-1',
                  'name': 'Test Cider',
                  'category': 'cider',
                  'dispense': 'bag in box',
                  'abv': '5.0',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(beerResponse, 200));
        when(
          mockClient.get(Uri.parse('https://example.com/cider.json')),
        ).thenAnswer((_) async => http.Response(ciderResponse, 200));

        final result = await service.fetchDrinksByType(festival);
        final drinks = [for (final list in result.drinksByType.values) ...list];

        expect(drinks.length, 2);
        expect(drinks.any((d) => d.category == 'beer'), isTrue);
        expect(drinks.any((d) => d.category == 'cider'), isTrue);
      });

      test('continues loading other types when one 404s', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer', 'mead'],
        );

        final beerResponse = json.encode({
          'producers': [
            {
              'id': 'brewery-1',
              'name': 'Beer Brewery',
              'location': 'Cambridge',
              'products': [
                {
                  'id': 'beer-1',
                  'name': 'Test Beer',
                  'category': 'beer',
                  'dispense': 'cask',
                  'abv': '4.0',
                },
              ],
            },
          ],
        });

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response(beerResponse, 200));
        when(
          mockClient.get(Uri.parse('https://example.com/mead.json')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final result = await service.fetchDrinksByType(festival);

        // Should still have beer even though mead 404s (a soft omission).
        expect(result.drinksByType.keys, ['beer']);
        expect(result.drinksByType['beer']!.length, 1);
        expect(result.drinksByType['beer']!.first.category, 'beer');
        expect(result.failedTypes, isEmpty);
      });

      test(
        'reports isCompleteFailure when every beverage type errors',
        () async {
          service = BeerApiService(client: mockClient);

          const festival = Festival(
            id: 'cbf2025',
            name: 'Test Festival',
            dataBaseUrl: 'https://example.com',
            availableBeverageTypes: ['beer', 'cider'],
          );

          when(
            mockClient.get(Uri.parse('https://example.com/beer.json')),
          ).thenThrow(Exception('Network error'));
          when(
            mockClient.get(Uri.parse('https://example.com/cider.json')),
          ).thenThrow(Exception('Network error'));

          final result = await service.fetchDrinksByType(festival);

          expect(result.isCompleteFailure, isTrue);
          expect(
            result.throwIfCompleteFailure,
            throwsA(isA<BeerApiException>()),
          );
        },
      );

      test('is not a complete failure when every type merely 404s', () async {
        service = BeerApiService(client: mockClient);

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final result = await service.fetchDrinksByType(festival);

        // 404s are a soft omission, not an error, so no exception should
        // be thrown even though nothing was fetched.
        expect(result.drinksByType, isEmpty);
        expect(result.isCompleteFailure, isFalse);
        expect(result.throwIfCompleteFailure, returnsNormally);
      });
    });

    group('timeout', () {
      test('captures a TimeoutException as a failed type', () async {
        service = BeerApiService(
          client: mockClient,
          timeout: const Duration(milliseconds: 50),
        );

        const festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(
          mockClient.get(Uri.parse('https://example.com/beer.json')),
        ).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 100),
            () => http.Response('{}', 200),
          ),
        );

        final result = await service.fetchDrinksByType(festival);

        expect(result.failedTypes['beer'], isA<TimeoutException>());
      });
    });
  });

  group('isConnectivityFailure', () {
    // isConnectivityFailure is a top-level function; no service instantiation needed.

    test('returns true for SocketException', () {
      expect(isConnectivityFailure(const SocketException('no route')), isTrue);
    });

    test('returns true for HandshakeException', () {
      expect(
        isConnectivityFailure(const HandshakeException('handshake failed')),
        isTrue,
      );
    });

    test('returns true for HttpException', () {
      expect(
        isConnectivityFailure(const HttpException('connection refused')),
        isTrue,
      );
    });

    test('returns true for TimeoutException', () {
      expect(isConnectivityFailure(TimeoutException('timed out')), isTrue);
    });

    test('returns true for http.ClientException', () {
      expect(
        isConnectivityFailure(http.ClientException('client error')),
        isTrue,
      );
    });

    test('returns false for generic Exception', () {
      expect(isConnectivityFailure(Exception('random')), isFalse);
    });

    test('returns false for FormatException', () {
      expect(isConnectivityFailure(const FormatException()), isFalse);
    });

    test('returns true for TlsException', () {
      expect(isConnectivityFailure(const TlsException('cert error')), isTrue);
    });

    test('returns true for CertificateException', () {
      expect(
        isConnectivityFailure(const CertificateException('bad cert')),
        isTrue,
      );
    });
  });

  // parseProducers walks a whole category in one pass, so anything that can
  // throw inside the loop takes every drink with it — the user sees an empty
  // list, not one missing beer. These pin the blast radius at one record.
  group('parseProducers blast radius', () {
    Map<String, dynamic> producer(String id, List<dynamic> products) =>
        <String, dynamic>{
          'id': id,
          'name': 'Brewery $id',
          'products': products,
        };

    Map<String, dynamic> product(String id) => <String, dynamic>{
      'id': id,
      'name': 'Drink $id',
      'category': 'beer',
      'abv': '4.5',
      'dispense': 'cask',
    };

    test('an odd product type does not empty the category', () {
      final drinks = BeerApiService.parseProducers(<String, dynamic>{
        'producers': <dynamic>[
          producer('a', <dynamic>[
            product('good-1'),
            <String, dynamic>{
              // Upstream serves the id as a number one day.
              'id': 999,
              'name': 'Odd Ale',
              'category': 'beer',
              'abv': '5.0',
              'dispense': 'cask',
            },
          ]),
          producer('b', <dynamic>[product('good-2')]),
        ],
      }, 'cbf2026');

      expect(drinks.map((d) => d.id), ['good-1', '999', 'good-2']);
    });

    test('a producer that is not an object is skipped, the rest survive', () {
      final drinks = BeerApiService.parseProducers(<String, dynamic>{
        'producers': <dynamic>[
          producer('a', <dynamic>[product('good-1')]),
          'not an object',
          42,
          producer('b', <dynamic>[product('good-2')]),
        ],
      }, 'cbf2026');

      expect(drinks.map((d) => d.id), ['good-1', 'good-2']);
    });

    test('a producers value that is not a list yields no drinks', () {
      expect(
        BeerApiService.parseProducers(<String, dynamic>{
          'producers': <String, dynamic>{'unexpected': 'shape'},
        }, 'cbf2026'),
        isEmpty,
      );
      expect(
        BeerApiService.parseProducers(<String, dynamic>{}, 'cbf2026'),
        isEmpty,
      );
    });
  });
}
