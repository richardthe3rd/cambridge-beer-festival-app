import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Response from the festivals API
class FestivalsResponse {
  final List<Festival> festivals;
  final String defaultFestivalId;
  final String version;
  final DateTime? lastUpdated;

  FestivalsResponse({
    required this.festivals,
    required this.defaultFestivalId,
    required this.version,
    this.lastUpdated,
  });

  factory FestivalsResponse.fromJson(Map<String, dynamic> json) {
    final festivalsList = (json['festivals'] as List<dynamic>)
        .map((f) => Festival.fromJson(f as Map<String, dynamic>))
        .toList();

    return FestivalsResponse(
      festivals: festivalsList,
      defaultFestivalId: json['default_festival_id'] as String,
      version: json['version'] as String? ?? '1.0.0',
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
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
      'https://cbf-data-proxy.richard-alcock.workers.dev/festivals.json';

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
      return FestivalsResponse.fromJson(data);
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
