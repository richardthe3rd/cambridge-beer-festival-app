import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Service for fetching beer festival data from the API
class BeerApiService {
  final http.Client _client;

  BeerApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches all drinks from a festival for a specific beverage type
  Future<List<Drink>> fetchDrinks(Festival festival, String beverageType) async {
    final url = festival.getBeverageUrl(beverageType);
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseDrinks(data, festival.id);
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

  /// Fetches all available drinks from a festival (all beverage types)
  /// 
  /// Throws [BeerApiException] if ALL beverage types fail to load or return
  /// no drinks. Individual failures are tracked and reported in the exception
  /// message to help diagnose issues like CORS or network problems.
  Future<List<Drink>> fetchAllDrinks(Festival festival) async {
    final allDrinks = <Drink>[];
    final errors = <String, String>{};

    for (final beverageType in festival.availableBeverageTypes) {
      try {
        final drinks = await fetchDrinks(festival, beverageType);
        allDrinks.addAll(drinks);
      } catch (e) {
        // Track the error for this beverage type
        errors[beverageType] = e.toString();
      }
    }

    // If we got no drinks at all and there were errors, throw with details
    if (allDrinks.isEmpty && errors.isNotEmpty) {
      final errorDetails = errors.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      throw BeerApiException(
        'Failed to load any drinks. This may be a network or CORS issue.\n\nDetails:\n$errorDetails',
      );
    }

    return allDrinks;
  }

  /// Parses the API response into a list of Drink objects
  List<Drink> _parseDrinks(Map<String, dynamic> data, String festivalId) {
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

/// Exception thrown when API calls fail
class BeerApiException implements Exception {
  final String message;
  final int? statusCode;

  BeerApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'BeerApiException: $message';
}
