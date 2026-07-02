import 'package:collection/collection.dart';

/// Unified per-drink-per-festival user state record.
///
/// Combines what were previously separate services (favourites, ratings,
/// tasting log) into one immutable value object that tracks all user intent and
/// history for a single drink at a single festival.
class UserDrinkState {
  /// Whether the user has marked this drink as "want to try" (the Phase 1
  /// "favourite"/bookmark).
  final bool wantToTry;

  /// Tasting events, one entry per pour/session, in the order supplied.
  /// Order is not significant — [lastTastedAt] derives the latest event
  /// independently — so callers need not pre-sort. May be empty.
  final List<DateTime> tastingEvents;

  /// Overall rating (1–5), or null if unrated.
  final int? rating;

  /// Free text notes, or null if none.
  final String? notes;

  /// Photo IDs (not file paths), may be empty.
  final List<String> photoIds;

  /// When this record was first created.
  final DateTime createdAt;

  /// When this record was last updated.
  final DateTime updatedAt;

  /// Sentinel for copyWith null semantics.
  static const Object _sentinel = Object();

  UserDrinkState({
    this.wantToTry = false,
    List<DateTime>? tastingEvents,
    this.rating,
    this.notes,
    List<String>? photoIds,
    required this.createdAt,
    required this.updatedAt,
  }) : tastingEvents = List.unmodifiable(
         (tastingEvents ?? const []).map(_toMillisPrecision),
       ),
       photoIds = List.unmodifiable(photoIds ?? const []);

  /// Tasting events are deleted by matching a timestamp against the stored
  /// list, but persistence round-trips through `millisecondsSinceEpoch` in
  /// local time (see [toJson]/[fromJson]). A `DateTime.now()` on the VM carries
  /// microseconds, so an in-memory event would never equal its persisted,
  /// millisecond-truncated form — a same-session delete would silently miss.
  /// Normalising every event to local millisecond precision on construction
  /// keeps in-memory events equal to their reloaded form.
  static DateTime _toMillisPrecision(DateTime dt) =>
      DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch);

  /// Returns an empty record with createdAt/updatedAt set to [now] (or
  /// `DateTime.now()`).
  factory UserDrinkState.initial({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return UserDrinkState(createdAt: timestamp, updatedAt: timestamp);
  }

  /// Whether this record has any tasting events.
  bool get isTasted => tastingEvents.isNotEmpty;

  /// Number of tasting events recorded.
  int get tastingCount => tastingEvents.length;

  /// The most recent tasting event, or null if none.
  DateTime? get lastTastedAt {
    if (tastingEvents.isEmpty) return null;
    return tastingEvents.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// True when the record carries NO user signal: not want-to-try, no tastings,
  /// no rating, no (non-empty) notes, and no photos. The store prunes empty
  /// records so they leave no key behind.
  bool get isEmpty =>
      !wantToTry &&
      tastingEvents.isEmpty &&
      rating == null &&
      (notes == null || notes!.isEmpty) &&
      photoIds.isEmpty;

  /// Returns a copy with any specified fields replaced.
  ///
  /// Uses a sentinel for [rating] and [notes] so callers can explicitly clear
  /// them (pass null) versus leave them unchanged (omit the argument).
  UserDrinkState copyWith({
    bool? wantToTry,
    List<DateTime>? tastingEvents,
    Object? rating = _sentinel,
    Object? notes = _sentinel,
    List<String>? photoIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserDrinkState(
      wantToTry: wantToTry ?? this.wantToTry,
      tastingEvents: tastingEvents ?? List.of(this.tastingEvents),
      rating: identical(rating, _sentinel) ? this.rating : rating as int?,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      photoIds: photoIds ?? List.of(this.photoIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serialises to JSON for storage. DateTimes are stored as
  /// millisecondsSinceEpoch integers.
  Map<String, dynamic> toJson() {
    return {
      'wantToTry': wantToTry,
      'tastingEvents': tastingEvents
          .map((e) => e.millisecondsSinceEpoch)
          .toList(),
      'rating': rating,
      'notes': notes,
      'photoIds': photoIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Deserialises from JSON, handling missing/null fields defensively.
  factory UserDrinkState.fromJson(Map<String, dynamic> json) {
    return UserDrinkState(
      wantToTry: json['wantToTry'] as bool? ?? false,
      tastingEvents:
          (json['tastingEvents'] as List?)
              ?.map(
                (e) => DateTime.fromMillisecondsSinceEpoch((e as num).toInt()),
              )
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      photoIds:
          (json['photoIds'] as List?)?.map((e) => e as String).toList() ??
          const [],
      // Parse as num: on web (dart2js) jsonDecode can hand back whole-number
      // millis as double, and `as int` would throw — dropping the whole record.
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserDrinkState &&
        wantToTry == other.wantToTry &&
        const ListEquality<DateTime>().equals(
          tastingEvents,
          other.tastingEvents,
        ) &&
        rating == other.rating &&
        notes == other.notes &&
        const ListEquality<String>().equals(photoIds, other.photoIds) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    wantToTry,
    const ListEquality<DateTime>().hash(tastingEvents),
    rating,
    notes,
    const ListEquality<String>().hash(photoIds),
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'UserDrinkState(wantToTry: $wantToTry, tastingCount: $tastingCount, '
      'lastTastedAt: $lastTastedAt, rating: $rating, notes: $notes, '
      'photoIds: $photoIds, createdAt: $createdAt, updatedAt: $updatedAt)';
}
