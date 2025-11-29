/// Status of a festival based on dates
enum FestivalStatus {
  /// Festival is currently running (between start and end dates)
  live,
  /// Festival is coming up (start date is in the future)
  upcoming,
  /// Festival was the most recent one to end
  mostRecent,
  /// Festival has ended and is not the most recent
  past,
}

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

  /// Check if the festival is currently live (between start and end dates)
  bool isLive([DateTime? now]) {
    if (startDate == null) return false;
    final currentDate = now ?? DateTime.now();
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59)
        : DateTime(start.year, start.month, start.day, 23, 59, 59);
    return !currentDate.isBefore(start) && !currentDate.isAfter(end);
  }

  /// Check if the festival is upcoming (starts in the future)
  bool isUpcoming([DateTime? now]) {
    if (startDate == null) return false;
    final currentDate = now ?? DateTime.now();
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    return currentDate.isBefore(start);
  }

  /// Check if the festival has ended
  bool hasEnded([DateTime? now]) {
    if (startDate == null) return false;
    final currentDate = now ?? DateTime.now();
    final end = endDate ?? startDate;
    final endOfDay = DateTime(end!.year, end.month, end.day, 23, 59, 59);
    return currentDate.isAfter(endOfDay);
  }

  /// Get the status of this festival (for display purposes)
  /// Use getStatusInContext() for mostRecent determination across multiple festivals
  FestivalStatus getBasicStatus([DateTime? now]) {
    if (isLive(now)) return FestivalStatus.live;
    if (isUpcoming(now)) return FestivalStatus.upcoming;
    return FestivalStatus.past;
  }

  /// Sort festivals by date: live first, then upcoming (soonest first), 
  /// then past (most recent first)
  static List<Festival> sortByDate(List<Festival> festivals, [DateTime? now]) {
    final currentDate = now ?? DateTime.now();
    final sorted = List<Festival>.from(festivals);
    
    sorted.sort((a, b) {
      final statusA = a.getBasicStatus(currentDate);
      final statusB = b.getBasicStatus(currentDate);
      
      // Priority: live > upcoming > past
      if (statusA == FestivalStatus.live && statusB != FestivalStatus.live) {
        return -1;
      }
      if (statusB == FestivalStatus.live && statusA != FestivalStatus.live) {
        return 1;
      }
      
      if (statusA == FestivalStatus.upcoming && statusB == FestivalStatus.past) {
        return -1;
      }
      if (statusB == FestivalStatus.upcoming && statusA == FestivalStatus.past) {
        return 1;
      }
      
      // Within same status, sort by date
      if (statusA == FestivalStatus.upcoming && statusB == FestivalStatus.upcoming) {
        // Upcoming: soonest first. Festivals with null startDate are sorted last.
        if (a.startDate == null && b.startDate == null) return 0;
        if (a.startDate == null) return 1;
        if (b.startDate == null) return -1;
        return a.startDate!.compareTo(b.startDate!);
      }
      
      if (statusA == FestivalStatus.past && statusB == FestivalStatus.past) {
        // Past: most recent first. Festivals with null endDate/startDate are sorted last.
        final aEnd = a.endDate ?? a.startDate;
        final bEnd = b.endDate ?? b.startDate;
        if (aEnd == null && bEnd == null) return 0;
        if (aEnd == null) return 1;
        if (bEnd == null) return -1;
        return bEnd.compareTo(aEnd);
      }
      
      return 0;
    });
    
    return sorted;
  }

  /// Get the status of a festival in the context of a sorted list
  /// The first past festival in a sorted list gets mostRecent status
  static FestivalStatus getStatusInContext(
    Festival festival, 
    List<Festival> sortedFestivals,
    [DateTime? now]
  ) {
    final basicStatus = festival.getBasicStatus(now);
    if (basicStatus != FestivalStatus.past) {
      return basicStatus;
    }
    
    // Find the first past festival in the sorted list
    final currentDate = now ?? DateTime.now();
    for (final f in sortedFestivals) {
      if (f.getBasicStatus(currentDate) == FestivalStatus.past) {
        if (f.id == festival.id) {
          return FestivalStatus.mostRecent;
        }
        break;
      }
    }
    
    return FestivalStatus.past;
  }
}

/// Predefined festival configurations
class DefaultFestivals {
  static final cambridge2025 = Festival(
    id: 'cbf2025',
    name: 'Cambridge Beer Festival 2025',
    hashtag: '#cbf2025',
    startDate: DateTime(2025, 5, 19),
    endDate: DateTime(2025, 5, 24),
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

  static final cambridgeWinter2025 = Festival(
    id: 'cbfw2025',
    name: 'Cambridge Winter Beer Festival 2025',
    hashtag: '#cbfw2025',
    startDate: DateTime(2025, 12, 10),
    endDate: DateTime(2025, 12, 13),
    location: 'Cambridge Corn Exchange, Cambridge',
    availableBeverageTypes: ['beer', 'international-beer', 'cider', 'perry', 'low-no'],
    dataBaseUrl: 'https://cbf-data-proxy.richard-alcock.workers.dev/cbfw2025',
    isActive: false,
  );

  static final cambridge2024 = Festival(
    id: 'cbf2024',
    name: 'Cambridge Beer Festival 2024',
    hashtag: '#cbf2024',
    startDate: DateTime(2024, 5, 20),
    endDate: DateTime(2024, 5, 25),
    location: 'Jesus Green, Cambridge',
    description: 'The 50th Anniversary Cambridge Beer Festival',
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
    dataBaseUrl: 'https://cbf-data-proxy.richard-alcock.workers.dev/cbf2024',
    isActive: false,
  );

  static List<Festival> get all => [cambridge2025, cambridgeWinter2025, cambridge2024];
}
