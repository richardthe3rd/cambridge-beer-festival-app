import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Service for fetching beer festival data from the API
class BeerApiService {
  final http.Client _client;
  final Duration timeout;

  BeerApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  /// Fetches all drinks from a festival for a specific beverage type
  Future<List<Drink>> fetchDrinks(
      Festival festival, String beverageType) async {
    final url = festival.getBeverageUrl(beverageType);
    final response = await _client.get(Uri.parse(url)).timeout(timeout);

    if (response.statusCode == 200) {
      // Decode as UTF-8 to handle non-ASCII characters properly (é, ñ, etc.)
      // Using response.body defaults to Latin-1 if no charset in Content-Type,
      // which causes "Rosé" to display as "RosÃ©" (mojibake)
      final jsonString = utf8.decode(response.bodyBytes);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      return parseProducers(data, festival.id);
    } else if (response.statusCode == 404) {
      // Beverage type not available for this festival
      return [];
    } else {
      throw BeerApiException(
        'Failed to fetch $beverageType: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  /// Fetches all beverage types in parallel, reporting per-type outcomes.
  ///
  /// A type that loads (HTTP 200, or 404 → empty) appears in
  /// [FestivalDrinksResult.drinksByType]; a type that errors (network, timeout,
  /// 5xx, …) appears in [FestivalDrinksResult.failedTypes]. This lets callers
  /// merge fresh data per type while preserving the last-good cache for types
  /// that failed, instead of treating a partial fetch as a full snapshot.
  Future<FestivalDrinksResult> fetchDrinksByType(Festival festival) async {
    final entries = await Future.wait(
      festival.availableBeverageTypes.map((beverageType) async {
        try {
          final drinks = await fetchDrinks(festival, beverageType);
          return (type: beverageType, drinks: drinks, error: null);
        } catch (e) {
          return (type: beverageType, drinks: null, error: e.toString());
        }
      }),
    );

    final drinksByType = <String, List<Drink>>{};
    final failedTypes = <String, String>{};
    for (final entry in entries) {
      if (entry.drinks != null) {
        drinksByType[entry.type] = entry.drinks!;
      } else {
        failedTypes[entry.type] = entry.error!;
      }
    }

    return FestivalDrinksResult(
      drinksByType: drinksByType,
      failedTypes: failedTypes,
    );
  }

  /// Fetches all available drinks from a festival (all beverage types).
  ///
  /// Fetches all beverage types in parallel for faster loading.
  /// Throws [BeerApiException] if ALL beverage types fail to load or return
  /// no drinks. Individual failures are tracked and reported in the exception
  /// message to help diagnose issues like CORS or network problems.
  Future<List<Drink>> fetchAllDrinks(Festival festival) async {
    final result = await fetchDrinksByType(festival);
    result.throwIfCompleteFailure();
    return result.allDrinks;
  }

  /// Parses an API response body (the `{ "producers": [...] }` shape) into a
  /// flat list of [Drink] objects for the given festival.
  ///
  /// Public and static so the local data cache can deserialize stored payloads
  /// through the exact same logic used for live API responses.
  static List<Drink> parseProducers(
      Map<String, dynamic> data, String festivalId) {
    final drinks = <Drink>[];
    final producers = data['producers'] as List<dynamic>? ?? [];

    for (final producerJson in producers) {
      final producer = Producer.fromJson(producerJson as Map<String, dynamic>);
      for (final product in producer.products) {
        drinks.add(Drink(
          product: product,
          producer: producer,
          festivalId: festivalId,
        ));
      }
    }

    return drinks;
  }

  void dispose() {
    _client.close();
  }
}

/// Per-beverage-type outcome of fetching a festival's drinks.
///
/// [drinksByType] holds the types that loaded successfully (a 404 counts as a
/// successful empty result); [failedTypes] maps each errored type to a
/// diagnostic string.
class FestivalDrinksResult {
  final Map<String, List<Drink>> drinksByType;
  final Map<String, String> failedTypes;

  const FestivalDrinksResult({
    required this.drinksByType,
    required this.failedTypes,
  });

  /// All successfully fetched drinks, flattened across beverage types.
  List<Drink> get allDrinks =>
      [for (final drinks in drinksByType.values) ...drinks];

  /// True when every beverage type errored and nothing was fetched.
  bool get isCompleteFailure => drinksByType.isEmpty && failedTypes.isNotEmpty;

  /// Throws a [BeerApiException] describing the failures when nothing loaded.
  void throwIfCompleteFailure() {
    if (!isCompleteFailure) return;
    final details =
        failedTypes.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    throw BeerApiException(
      'Failed to load any drinks. This may be a network or CORS issue.\n\nDetails:\n$details',
    );
  }
}

/// Exception thrown when API calls fail
class BeerApiException implements Exception {
  final String message;
  final int? statusCode;

  BeerApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'BeerApiException: $message';
}
