/// Status values for favorite items in the festival log.
enum FavoriteStatus {
  /// Drink is on the 'want to try' list.
  wantToTry('want_to_try'),

  /// Drink has been tasted at least once.
  tasted('tasted');

  const FavoriteStatus(this.value);

  /// The string value used for JSON serialization.
  final String value;

  /// Creates a FavoriteStatus from a string value.
  static FavoriteStatus fromString(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => FavoriteStatus.wantToTry,
    );
  }
}

/// Represents a drink in the user's festival log.
///
/// Tracks whether a drink is on the 'want to try' list or has been tasted,
/// along with timestamps of tastings and optional notes.
class FavoriteItem {
  /// Creates a favorite item.
  const FavoriteItem({
    required this.id,
    required this.status,
    required this.tries,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Drink ID.
  final String id;

  /// Current status of this drink in the festival log.
  final FavoriteStatus status;

  /// List of tasting timestamps (empty if want_to_try).
  final List<DateTime> tries;

  /// Optional user notes.
  final String? notes;

  /// When this item was added to the log.
  final DateTime createdAt;

  /// When this item was last updated.
  final DateTime updatedAt;

  /// Creates a FavoriteItem from JSON.
  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      status: FavoriteStatus.fromString(
        json['status'] as String? ?? 'want_to_try',
      ),
      tries: (json['tries'] as List?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this item to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.value,
      'tries': tries.map((t) => t.toIso8601String()).toList(),
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields.
  ///
  /// To explicitly clear notes, pass an empty Optional: `notes: Optional.value(null)`.
  /// To keep existing notes, omit the parameter: `copyWith(status: FavoriteStatus.tasted)`.
  FavoriteItem copyWith({
    String? id,
    FavoriteStatus? status,
    List<DateTime>? tries,
    Optional<String?>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      status: status ?? this.status,
      tries: tries ?? this.tries,
      notes: notes != null ? notes.value : this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Equality comparison based on drink ID only.
  ///
  /// Two FavoriteItems are considered equal if they have the same id,
  /// regardless of status, tries, notes, or timestamps. This design
  /// allows FavoriteItem to be used in Sets and as Map keys where
  /// uniqueness is determined by the drink being tracked, not its
  /// specific state.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Wrapper class for explicitly passing null values in copyWith methods.
///
/// Used to distinguish between omitting a parameter (keep existing value)
/// and explicitly passing null (clear the value). This is particularly
/// useful for optional fields like notes where both "no change" and
/// "set to null" are valid operations.
///
/// Example usage:
/// ```dart
/// // Keep existing notes
/// item.copyWith(status: FavoriteStatus.tasted);
///
/// // Clear notes (set to null)
/// item.copyWith(notes: Optional.value(null));
///
/// // Set new notes value
/// item.copyWith(notes: Optional.value('Great beer!'));
/// ```
class Optional<T> {
  const Optional.value(this.value);

  final T value;
}
