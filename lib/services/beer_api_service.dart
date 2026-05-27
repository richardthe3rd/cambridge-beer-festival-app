import 'dart:async';
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

  /// Fetches all drinks from a festival for a specific beverage type.
  ///
  /// Returns an empty list when the beverage type is not available (HTTP 404).
  /// Callers that need to distinguish "no data" from "type not offered" (the
  /// per-type cache) should use [fetchDrinksByType] instead.
  Future<List<Drink>> fetchDrinks(
      Festival festival, String beverageType) async {
    return (await _fetchDrinksOrNull(festival, beverageType)) ?? <Drink>[];
  }

  /// Returns the parsed drinks for one beverage type, or null when the API
  /// responded 404 (meaning "not offered, or transiently unavailable").
  /// Throws [BeerApiException] for non-200/404 statuses or other I/O errors.
  Future<List<Drink>?> _fetchDrinksOrNull(
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
      return null;
    }
    throw BeerApiException(
      'Failed to fetch $beverageType: ${response.statusCode}',
      response.statusCode,
    );
  }

  /// Fetches all beverage types in parallel, reporting per-type outcomes.
  ///
  /// A type that responded with HTTP 200 appears in
  /// [FestivalDrinksResult.drinksByType]; a type that errored (network,
  /// timeout, 5xx, …) appears in [FestivalDrinksResult.failedTypes]. A 404
  /// is treated as a soft omission — it appears in NEITHER bucket — so the
  /// per-type cache will preserve any previously-cached entry for that type
  /// rather than overwriting it with empty on a transient 404 (e.g. mid-deploy).
  Future<FestivalDrinksResult> fetchDrinksByType(Festival festival) async {
    final entries = await Future.wait(
      festival.availableBeverageTypes.map((beverageType) async {
        try {
          final drinks = await _fetchDrinksOrNull(festival, beverageType);
          // drinks == null → 404, omitted from result.
          return (type: beverageType, drinks: drinks, error: null);
        } catch (e) {
          return (type: beverageType, drinks: null, error: e);
        }
      }),
    );

    final drinksByType = <String, List<Drink>>{};
    final failedTypes = <String, Object>{};
    for (final entry in entries) {
      if (entry.drinks != null) {
        drinksByType[entry.type] = entry.drinks!;
      } else if (entry.error != null) {
        failedTypes[entry.type] = entry.error!;
      }
      // else: 404 — neither success nor failure, preserves cache.
    }

    return FestivalDrinksResult(
      drinksByType: drinksByType,
      failedTypes: failedTypes,
    );
  }

  /// Fetches all available drinks from a festival (all beverage types).
  ///
  /// Throws [BeerApiException] if every beverage type errored. Types that
  /// responded 404 contribute nothing and never trigger this throw on their
  /// own — preserving the historical behaviour that an all-404 festival
  /// returns an empty list rather than an error.
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
      if (producer.id.isEmpty) continue;
      for (final product in producer.products) {
        if (product.id.isEmpty) continue;
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
/// [drinksByType] holds the types that loaded successfully (HTTP 200);
/// [failedTypes] maps each errored type to the original error object so
/// callers (and [throwIfCompleteFailure]) can inspect it for classification.
/// 404s are deliberately omitted from both maps — see [BeerApiService.fetchDrinksByType].
class FestivalDrinksResult {
  final Map<String, List<Drink>> drinksByType;
  final Map<String, Object> failedTypes;

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
  ///
  /// When every underlying failure is a connectivity error, the thrown
  /// exception carries one of them as [BeerApiException.cause] so the provider
  /// can recognise the wrapped offline case and skip noisy analytics logging.
  void throwIfCompleteFailure() {
    if (!isCompleteFailure) return;
    final details =
        failedTypes.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    final allConnectivity = failedTypes.values.every(isConnectivityFailure);
    throw BeerApiException(
      'Failed to load any drinks. This may be a network or CORS issue.\n\nDetails:\n$details',
      null,
      allConnectivity ? failedTypes.values.first : null,
    );
  }
}

/// Exception thrown when API calls fail.
///
/// [cause] is the underlying error when this exception wraps one (e.g. a
/// `SocketException`/`TimeoutException` aggregated from per-type failures),
/// letting callers classify it without parsing strings.
class BeerApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  BeerApiException(this.message, [this.statusCode, this.cause]);

  @override
  String toString() => 'BeerApiException: $message';
}

/// Whether [error] represents a connectivity failure (offline, timeout, DNS,
/// TLS handshake) rather than a server-side or programming error.
///
/// Lives next to [BeerApiException] so that error classification and the
/// per-type fetch logic share a single source of truth.
bool isConnectivityFailure(Object error) {
  if (error is http.ClientException || error is TimeoutException) return true;
  // dart:io types aren't available on web; match by runtime type name to
  // cover SocketException, HandshakeException, and HttpException without an
  // unconditional dart:io import.
  const connectivityTypeNames = {
    'SocketException',
    'HandshakeException',
    'HttpException',
    'TlsException',
  };
  return connectivityTypeNames.contains(error.runtimeType.toString());
}
