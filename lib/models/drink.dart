/// Represents a beverage producer (brewery, cidery, meadery, etc.)
class Producer {
  final String id;
  final String name;
  final String location;
  final int? yearFounded;
  final String? notes;
  final List<Product> products;

  const Producer({
    required this.id,
    required this.name,
    required this.location,
    this.yearFounded,
    this.notes,
    required this.products,
  });

  factory Producer.fromJson(Map<String, dynamic> json) {
    // Parse year_founded robustly - it may be int, String, or null
    int? yearFounded;
    final yearValue = json['year_founded'];
    if (yearValue is int) {
      yearFounded = yearValue;
    } else if (yearValue is String) {
      yearFounded = int.tryParse(yearValue);
    }

    return Producer(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      location: (json['location'] ?? '').toString(),
      yearFounded: yearFounded,
      notes: json['notes']?.toString(),
      products:
          (json['products'] as List<dynamic>?)
              ?.map((p) => Product.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      if (yearFounded != null) 'year_founded': yearFounded,
      if (notes != null) 'notes': notes,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (id.isEmpty) return identical(this, other);
    return other is Producer && other.id == id;
  }

  @override
  int get hashCode => id.isEmpty ? identityHashCode(this) : id.hashCode;
}

/// Represents a beverage product (beer, cider, mead, etc.)
class Product {
  final String id;
  final String name;
  final String category;
  final String? style;
  final String dispense;
  final double abv;
  final String? notes;
  final String? statusText;
  final String? bar;
  final Map<String, int> allergens;
  final bool? isVegan;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.style,
    required this.dispense,
    required this.abv,
    this.notes,
    this.statusText,
    this.bar,
    this.allergens = const {},
    this.isVegan,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final abvValue = json['abv'];
    double parsedAbv;
    if (abvValue is num) {
      parsedAbv = abvValue.toDouble();
    } else if (abvValue is String) {
      parsedAbv = double.tryParse(abvValue) ?? 0.0;
    } else {
      parsedAbv = 0.0;
    }

    // Parse allergens robustly - values are typically int (1 = present) but may
    // also be bool or other numeric types. Unknown types are skipped as they
    // don't represent a valid allergen flag.
    final allergensRaw = json['allergens'];
    final allergens = <String, int>{};
    if (allergensRaw is Map) {
      for (final entry in allergensRaw.entries) {
        final value = entry.value;
        if (value is int) {
          allergens[entry.key] = value;
        } else if (value is bool) {
          allergens[entry.key] = value ? 1 : 0;
        } else if (value is num) {
          allergens[entry.key] = value.toInt();
        }
        // Other types (String, null, etc.) are skipped as invalid allergen flags
      }
    }

    // Parse bar field - can be String, int, or boolean
    // Per API docs, bar can be "string or boolean". Boolean values (true/false)
    // indicate presence at unspecified bar, so we treat them as null (no specific bar name)
    String? bar;
    final barValue = json['bar'];
    if (barValue is String) {
      bar = barValue;
    } else if (barValue is int) {
      bar = barValue.toString();
    }

    // Parse vegan field robustly - can be bool, int/num, or string.
    bool? parsedVegan;
    final veganValue = json['is_vegan'] ?? json['vegan'];
    if (veganValue is bool) {
      parsedVegan = veganValue;
    } else if (veganValue is num) {
      parsedVegan = veganValue != 0;
    } else if (veganValue is String) {
      final normalized = veganValue.toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        parsedVegan = true;
      } else if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no') {
        parsedVegan = false;
      }
    }

    return Product(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      category: (json['category'] ?? 'beer').toString(),
      style: json['style']?.toString(),
      dispense: (json['dispense'] ?? 'cask').toString(),
      abv: parsedAbv,
      notes: json['notes']?.toString(),
      statusText: json['status_text']?.toString(),
      bar: bar,
      allergens: allergens,
      isVegan: parsedVegan,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      if (style != null) 'style': style,
      'dispense': dispense,
      'abv': abv.toString(),
      if (notes != null) 'notes': notes,
      if (statusText != null) 'status_text': statusText,
      if (bar != null) 'bar': bar,
      'allergens': allergens,
      if (isVegan != null) 'is_vegan': isVegan,
    };
  }

  /// Returns the availability status for display
  AvailabilityStatus? get availabilityStatus {
    if (statusText == null || statusText!.trim().isEmpty) return null;
    final lower = statusText!.trim().toLowerCase();

    // Exact match against the known festival vocabulary (case/trim normalised).
    final exact = _statusMap[lower];
    if (exact != null) return exact;

    // Unknown phrase — safe catch-all; raw text is shown in the UI.
    return AvailabilityStatus.unknown;
  }

  /// Returns allergen list as a formatted string
  String? get allergenText {
    if (allergens.isEmpty) return null;
    final allergenList = allergens.entries
        .where((e) => e.value == 1 && e.key.isNotEmpty)
        .map((e) {
          // Capitalize first letter
          return e.key[0].toUpperCase() + e.key.substring(1);
        })
        .toList();
    if (allergenList.isEmpty) return null;
    return allergenList.join(', ');
  }

  /// Returns true if the product has no declared allergens
  bool get isAllergenFree =>
      allergens.isEmpty || allergens.values.every((v) => v == 0);

  @override
  bool operator ==(Object other) {
    if (id.isEmpty) return identical(this, other);
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.isEmpty ? identityHashCode(this) : id.hashCode;
}

/// Availability status for a product, ordered from most to least available.
/// `unknown` is a safe catch-all for phrases not in the known vocabulary;
/// the raw statusText is passed through to the UI for display.
enum AvailabilityStatus { plenty, good, low, veryLow, out, unknown }

/// Exact-match map for the known festival status-text vocabulary.
/// Keys are lowercase+trimmed. Novel phrases map to AvailabilityStatus.unknown.
const Map<String, AvailabilityStatus> _statusMap = {
  'sold out': AvailabilityStatus.out,
  'nearly finished!': AvailabilityStatus.veryLow,
  'a little remaining': AvailabilityStatus.low,
  'some beer remaining': AvailabilityStatus.good,
  'plenty left': AvailabilityStatus.plenty,
  'arrived': AvailabilityStatus.plenty,
};

/// Extended drink model that includes producer information
class Drink {
  final Product product;
  final Producer producer;
  final String festivalId;
  final bool isFavorite;
  final int? rating;
  final bool isTasted;

  static const _absent = Object();

  Drink({
    required this.product,
    required this.producer,
    required this.festivalId,
    this.isFavorite = false,
    this.rating,
    this.isTasted = false,
  });

  Drink copyWith({bool? isFavorite, Object? rating = _absent, bool? isTasted}) {
    return Drink(
      product: product,
      producer: producer,
      festivalId: festivalId,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: identical(rating, _absent) ? this.rating : rating as int?,
      isTasted: isTasted ?? this.isTasted,
    );
  }

  String get id => product.id;
  String get name => product.name;
  String get breweryName => producer.name;
  String get breweryLocation => producer.location;
  String get category => product.category;
  String? get style => product.style;
  String get dispense => product.dispense;
  double get abv => product.abv;
  String? get notes => product.notes;
  String? get statusText => product.statusText;
  String? get bar => product.bar;
  Map<String, int> get allergens => product.allergens;
  AvailabilityStatus? get availabilityStatus => product.availabilityStatus;
  String? get allergenText => product.allergenText;
  bool? get isVegan => product.isVegan;
  bool get isAllergenFree => product.isAllergenFree;
  String get producerId => producer.id;

  bool isSameBrewery(Drink other) => producer == other.producer;

  @override
  bool operator ==(Object other) {
    if (product.id.isEmpty) return identical(this, other);
    return other is Drink &&
        other.product.id == product.id &&
        other.festivalId == festivalId;
  }

  @override
  int get hashCode => product.id.isEmpty
      ? identityHashCode(this)
      : Object.hash(product.id, festivalId);

  /// Generate a share message for this drink.
  ///
  /// The [hashtag] parameter should be a valid social media hashtag including
  /// the # symbol (e.g., '#cbf2025').
  ///
  /// The optional [url] parameter, when provided, is appended on a new line
  /// so recipients can tap through to the drink directly.
  ///
  /// Returns a message in the format:
  /// - Without rating: "Drinking {name} from {brewery} at {hashtag}"
  /// - With rating: "Drinking {name} from {brewery} at {hashtag} - {n} stars"
  /// - With url: above + "\n{url}"
  String getShareMessage(String hashtag, {String? url}) {
    final buffer = StringBuffer();
    buffer.write('Drinking $name from $breweryName at $hashtag');
    if (rating != null) {
      buffer.write(' - $rating stars');
    }
    if (url != null) {
      buffer.write('\n$url');
    }
    return buffer.toString();
  }
}
