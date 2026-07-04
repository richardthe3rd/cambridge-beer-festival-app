import 'package:collection/collection.dart';

/// A single **My Festival check-in** — the primary My Festival entity (ADR
/// 0006). A festival-scoped, timestamped record that _optionally_ references a
/// drink.
///
/// The kind is **derived, not stored**: [isTasting] is `drinkId != null`. A
/// tasting carries the full set (rating/recommend/note/photos); a freeform
/// `other` entry (null [drinkId]) has a [title] plus optional note/photos and no
/// rating/recommend. There is deliberately no separate `kind` field to drift out
/// of sync with [drinkId].
///
/// Identity is a stable [id] (a UUID) assigned once and never changed; edit and
/// delete key off it. [when] is user-editable and defaults to "now" but can be
/// backdated, so it can never be the identity.
class LogEntry {
  /// Stable UUID identity, assigned once on creation.
  final String id;

  /// When the check-in happened. User-editable; normalised to millisecond
  /// precision to match the persisted form.
  final DateTime when;

  /// The drink this entry references, or null for a freeform `other` entry.
  /// Non-null makes this entry a tasting ([isTasting]).
  final String? drinkId;

  /// Freeform label for an `other` entry (e.g. "Scotch egg from the pie
  /// stall"). Null for tastings.
  final String? title;

  /// Free-text note for any entry, or null.
  final String? note;

  /// Photo IDs (not file paths), may be empty. Any entry (#416).
  final List<String> photoIds;

  /// Rating (1–5) for a tasting, or null. Meaningful only when [isTasting].
  final int? rating;

  /// Whether the user would recommend this tasting, or null (#417). Meaningful
  /// only when [isTasting].
  final bool? wouldRecommend;

  /// Sentinel for copyWith null semantics.
  static const Object _sentinel = Object();

  LogEntry({
    required this.id,
    required DateTime when,
    this.drinkId,
    this.title,
    this.note,
    List<String>? photoIds,
    this.rating,
    this.wouldRecommend,
  }) : when = _toMillisPrecision(when),
       photoIds = List.unmodifiable(photoIds ?? const []);

  /// Persistence round-trips [when] through `millisecondsSinceEpoch`, so a
  /// `DateTime.now()` (which carries microseconds) would never equal its
  /// reloaded form. Normalise on construction so in-memory entries compare
  /// equal to their persisted form (matches [UserDrinkState]'s tasting-event
  /// handling).
  static DateTime _toMillisPrecision(DateTime dt) =>
      DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch);

  /// A tasting is a drink-kind check-in. Derived from [drinkId] — there is no
  /// stored kind (ADR 0006).
  bool get isTasting => drinkId != null;

  /// Returns a copy with any specified fields replaced. Nullable fields use a
  /// sentinel so callers can explicitly clear them (pass null) versus leave
  /// them unchanged (omit the argument).
  LogEntry copyWith({
    String? id,
    DateTime? when,
    Object? drinkId = _sentinel,
    Object? title = _sentinel,
    Object? note = _sentinel,
    List<String>? photoIds,
    Object? rating = _sentinel,
    Object? wouldRecommend = _sentinel,
  }) {
    return LogEntry(
      id: id ?? this.id,
      when: when ?? this.when,
      drinkId: identical(drinkId, _sentinel)
          ? this.drinkId
          : drinkId as String?,
      title: identical(title, _sentinel) ? this.title : title as String?,
      note: identical(note, _sentinel) ? this.note : note as String?,
      photoIds: photoIds ?? List.of(this.photoIds),
      rating: identical(rating, _sentinel) ? this.rating : rating as int?,
      wouldRecommend: identical(wouldRecommend, _sentinel)
          ? this.wouldRecommend
          : wouldRecommend as bool?,
    );
  }

  /// Serialises to JSON for storage. [when] is stored as
  /// millisecondsSinceEpoch.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'when': when.millisecondsSinceEpoch,
      'drinkId': drinkId,
      'title': title,
      'note': note,
      'photoIds': photoIds,
      'rating': rating,
      'wouldRecommend': wouldRecommend,
    };
  }

  /// Deserialises from JSON, handling missing/null fields defensively.
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      // Parse as num: on web (dart2js) jsonDecode can hand back whole-number
      // millis as double, and `as int` would throw — dropping the record.
      when: DateTime.fromMillisecondsSinceEpoch(
        (json['when'] as num?)?.toInt() ?? 0,
      ),
      drinkId: json['drinkId'] as String?,
      title: json['title'] as String?,
      note: json['note'] as String?,
      photoIds:
          (json['photoIds'] as List?)?.map((e) => e as String).toList() ??
          const [],
      rating: (json['rating'] as num?)?.toInt(),
      wouldRecommend: json['wouldRecommend'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogEntry &&
        id == other.id &&
        when == other.when &&
        drinkId == other.drinkId &&
        title == other.title &&
        note == other.note &&
        const ListEquality<String>().equals(photoIds, other.photoIds) &&
        rating == other.rating &&
        wouldRecommend == other.wouldRecommend;
  }

  @override
  int get hashCode => Object.hash(
    id,
    when,
    drinkId,
    title,
    note,
    const ListEquality<String>().hash(photoIds),
    rating,
    wouldRecommend,
  );

  @override
  String toString() =>
      'LogEntry(id: $id, when: $when, drinkId: $drinkId, title: $title, '
      'note: $note, photoIds: $photoIds, rating: $rating, '
      'wouldRecommend: $wouldRecommend)';
}
