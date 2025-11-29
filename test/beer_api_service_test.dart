import 'dart:async';
import 'dart:convert';
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

    group('fetchDrinks', () {
      test('parses drinks correctly from API response', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
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
                }
              ],
            },
          ],
        });

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        final drinks = await service.fetchDrinks(festival, 'beer');

        expect(drinks.length, 1);
        expect(drinks.first.name, 'Test IPA');
        expect(drinks.first.breweryName, 'Test Brewery');
        expect(drinks.first.abv, 5.5);
      });

      test('parses multiple producers and products', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
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
                {'id': 'drink-1', 'name': 'Beer 1', 'category': 'beer', 'dispense': 'cask', 'abv': '4.0'},
                {'id': 'drink-2', 'name': 'Beer 2', 'category': 'beer', 'dispense': 'cask', 'abv': '5.0'},
              ],
            },
            {
              'id': 'brewery-2',
              'name': 'Brewery Two',
              'location': 'London',
              'products': [
                {'id': 'drink-3', 'name': 'Beer 3', 'category': 'beer', 'dispense': 'keg', 'abv': '6.0'},
              ],
            },
          ],
        });

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        final drinks = await service.fetchDrinks(festival, 'beer');

        expect(drinks.length, 3);
        expect(drinks[0].breweryName, 'Brewery One');
        expect(drinks[1].breweryName, 'Brewery One');
        expect(drinks[2].breweryName, 'Brewery Two');
      });

      test('returns empty list for 404 response', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['mead'],
        );

        when(mockClient.get(Uri.parse('https://example.com/mead.json')))
            .thenAnswer((_) async => http.Response('Not found', 404));

        final drinks = await service.fetchDrinks(festival, 'mead');

        expect(drinks, isEmpty);
      });

      test('throws BeerApiException for server error', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response('Server error', 500));

        expect(
          () => service.fetchDrinks(festival, 'beer'),
          throwsA(isA<BeerApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          )),
        );
      });

      test('handles empty producers list', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({'producers': []});

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        final drinks = await service.fetchDrinks(festival, 'beer');

        expect(drinks, isEmpty);
      });

      test('handles missing producers key', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        final responseBody = json.encode({});

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        final drinks = await service.fetchDrinks(festival, 'beer');

        expect(drinks, isEmpty);
      });

      test('sets correct festivalId on drinks', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
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
                {'id': 'drink-1', 'name': 'Beer', 'category': 'beer', 'dispense': 'cask', 'abv': '4.0'},
              ],
            },
          ],
        });

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        final drinks = await service.fetchDrinks(festival, 'beer');

        expect(drinks.first.festivalId, 'my-festival-id');
      });
    });

    group('fetchAllDrinks', () {
      test('fetches all beverage types', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
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
                {'id': 'beer-1', 'name': 'Test Beer', 'category': 'beer', 'dispense': 'cask', 'abv': '4.0'},
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
                {'id': 'cider-1', 'name': 'Test Cider', 'category': 'cider', 'dispense': 'bag in box', 'abv': '5.0'},
              ],
            },
          ],
        });

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(beerResponse, 200));
        when(mockClient.get(Uri.parse('https://example.com/cider.json')))
            .thenAnswer((_) async => http.Response(ciderResponse, 200));

        final drinks = await service.fetchAllDrinks(festival);

        expect(drinks.length, 2);
        expect(drinks.any((d) => d.category == 'beer'), isTrue);
        expect(drinks.any((d) => d.category == 'cider'), isTrue);
      });

      test('continues loading when one beverage type fails', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
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
                {'id': 'beer-1', 'name': 'Test Beer', 'category': 'beer', 'dispense': 'cask', 'abv': '4.0'},
              ],
            },
          ],
        });

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response(beerResponse, 200));
        when(mockClient.get(Uri.parse('https://example.com/mead.json')))
            .thenAnswer((_) async => http.Response('Not found', 404));

        final drinks = await service.fetchAllDrinks(festival);

        // Should still have beer even though mead failed
        expect(drinks.length, 1);
        expect(drinks.first.category, 'beer');
      });

      test('throws exception when all beverage types fail', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer', 'cider'],
        );

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenThrow(Exception('Network error'));
        when(mockClient.get(Uri.parse('https://example.com/cider.json')))
            .thenThrow(Exception('Network error'));

        expect(
          () => service.fetchAllDrinks(festival),
          throwsA(isA<BeerApiException>()),
        );
      });

      test('returns empty list without error when all types return 404', () async {
        service = BeerApiService(client: mockClient);

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) async => http.Response('Not found', 404));

        final drinks = await service.fetchAllDrinks(festival);

        // 404s return empty list, not errors, so no exception should be thrown
        expect(drinks, isEmpty);
      });
    });

    group('timeout', () {
      test('throws TimeoutException when request times out', () async {
        service = BeerApiService(
          client: mockClient,
          timeout: const Duration(milliseconds: 50),
        );

        final festival = Festival(
          id: 'cbf2025',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: ['beer'],
        );

        when(mockClient.get(Uri.parse('https://example.com/beer.json')))
            .thenAnswer((_) => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => http.Response('{}', 200),
                ));

        expect(
          () => service.fetchDrinks(festival, 'beer'),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
  });
}
