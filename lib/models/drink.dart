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
    return Producer(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String? ?? '',
      yearFounded: json['year_founded'] as int?,
      notes: json['notes'] as String?,
      products: (json['products'] as List<dynamic>?)
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

    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'beer',
      style: json['style'] as String?,
      dispense: json['dispense'] as String? ?? 'cask',
      abv: parsedAbv,
      notes: json['notes'] as String?,
      statusText: json['status_text'] as String?,
      bar: json['bar'] is String ? json['bar'] as String : null,
      allergens: (json['allergens'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as int)) ??
          {},
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
    };
  }

  /// Returns the availability status for display
  AvailabilityStatus? get availabilityStatus {
    if (statusText == null) return null;
    final lower = statusText!.toLowerCase();
    if (lower.contains('plenty') ||
        lower.contains('arrived') ||
        lower.contains('available')) {
      return AvailabilityStatus.plenty;
    }
    if (lower.contains('remaining') ||
        lower.contains('nearly') ||
        lower.contains('low')) {
      return AvailabilityStatus.low;
    }
    if (lower.contains('out') || lower.contains('sold')) {
      return AvailabilityStatus.out;
    }
    return AvailabilityStatus.plenty;
  }

  /// Returns allergen list as a formatted string
  String? get allergenText {
    if (allergens.isEmpty) return null;
    final allergenList =
        allergens.entries.where((e) => e.value == 1 && e.key.isNotEmpty).map((e) {
      // Capitalize first letter
      return e.key[0].toUpperCase() + e.key.substring(1);
    }).toList();
    if (allergenList.isEmpty) return null;
    return allergenList.join(', ');
  }
}

/// Availability status for a product
enum AvailabilityStatus {
  plenty,
  low,
  out,
}

/// Extended drink model that includes producer information
class Drink {
  final Product product;
  final Producer producer;
  final String festivalId;
  bool isFavorite;
  int? rating;

  Drink({
    required this.product,
    required this.producer,
    required this.festivalId,
    this.isFavorite = false,
    this.rating,
  });

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
}
