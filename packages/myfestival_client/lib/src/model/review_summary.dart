//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'review_summary.g.dart';

/// Computed, read-only aggregate of all callers' reviews for one drink.   Keyed by drink under the festival so the whole festival can be fetched in  one paginated call for list/grid views.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/reviewSummaries/{drink}.
/// * [ratingCount] - Number of callers who have submitted a star rating.
/// * [averageRating] - Mean star rating across all callers (1.0–5.0); 0 when rating_count is 0.
/// * [responseCount] - Number of callers who have answered the \"would recommend\" question.
/// * [recommendCount] - Number of callers who answered \"yes\" to the recommendation question.
/// * [recommendRate] - Fraction of responses (0.0–1.0) that would recommend; 0 when  response_count is 0.
@BuiltValue()
abstract class ReviewSummary implements Built<ReviewSummary, ReviewSummaryBuilder> {
  /// Resource name: festivals/{festival}/reviewSummaries/{drink}.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// Number of callers who have submitted a star rating.
  @BuiltValueField(wireName: r'ratingCount')
  int? get ratingCount;

  /// Mean star rating across all callers (1.0–5.0); 0 when rating_count is 0.
  @BuiltValueField(wireName: r'averageRating')
  double? get averageRating;

  /// Number of callers who have answered the \"would recommend\" question.
  @BuiltValueField(wireName: r'responseCount')
  int? get responseCount;

  /// Number of callers who answered \"yes\" to the recommendation question.
  @BuiltValueField(wireName: r'recommendCount')
  int? get recommendCount;

  /// Fraction of responses (0.0–1.0) that would recommend; 0 when  response_count is 0.
  @BuiltValueField(wireName: r'recommendRate')
  double? get recommendRate;

  ReviewSummary._();

  factory ReviewSummary([void updates(ReviewSummaryBuilder b)]) = _$ReviewSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReviewSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReviewSummary> get serializer => _$ReviewSummarySerializer();
}

class _$ReviewSummarySerializer implements PrimitiveSerializer<ReviewSummary> {
  @override
  final Iterable<Type> types = const [ReviewSummary, _$ReviewSummary];

  @override
  final String wireName = r'ReviewSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReviewSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.ratingCount != null) {
      yield r'ratingCount';
      yield serializers.serialize(
        object.ratingCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.averageRating != null) {
      yield r'averageRating';
      yield serializers.serialize(
        object.averageRating,
        specifiedType: const FullType(double),
      );
    }
    if (object.responseCount != null) {
      yield r'responseCount';
      yield serializers.serialize(
        object.responseCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.recommendCount != null) {
      yield r'recommendCount';
      yield serializers.serialize(
        object.recommendCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.recommendRate != null) {
      yield r'recommendRate';
      yield serializers.serialize(
        object.recommendRate,
        specifiedType: const FullType(double),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ReviewSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReviewSummaryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'ratingCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.ratingCount = valueDes;
          break;
        case r'averageRating':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(double),
          ) as double;
          result.averageRating = valueDes;
          break;
        case r'responseCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.responseCount = valueDes;
          break;
        case r'recommendCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.recommendCount = valueDes;
          break;
        case r'recommendRate':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(double),
          ) as double;
          result.recommendRate = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ReviewSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReviewSummaryBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

