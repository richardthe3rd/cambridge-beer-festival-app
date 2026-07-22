import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/domain/services/search_match_service.dart';
import 'package:cambridge_beer_festival/models/models.dart';

Drink createDrink({
  String name = 'Alpha Ale',
  String breweryName = 'Test Brewery',
  String? style = 'IPA',
  String? description,
  String? userNote,
}) {
  final now = DateTime(2026, 6, 10);
  return Drink(
    product: Product(
      id: 'drink-a',
      name: name,
      category: 'beer',
      style: style,
      dispense: 'cask',
      abv: 4.2,
      notes: description,
    ),
    producer: Producer(
      id: 'brewery-1',
      name: breweryName,
      location: 'Cambridge',
      products: const [],
    ),
    festivalId: 'cbf2025',
    userState: userNote == null
        ? null
        : UserDrinkState(notes: userNote, createdAt: now, updatedAt: now),
  );
}

void main() {
  const service = SearchMatchService();

  group('matches', () {
    test('matches on name, brewery, style, description and user note', () {
      final drink = createDrink(
        name: 'Alpha Ale',
        breweryName: 'Moonshine Co',
        style: 'Stout',
        description: 'A rich chocolate finish',
        userNote: 'Tom recommended this',
      );

      expect(service.matches(drink, 'alpha'), isTrue); // name
      expect(service.matches(drink, 'moonshine'), isTrue); // brewery
      expect(service.matches(drink, 'stout'), isTrue); // style
      expect(service.matches(drink, 'chocolate'), isTrue); // description
      expect(service.matches(drink, 'tom'), isTrue); // user note
    });

    test('returns false when no field contains the query', () {
      final drink = createDrink();
      expect(service.matches(drink, 'zzz'), isFalse);
    });
  });

  group('hiddenFieldExcerpt', () {
    test('returns null for a blank query', () {
      final drink = createDrink(description: 'A rich chocolate finish');
      expect(service.hiddenFieldExcerpt(drink, ''), isNull);
      expect(service.hiddenFieldExcerpt(drink, '   '), isNull);
    });

    test('returns null when the match is already visible (name)', () {
      final drink = createDrink(name: 'Chocolate Stout', description: null);
      expect(service.hiddenFieldExcerpt(drink, 'chocolate'), isNull);
    });

    test('returns null when the match is only visible via style', () {
      final drink = createDrink(style: 'Chocolate Porter');
      expect(service.hiddenFieldExcerpt(drink, 'chocolate'), isNull);
    });

    test('surfaces an excerpt for a description-only match', () {
      final drink = createDrink(description: 'A rich chocolate finish');
      final excerpt = service.hiddenFieldExcerpt(drink, 'chocolate');

      expect(excerpt, isNotNull);
      expect(excerpt!.text.toLowerCase(), contains('chocolate'));
      expect(
        excerpt.text.substring(
          excerpt.matchStart,
          excerpt.matchStart + excerpt.matchLength,
        ),
        'chocolate',
      );
    });

    test('surfaces an excerpt for a user-note-only match', () {
      final drink = createDrink(userNote: 'Tom recommended this at the bar');
      final excerpt = service.hiddenFieldExcerpt(drink, 'recommended');

      expect(excerpt, isNotNull);
      expect(excerpt!.text, contains('recommended'));
    });

    test('prefers the catalogue description over the user note', () {
      final drink = createDrink(
        description: 'notably peaty and smoky',
        userNote: 'also very peaty to me',
      );
      final excerpt = service.hiddenFieldExcerpt(drink, 'peaty');

      expect(excerpt, isNotNull);
      // The description window, not the user note, is chosen.
      expect(excerpt!.text, contains('notably peaty and smoky'));
    });

    test('windows a long field with ellipses around the match', () {
      final longText =
          'The quick brown fox jumps over the lazy dog before finding '
          'a hidden treasure buried deep beneath the ancient oak tree.';
      final drink = createDrink(description: longText);
      final excerpt = service.hiddenFieldExcerpt(drink, 'treasure');

      expect(excerpt, isNotNull);
      // Elided on both sides — the match sits in the middle of the text.
      expect(excerpt!.text.startsWith('…'), isTrue);
      expect(excerpt.text.endsWith('…'), isTrue);
      // Far shorter than the source field.
      expect(excerpt.text.length, lessThan(longText.length));
      // The reported match range lands exactly on the query.
      expect(
        excerpt.text
            .substring(
              excerpt.matchStart,
              excerpt.matchStart + excerpt.matchLength,
            )
            .toLowerCase(),
        'treasure',
      );
    });

    test('does not lead with an ellipsis when the match is near the start', () {
      final drink = createDrink(description: 'Chocolate notes throughout');
      final excerpt = service.hiddenFieldExcerpt(drink, 'chocolate');

      expect(excerpt, isNotNull);
      expect(excerpt!.text.startsWith('…'), isFalse);
      expect(excerpt.text.startsWith('Chocolate'), isTrue);
    });

    test('is case-insensitive', () {
      final drink = createDrink(description: 'A rich CHOCOLATE finish');
      final excerpt = service.hiddenFieldExcerpt(drink, 'chocolate');

      expect(excerpt, isNotNull);
      // Preserves the original casing of the source text.
      expect(excerpt!.text, contains('CHOCOLATE'));
    });
  });
}
