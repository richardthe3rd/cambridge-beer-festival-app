import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';

import 'utf8_encoding_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('BeerApiService UTF-8 Encoding', () {
    late MockClient mockClient;
    late BeerApiService service;
    const testFestival = Festival(
      id: 'test2025',
      name: 'Test Festival',
      dataBaseUrl: 'https://example.com/test2025',
    );

    setUp(() {
      mockClient = MockClient();
      service = BeerApiService(client: mockClient);
    });

    tearDown(() {
      service.dispose();
    });

    test('correctly decodes UTF-8 characters like é in Rosé', () async {
      // Create a JSON response with UTF-8 characters
      final jsonData = {
        'producers': [
          {
            'id': 'cidery1',
            'name': 'Test Cidery',
            'location': 'France',
            'products': [
              {
                'id': 'cider1',
                'name': 'Rosé Cider',
                'abv': 5.5,
                'category': 'cider',
                'dispense': 'keg',
                'style': 'Rosé',
              },
              {
                'id': 'cider2',
                'name': 'Café Apple',
                'abv': 6.0,
                'category': 'cider',
                'dispense': 'keg',
                'style': 'Café',
              },
            ],
          },
        ],
      };

      // Encode as UTF-8 bytes (simulating real API response)
      final utf8Bytes = utf8.encode(json.encode(jsonData));

      // Mock the HTTP response
      when(mockClient.get(any)).thenAnswer((_) async {
        return http.Response.bytes(
          utf8Bytes,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      // Fetch the drinks
      final drinks = await service.fetchDrinks(testFestival, 'cider');

      // Verify we got 2 drinks
      expect(drinks.length, 2);

      // Verify the UTF-8 characters are decoded correctly (not as mojibake)
      final roseDrink = drinks.firstWhere((d) => d.product.id == 'cider1');
      expect(roseDrink.product.name, 'Rosé Cider',
        reason: 'Name should have correct é character');
      expect(roseDrink.product.style, 'Rosé',
        reason: 'Style should have correct é character');
      
      // Verify it's NOT the mojibake version
      expect(roseDrink.product.name, isNot('RosÃ© Cider'),
        reason: 'Should not be garbled as RosÃ©');
      expect(roseDrink.product.style, isNot('RosÃ©'),
        reason: 'Should not be garbled as RosÃ©');

      final cafeDrink = drinks.firstWhere((d) => d.product.id == 'cider2');
      expect(cafeDrink.product.name, 'Café Apple',
        reason: 'Name should have correct é character');
      expect(cafeDrink.product.style, 'Café',
        reason: 'Style should have correct é character');
      
      // Verify it's NOT the mojibake version
      expect(cafeDrink.product.name, isNot('CafÃ© Apple'),
        reason: 'Should not be garbled as CafÃ©');
      expect(cafeDrink.product.style, isNot('CafÃ©'),
        reason: 'Should not be garbled as CafÃ©');
    });

    test('handles various European accented characters correctly', () async {
      // Test with German, Spanish, and French characters
      final jsonData = {
        'producers': [
          {
            'id': 'brewery1',
            'name': 'Test Brewery',
            'location': 'Germany',
            'products': [
              {
                'id': 'beer1',
                'name': 'Kölsch Beer',
                'abv': 4.8,
                'category': 'beer',
                'dispense': 'keg',
                'style': 'Kölsch',
              },
              {
                'id': 'beer2',
                'name': 'Märzen Lager',
                'abv': 5.5,
                'category': 'beer',
                'dispense': 'keg',
                'style': 'Märzen',
              },
              {
                'id': 'beer3',
                'name': 'Niño Porter',
                'abv': 5.0,
                'category': 'beer',
                'dispense': 'cask',
                'style': 'Porter',
              },
            ],
          },
        ],
      };

      final utf8Bytes = utf8.encode(json.encode(jsonData));

      when(mockClient.get(any)).thenAnswer((_) async {
        return http.Response.bytes(
          utf8Bytes,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final drinks = await service.fetchDrinks(testFestival, 'beer');

      expect(drinks.length, 3);

      // Verify German ö character
      final kolsch = drinks.firstWhere((d) => d.product.id == 'beer1');
      expect(kolsch.product.style, 'Kölsch');
      expect(kolsch.product.style?.contains('ö'), true);
      expect(kolsch.product.style, isNot(contains('Ã¶')), // mojibake for ö
        reason: 'Should not be garbled');

      // Verify German ä character
      final marzen = drinks.firstWhere((d) => d.product.id == 'beer2');
      expect(marzen.product.style, 'Märzen');
      expect(marzen.product.style?.contains('ä'), true);
      expect(marzen.product.style, isNot(contains('Ã¤')), // mojibake for ä
        reason: 'Should not be garbled');

      // Verify Spanish ñ character
      final nino = drinks.firstWhere((d) => d.product.id == 'beer3');
      expect(nino.product.name, 'Niño Porter');
      expect(nino.product.name.contains('ñ'), true);
      expect(nino.product.name, isNot(contains('Ã±')), // mojibake for ñ
        reason: 'Should not be garbled');
    });

    test('handles response without explicit charset in Content-Type', () async {
      // Many APIs don't specify charset=utf-8 in Content-Type header
      // Our fix should handle this correctly by using bodyBytes
      final jsonData = {
        'producers': [
          {
            'id': 'producer1',
            'name': 'Café Producer',
            'location': 'France',
            'products': [
              {
                'id': 'product1',
                'name': 'Rosé Wine',
                'abv': 12.5,
                'category': 'wine',
                'dispense': 'bottle',
                'style': 'Rosé',
              },
            ],
          },
        ],
      };

      final utf8Bytes = utf8.encode(json.encode(jsonData));

      // Return response WITHOUT charset in Content-Type
      // This is the problematic case that causes mojibake with response.body
      when(mockClient.get(any)).thenAnswer((_) async {
        return http.Response.bytes(
          utf8Bytes,
          200,
          headers: {'content-type': 'application/json'}, // No charset=utf-8
        );
      });

      final drinks = await service.fetchDrinks(testFestival, 'wine');

      expect(drinks.length, 1);
      
      // Verify the fix works even without explicit charset
      final drink = drinks.first;
      expect(drink.producer.name, 'Café Producer');
      expect(drink.product.style, 'Rosé');
      
      // Verify no mojibake
      expect(drink.producer.name, isNot('CafÃ© Producer'));
      expect(drink.product.style, isNot('RosÃ©'));
    });
  });
}
