import 'package:cambridge_beer_festival/domain/controllers/controllers.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _kNow = DateTime(2026, 6, 7);

UserDrinkState _sampleState({
  bool wantToTry = false,
  int? rating,
  List<DateTime>? tastingEvents,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return UserDrinkState(
    wantToTry: wantToTry,
    rating: rating,
    tastingEvents: tastingEvents,
    createdAt: createdAt ?? _kNow,
    updatedAt: updatedAt ?? _kNow,
  );
}

Drink _drink({required String id, UserDrinkState? userState}) {
  final producer = Producer.fromJson({
    'id': 'brewery-1',
    'name': 'Test Brewery',
    'location': 'Cambridge',
    'products': const <Map<String, dynamic>>[],
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
        final drinkWithState = _drink(
          id: 'd1',
          userState: _sampleState(wantToTry: true),
        );
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
        controller
          ..setSource([
            _drink(id: 'a', userState: _sampleState(wantToTry: true)),
          ])
          ..setSource([
            _drink(id: 'b', userState: _sampleState(wantToTry: true)),
          ]);

        expect(controller.stateFor('a'), isNull);
        expect(controller.stateFor('b'), isNotNull);
      });

      test('clear removes all state', () {
        controller
          ..setSource([
            _drink(id: 'd1', userState: _sampleState(wantToTry: true)),
          ])
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
        controller.setSource([
          _drink(id: 'd1', userState: _sampleState(wantToTry: true)),
        ]);

        expect(controller.isFavorite('d1'), isTrue);
      });

      test('ratingFor returns null for unknown id', () {
        expect(controller.ratingFor('unknown'), isNull);
      });

      test('ratingFor returns value when rating is set', () {
        controller.setSource([
          _drink(id: 'd1', userState: _sampleState(rating: 4)),
        ]);

        expect(controller.ratingFor('d1'), equals(4));
      });

      test('isTasted returns false for unknown id', () {
        expect(controller.isTasted('unknown'), isFalse);
      });

      test('isTasted returns true when tastingEvents non-empty', () {
        controller.setSource([
          _drink(
            id: 'd1',
            userState: _sampleState(tastingEvents: [_kNow]),
          ),
        ]);

        expect(controller.isTasted('d1'), isTrue);
      });

      test('tastingCountFor returns 0 for unknown id', () {
        expect(controller.tastingCountFor('unknown'), equals(0));
      });

      test('tastingCountFor returns count of tasting events', () {
        controller.setSource([
          _drink(
            id: 'd1',
            userState: _sampleState(
              tastingEvents: [_kNow, _kNow.add(const Duration(hours: 1))],
            ),
          ),
        ]);

        expect(controller.tastingCountFor('d1'), equals(2));
      });
    });

    // --- apply ---

    group('apply', () {
      test('stores a non-empty state and returns it', () {
        final state = _sampleState(wantToTry: true);
        final result = controller.apply('d1', state);

        expect(result, equals(state));
        expect(controller.stateFor('d1'), equals(state));
      });

      test('prunes and returns null when given null', () {
        controller.setSource([
          _drink(id: 'd1', userState: _sampleState(wantToTry: true)),
        ]);
        final result = controller.apply('d1', null);

        expect(result, isNull);
        expect(controller.stateFor('d1'), isNull);
      });

      test('prunes and returns null when given an empty state', () {
        controller.setSource([
          _drink(id: 'd1', userState: _sampleState(wantToTry: true)),
        ]);
        final result = controller.apply('d1', _sampleState());

        expect(result, isNull);
        expect(controller.stateFor('d1'), isNull);
      });

      test('replaces existing state wholesale, does not merge', () {
        controller.setSource([
          _drink(id: 'd1', userState: _sampleState(wantToTry: true, rating: 3)),
        ]);
        final incoming = _sampleState(rating: 5);
        controller.apply('d1', incoming);

        expect(controller.isFavorite('d1'), isFalse);
        expect(controller.ratingFor('d1'), equals(5));
      });
    });
  });
}
