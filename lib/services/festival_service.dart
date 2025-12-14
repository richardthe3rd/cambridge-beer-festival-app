import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Response from the festivals API
class FestivalsResponse {
  final List<Festival> festivals;
  final String defaultFestivalId;
  final String version;
  final DateTime? lastUpdated;
  final String baseUrl;

  FestivalsResponse({
    required this.festivals,
    required this.defaultFestivalId,
    required this.version,
    this.lastUpdated,
    required this.baseUrl,
  });

  factory FestivalsResponse.fromJson(Map<String, dynamic> json, String baseUrl) {
    final festivalsList = (json['festivals'] as List<dynamic>)
        .map((f) {
          final festivalJson = f as Map<String, dynamic>;
          // Resolve relative URLs to absolute URLs
          if (festivalJson['data_base_url'] != null) {
            final dataBaseUrl = festivalJson['data_base_url'] as String;
            if (dataBaseUrl.startsWith('/')) {
              festivalJson['data_base_url'] = baseUrl + dataBaseUrl;
            }
          }
          return Festival.fromJson(festivalJson);
        })
        .toList();

    return FestivalsResponse(
      festivals: festivalsList,
      defaultFestivalId: json['default_festival_id'] as String,
      version: json['version'] as String? ?? '1.0.0',
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
      baseUrl: baseUrl,
    );
  }

  /// Get the default festival
  Festival? get defaultFestival {
    if (festivals.isEmpty) return null;
    final index = festivals.indexWhere((f) => f.id == defaultFestivalId);
    return index >= 0 ? festivals[index] : festivals.first;
  }

  /// Get active festivals (currently running or upcoming)
  List<Festival> get activeFestivals {
    return festivals.where((f) => f.isActive).toList();
  }
}

/// Service for fetching festival metadata
class FestivalService {
  static const String _festivalsUrl =
      'https://data.cambeerfestival.app/festivals.json';

  final http.Client _client;
  final Duration timeout;

  FestivalService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  /// Fetches the list of available festivals
  Future<FestivalsResponse> fetchFestivals() async {
    final response = await _client.get(Uri.parse(_festivalsUrl))
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      // Extract base URL from the festivals URL (remove /festivals.json)
      final baseUrl = _festivalsUrl.replaceAll(RegExp(r'/festivals\.json$'), '');
      return FestivalsResponse.fromJson(data, baseUrl);
    } else {
      throw FestivalServiceException(
        'Failed to fetch festivals: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Exception thrown when festival API calls fail
class FestivalServiceException implements Exception {
  final String message;
  final int? statusCode;

  FestivalServiceException(this.message, [this.statusCode]);

  @override
  String toString() => 'FestivalServiceException: $message';
}
