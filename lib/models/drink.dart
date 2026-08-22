import 'beverage_categories.dart';
import 'user_drink_state.dart';

// The drinks feed is generated upstream by the festival, not by this app, and
// its shape varies per festival rather than over time: one winter feed quoted
// every `year_founded` and served a `dispense` value no summer feed had used.
//
// So the type-variant handling in the `fromJson` factories below is deliberate,
// and stays even for variants the currently-served feeds never emit. A census of
// every festival on the live registry (issue #349) confirmed the parsing is
// wider than today's data — and concluded to keep it that way, because the cost
// of an unexpected type is an empty drinks list on a festival day. Do not narrow
// these branches to match observed data; `docs/code/api/beer-list-schema.json`
// documents the shapes but is explicitly not a contract.

/// Fallback when the feed omits `dispense` entirely; cask is what the great
/// majority of a festival's stock is served from.
const String _defaultDispense = 'cask';

// Lenient readers.
//
// Every reader below is total: it coerces what it can, returns null otherwise,
// and never throws. That is the point. Parsing runs over a whole festival's
// catalogue in one pass, so a reader that throws on one odd value doesn't cost
// one drink — it costs the entire category. Keeping the policy here also keeps
// it consistent: before this, each field hand-rolled its own idea of how to
// read a loose value, and they quietly disagreed with each other.

/// Reads a value that should be text. Numbers and bools are stringified rather
/// than rejected — an `id` served as `12345` is still a usable id, and
/// refusing it would drop the drink for a purely cosmetic difference.
String? _readString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// Reads a value that should be a number. Feeds quote these about as often as
/// not — `abv` has been a string in every festival measured so far.
double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Reads a value that should be a whole number, quoted or not: `year_founded`
/// is quoted by winter feeds and unquoted by summer ones.
int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Reads a present/absent flag in any spelling the feed has used: bool, number,
/// or word. Returns null when the value carries no opinion either way.
bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return null;
}

/// Reads an allergen flag. Values are counts or booleans in practice; the empty
/// string every feed uses for 'absent' carries no number and is skipped by
/// returning null. Counts are preserved rather than flattened to 0/1, because
/// [Product.allergenText] distinguishes them.
int? _readAllergenFlag(Object? value) {
  if (value is bool) return value ? 1 : 0;
  return _readInt(value);
}

/// Parses a producer's product list, skipping entries that are not objects.
/// A malformed entry costs that one product, not its producer.
List<Product> _readProducts(Object? value) {
  if (value is! List) return const <Product>[];
  final products = <Product>[];
  for (final item in value) {
    if (item is! Map<String, dynamic>) continue;
    products.add(Product.fromJson(item));
  }
  return products;
}

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
      id: _readString(json['id']) ?? '',
      name: _readString(json['name']) ?? '',
      location: _readString(json['location']) ?? '',
      yearFounded: _readInt(json['year_founded']),
      notes: _readString(json['notes']),
      products: _readProducts(json['products']),
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
    final allergens = <String, int>{};
    final allergensRaw = json['allergens'];
    if (allergensRaw is Map) {
      for (final entry in allergensRaw.entries) {
        final key = entry.key;
        if (key is! String) continue;
        final flag = _readAllergenFlag(entry.value);
        if (flag != null) allergens[key] = flag;
      }
    }

    // A boolean `bar` means 'present at an unspecified bar' — `true` is not a
    // name, so it reads as no bar rather than the string "true".
    final barValue = json['bar'];

    return Product(
      id: _readString(json['id']) ?? '',
      name: _readString(json['name']) ?? '',
      category:
          _readString(json['category'])?.toLowerCase() ??
          BeverageCategories.defaultCategory,
      style: _readString(json['style']),
      dispense: _readString(json['dispense']) ?? _defaultDispense,
      abv: _readDouble(json['abv']) ?? 0.0,
      notes: _readString(json['notes']),
      statusText: _readString(json['status_text']),
      bar: barValue is bool ? null : _readString(barValue),
      allergens: allergens,
      // `vegan` is an unobserved legacy spelling kept as a fallback; see #349.
      isVegan: _readBool(json['is_vegan'] ?? json['vegan']),
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

  /// The user's personal record for this drink (want-to-try/favourite, rating,
  /// tasting events, notes, photos), or null when the user has no state for it.
  /// Hydrated onto the catalogue drink from the user-data store.
  final UserDrinkState? userState;

  static const _absent = Object();

  Drink({
    required this.product,
    required this.producer,
    required this.festivalId,
    this.userState,
  });

  Drink copyWith({Object? userState = _absent}) {
    return Drink(
      product: product,
      producer: producer,
      festivalId: festivalId,
      userState: identical(userState, _absent)
          ? this.userState
          : userState as UserDrinkState?,
    );
  }

  // --- Personal-state views (derived from [userState]) ---

  /// Whether the user has flagged this drink. Backed by the record's
  /// want-to-try flag (the Phase 1 "favourite"/bookmark).
  bool get isFavorite => userState?.wantToTry ?? false;

  /// The user's 1–5 rating, or null if unrated.
  int? get rating => userState?.rating;

  /// Whether the user has logged at least one tasting of this drink.
  bool get isTasted => userState?.isTasted ?? false;

  /// How many times the user has tasted this drink (0 when never).
  int get tastingCount => userState?.tastingCount ?? 0;

  /// The user's recorded tasting events (one per pour), or empty when never
  /// tasted. Order is not significant.
  List<DateTime> get tastingEvents => userState?.tastingEvents ?? const [];

  /// The user's personal free-text notes for this drink, or null if none.
  /// Distinct from [notes], which is the catalogue's tasting description.
  String? get userNotes => userState?.notes;

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
    final buffer = StringBuffer()
      ..write('Drinking $name from $breweryName at $hashtag');
    if (rating != null) {
      buffer.write(' - $rating stars');
    }
    if (url != null) {
      buffer.write('\n$url');
    }
    return buffer.toString();
  }
}
