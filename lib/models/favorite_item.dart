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

  /// Status: 'want_to_try' or 'tasted'.
  final String status;

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
      status: json['status'] as String? ?? 'want_to_try',
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
      'status': status,
      'tries': tries.map((t) => t.toIso8601String()).toList(),
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields.
  ///
  /// To explicitly clear notes, pass an empty Optional: `notes: Optional.value(null)`.
  /// To keep existing notes, omit the parameter: `copyWith(status: 'tasted')`.
  FavoriteItem copyWith({
    String? id,
    String? status,
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
class Optional<T> {
  const Optional.value(this.value);

  final T value;
}
