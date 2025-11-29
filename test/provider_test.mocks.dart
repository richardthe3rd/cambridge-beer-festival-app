// Mocks generated manually for provider_test.dart
import 'dart:async';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:mockito/mockito.dart';

/// A class which mocks [BeerApiService].
class MockBeerApiService extends Mock implements BeerApiService {
  @override
  Duration get timeout => const Duration(seconds: 30);

  @override
  Future<List<Drink>> fetchAllDrinks(Festival? festival) =>
      super.noSuchMethod(
        Invocation.method(#fetchAllDrinks, [festival]),
        returnValue: Future.value(<Drink>[]),
        returnValueForMissingStub: Future.value(<Drink>[]),
      ) as Future<List<Drink>>;

  @override
  Future<List<Drink>> fetchDrinks(Festival? festival, String? beverageType) =>
      super.noSuchMethod(
        Invocation.method(#fetchDrinks, [festival, beverageType]),
        returnValue: Future.value(<Drink>[]),
        returnValueForMissingStub: Future.value(<Drink>[]),
      ) as Future<List<Drink>>;
}

/// A class which mocks [FestivalService].
class MockFestivalService extends Mock implements FestivalService {
  @override
  Duration get timeout => const Duration(seconds: 30);

  @override
  Future<FestivalsResponse> fetchFestivals() =>
      super.noSuchMethod(
        Invocation.method(#fetchFestivals, []),
        returnValue: Future.value(FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
        )),
        returnValueForMissingStub: Future.value(FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
        )),
      ) as Future<FestivalsResponse>;
}
