import 'package:cambridge_beer_festival/services/festival_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FestivalsResponse.fromJson', () {
    const baseUrl = 'https://example.com';

    Map<String, dynamic> validFestivalJson({String id = 'cbf2025'}) => {
      'id': id,
      'name': 'Cambridge Beer Festival 2025',
      'data_base_url': 'https://data.example.com/$id',
    };

    test('parses a valid response with one festival', () {
      final response = FestivalsResponse.fromJson({
        'festivals': [validFestivalJson()],
        'default_festival_id': 'cbf2025',
      }, baseUrl);

      expect(response.festivals.length, 1);
      expect(response.festivals.single.id, 'cbf2025');
      expect(response.defaultFestivalId, 'cbf2025');
    });

    test(
      'skips a festival entry with a null id and returns the valid ones',
      () {
        final response = FestivalsResponse.fromJson({
          'festivals': [
            validFestivalJson(id: 'cbf2025'),
            {
              'id': null,
              'name': 'Bad Festival',
              'data_base_url': 'https://data.example.com/bad',
            },
            validFestivalJson(id: 'cbf2024'),
          ],
          'default_festival_id': 'cbf2025',
        }, baseUrl);

        expect(response.festivals.length, 2);
        expect(
          response.festivals.map((f) => f.id),
          containsAll(['cbf2025', 'cbf2024']),
        );
      },
    );

    test(
      'skips a festival entry with a missing data_base_url and returns the valid ones',
      () {
        final response = FestivalsResponse.fromJson({
          'festivals': [
            validFestivalJson(id: 'cbf2025'),
            {'id': 'bad', 'name': 'No URL Festival'},
            validFestivalJson(id: 'cbf2024'),
          ],
          'default_festival_id': 'cbf2025',
        }, baseUrl);

        expect(response.festivals.length, 2);
        expect(
          response.festivals.map((f) => f.id),
          containsAll(['cbf2025', 'cbf2024']),
        );
      },
    );

    test(
      'skips a festival entry whose value is not a Map and returns the valid ones',
      () {
        final response = FestivalsResponse.fromJson({
          'festivals': [
            validFestivalJson(id: 'cbf2025'),
            'this is not a map',
            42,
            validFestivalJson(id: 'cbf2024'),
          ],
          'default_festival_id': 'cbf2025',
        }, baseUrl);

        expect(response.festivals.length, 2);
        expect(
          response.festivals.map((f) => f.id),
          containsAll(['cbf2025', 'cbf2024']),
        );
      },
    );

    test('returns an empty festival list when all entries are malformed', () {
      final response = FestivalsResponse.fromJson({
        'festivals': [
          {
            'id': null,
            'name': 'Bad1',
            'data_base_url': 'https://data.example.com/bad',
          },
          {'name': 'Bad2'},
        ],
        'default_festival_id': 'cbf2025',
      }, baseUrl);

      expect(response.festivals, isEmpty);
    });

    test('handles a null or missing "festivals" key without throwing', () {
      final responseWithNull = FestivalsResponse.fromJson({
        'festivals': null,
        'default_festival_id': 'cbf2025',
      }, baseUrl);
      expect(responseWithNull.festivals, isEmpty);

      final responseWithMissing = FestivalsResponse.fromJson({
        'default_festival_id': 'cbf2025',
      }, baseUrl);
      expect(responseWithMissing.festivals, isEmpty);
    });

    test('handles a non-List value for "festivals" key without throwing', () {
      final responseWithMap = FestivalsResponse.fromJson({
        'festivals': {'unexpected': 'map'},
        'default_festival_id': 'cbf2025',
      }, baseUrl);
      expect(responseWithMap.festivals, isEmpty);

      final responseWithString = FestivalsResponse.fromJson({
        'festivals': 'not a list',
        'default_festival_id': 'cbf2025',
      }, baseUrl);
      expect(responseWithString.festivals, isEmpty);
    });
  });
}
