/// Represents a beer festival
class Festival {
  final String id;
  final String name;
  final String? hashtag;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? websiteUrl;
  final Map<String, String>? hours;
  final List<String> availableBeverageTypes;
  final String dataBaseUrl;
  final bool isActive;

  const Festival({
    required this.id,
    required this.name,
    this.hashtag,
    this.startDate,
    this.endDate,
    this.location,
    this.address,
    this.latitude,
    this.longitude,
    this.description,
    this.websiteUrl,
    this.hours,
    this.availableBeverageTypes = const ['beer'],
    required this.dataBaseUrl,
    this.isActive = false,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: json['id'] as String,
      name: json['name'] as String,
      hashtag: json['hashtag'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      location: json['location'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String?,
      websiteUrl: json['website_url'] as String?,
      hours: (json['hours'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value as String)),
      availableBeverageTypes: (json['available_beverage_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['beer'],
      dataBaseUrl: json['data_base_url'] as String,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (hashtag != null) 'hashtag': hashtag,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (location != null) 'location': location,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (description != null) 'description': description,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (hours != null) 'hours': hours,
      'available_beverage_types': availableBeverageTypes,
      'data_base_url': dataBaseUrl,
      'is_active': isActive,
    };
  }

  /// Get the URL for a specific beverage type
  String getBeverageUrl(String beverageType) {
    return '$dataBaseUrl/$beverageType.json';
  }

  /// Format the festival dates for display
  String get formattedDates {
    if (startDate == null) return '';
    final start = startDate!;
    final end = endDate;

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    if (end == null) {
      return '${months[start.month - 1]} ${start.day}, ${start.year}';
    }

    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.day}-${end.day}, ${start.year}';
    }

    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${start.year}';
  }
}

/// Predefined festival configurations
class DefaultFestivals {
  static const cambridge2025 = Festival(
    id: 'cbf2025',
    name: 'Cambridge Beer Festival 2025',
    hashtag: '#cbf2025',
    location: 'Jesus Green, Cambridge',
    description: 'The largest volunteer-run beer festival in the UK',
    websiteUrl: 'https://www.cambridgebeerfestival.com',
    availableBeverageTypes: [
      'beer',
      'international-beer',
      'cider',
      'perry',
      'mead',
      'wine',
      'low-no',
    ],
    dataBaseUrl: 'https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025',
    isActive: true,
  );

  static const cambridgeWinter2025 = Festival(
    id: 'cbfw2025',
    name: 'Cambridge Winter Beer Festival 2025',
    hashtag: '#cbfw2025',
    location: 'Cambridge',
    availableBeverageTypes: ['beer', 'low-no'],
    dataBaseUrl: 'https://cbf-data-proxy.richard-alcock.workers.dev/cbfw2025',
    isActive: false,
  );

  static List<Festival> get all => [cambridge2025, cambridgeWinter2025];
}
