import 'package:cambridge_beer_festival/domain/controllers/controllers.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Drink _drink({required String id, UserDrinkState? userState}) {
  final producer = Producer.fromJson({
    'id': 'brewery-1',
    'name': 'Test Brewery',
    'location': 'Cambridge',
    'products': const [],
  });
  final product = Product.fromJson({
    'id': id,
    'name': 'Test Drink $id',
    'category': 'beer',
    'dispense': 'cask',
    'abv': '5.0',
  });
  return Drink(
    product: product,
    producer: producer,
    festivalId: 'cbf2025',
    userState: userState,
  );
}

void main() {
  group('UserDrinkStateController', () {
    late UserDrinkStateController controller;

    setUp(() {
      controller = UserDrinkStateController();
    });

    // --- setSource / clear ---

    group('setSource / clear', () {
      test('setSource populates state from drinks with non-null userState', () {
        final now = DateTime(2026, 6, 7);
        final stateWithData = UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        );
        final drinkWithState = _drink(id: 'd1', userState: stateWithData);
        final drinkWithoutState = _drink(id: 'd2');

        controller.setSource([drinkWithState, drinkWithoutState]);

        expect(controller.stateFor('d1'), isNotNull);
        expect(controller.stateFor('d2'), isNull);
      });

      test('setSource ignores drinks with null userState', () {
        final drinkWithoutState = _drink(id: 'd1');
        controller.setSource([drinkWithoutState]);

        expect(controller.stateFor('d1'), isNull);
      });

      test('setSource replaces previous state on re-call', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        );
        final drinkA = _drink(id: 'a', userState: state);
        controller.setSource([drinkA]);

        // Second call with a different list
        final drinkB = _drink(id: 'b', userState: state);
        controller.setSource([drinkB]);

        expect(controller.stateFor('a'), isNull);
        expect(controller.stateFor('b'), isNotNull);
      });

      test('clear removes all state', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        );
        controller
          ..setSource([_drink(id: 'd1', userState: state)])
          ..clear();

        expect(controller.stateFor('d1'), isNull);
      });
    });

    // --- read access ---

    group('read access', () {
      test('isFavorite returns false for unknown id', () {
        expect(controller.isFavorite('unknown'), isFalse);
      });

      test('isFavorite returns true when wantToTry is set', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        );
        controller.setSource([_drink(id: 'd1', userState: state)]);

        expect(controller.isFavorite('d1'), isTrue);
      });

      test('ratingFor returns null for unknown id', () {
        expect(controller.ratingFor('unknown'), isNull);
      });

      test('ratingFor returns value when rating is set', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(rating: 4, createdAt: now, updatedAt: now);
        controller.setSource([_drink(id: 'd1', userState: state)]);

        expect(controller.ratingFor('d1'), equals(4));
      });

      test('isTasted returns false for unknown id', () {
        expect(controller.isTasted('unknown'), isFalse);
      });

      test('isTasted returns true when tastingEvents non-empty', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          tastingEvents: [now],
          createdAt: now,
          updatedAt: now,
        );
        controller.setSource([_drink(id: 'd1', userState: state)]);

        expect(controller.isTasted('d1'), isTrue);
      });

      test('tastingCountFor returns 0 for unknown id', () {
        expect(controller.tastingCountFor('unknown'), equals(0));
      });

      test('tastingCountFor returns count of tasting events', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          tastingEvents: [now, now.add(const Duration(hours: 1))],
          createdAt: now,
          updatedAt: now,
        );
        controller.setSource([_drink(id: 'd1', userState: state)]);

        expect(controller.tastingCountFor('d1'), equals(2));
      });
    });

    // --- applyWantToTry ---

    group('applyWantToTry', () {
      test('sets wantToTry on drink with no prior state', () {
        final result = controller.applyWantToTry('d1', value: true);

        expect(result, isNotNull);
        expect(controller.isFavorite('d1'), isTrue);
      });

      test('returns null and prunes when clearing sole field', () {
        controller.applyWantToTry('d1', value: true);
        final result = controller.applyWantToTry('d1', value: false);

        expect(result, isNull);
        expect(controller.stateFor('d1'), isNull);
      });

      test('clears wantToTry but retains rating when other state present', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          rating: 3,
          createdAt: now,
          updatedAt: now,
        );
        controller.setSource([_drink(id: 'd1', userState: state)]);

        final result = controller.applyWantToTry('d1', value: false);

        expect(result, isNotNull);
        expect(controller.ratingFor('d1'), equals(3));
      });
    });

    // --- applyRating ---

    group('applyRating', () {
      test('sets rating on drink with no prior state', () {
        final result = controller.applyRating('d1', rating: 5);

        expect(result, isNotNull);
        expect(controller.ratingFor('d1'), equals(5));
      });

      test('clears rating (null) and prunes when no other state', () {
        controller.applyRating('d1', rating: 3);
        final result = controller.applyRating('d1', rating: null);

        expect(result, isNull);
        expect(controller.stateFor('d1'), isNull);
      });

      test('clears rating but retains wantToTry when other state present', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          rating: 3,
          createdAt: now,
          updatedAt: now,
        );
        controller.setSource([_drink(id: 'd1', userState: state)]);

        final result = controller.applyRating('d1', rating: null);

        expect(result, isNotNull);
        expect(controller.isFavorite('d1'), isTrue);
      });
    });

    // --- applyTasted ---

    group('applyTasted', () {
      test('records a single tasting event when tasted=true', () {
        final result = controller.applyTasted(
          'd1',
          tasted: true,
          now: DateTime(2026, 6, 7),
        );

        expect(result, isNotNull);
        expect(controller.isTasted('d1'), isTrue);
        expect(controller.tastingCountFor('d1'), equals(1));
      });

      test('uses injected timestamp', () {
        final ts = DateTime(2026, 6, 7);
        controller.applyTasted('d1', tasted: true, now: ts);

        expect(controller.stateFor('d1')!.tastingEvents.first, equals(ts));
      });

      test('clears tasting events when tasted=false', () {
        controller.applyTasted('d1', tasted: true, now: DateTime(2026, 6, 7));
        final result = controller.applyTasted('d1', tasted: false);

        expect(controller.isTasted('d1'), isFalse);
        expect(result, isNull);
      });

      test(
        'binary toggle: calling applyTasted(true) twice still yields count=1',
        () {
          final ts1 = DateTime(2026, 6, 7, 10);
          final ts2 = DateTime(2026, 6, 7, 11);
          controller
            ..applyTasted('d1', tasted: true, now: ts1)
            ..applyTasted('d1', tasted: true, now: ts2);

          expect(controller.tastingCountFor('d1'), equals(1));
          expect(controller.stateFor('d1')!.tastingEvents.first, equals(ts2));
        },
      );
    });

    // --- cross-field preservation ---

    group('cross-field preservation', () {
      test('applyWantToTry preserves existing rating', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(rating: 4, createdAt: now, updatedAt: now);
        controller
          ..setSource([_drink(id: 'd1', userState: state)])
          ..applyWantToTry('d1', value: true);

        expect(controller.ratingFor('d1'), equals(4));
        expect(controller.isFavorite('d1'), isTrue);
      });

      test('applyRating preserves existing wantToTry', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        );
        controller
          ..setSource([_drink(id: 'd1', userState: state)])
          ..applyRating('d1', rating: 5);

        expect(controller.isFavorite('d1'), isTrue);
        expect(controller.ratingFor('d1'), equals(5));
      });

      test('applyTasted preserves existing rating', () {
        final now = DateTime(2026, 6, 7);
        final state = UserDrinkState(rating: 3, createdAt: now, updatedAt: now);
        controller
          ..setSource([_drink(id: 'd1', userState: state)])
          ..applyTasted('d1', tasted: true, now: now);

        expect(controller.ratingFor('d1'), equals(3));
        expect(controller.isTasted('d1'), isTrue);
      });
    });
  });
}
