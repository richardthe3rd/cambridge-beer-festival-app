//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'review.g.dart';

/// The caller's review of one drink at one festival: a star rating (1-5) and/or  a \"would recommend\" answer.   Singleton resource — one per (caller, drink). The caller is implicit in the  auth context; their identity never appears in the resource name, keeping  device IDs private and making the sign-in upgrade transparent to clients.   Both signals are optional and independent: a caller can rate without  answering the recommendation question, or vice versa.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/drinks/{drink}/review.
/// * [starRating] - Star rating, 1–5 inclusive. Absent if the caller has not set a star rating.
/// * [wouldRecommend] - Whether the caller would recommend this drink. Absent if not answered.
/// * [updateTime] - When this review was last written.
@BuiltValue()
abstract class Review implements Built<Review, ReviewBuilder> {
  /// Resource name: festivals/{festival}/drinks/{drink}/review.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// Star rating, 1–5 inclusive. Absent if the caller has not set a star rating.
  @BuiltValueField(wireName: r'starRating')
  int? get starRating;

  /// Whether the caller would recommend this drink. Absent if not answered.
  @BuiltValueField(wireName: r'wouldRecommend')
  bool? get wouldRecommend;

  /// When this review was last written.
  @BuiltValueField(wireName: r'updateTime')
  DateTime? get updateTime;

  Review._();

  factory Review([void updates(ReviewBuilder b)]) = _$Review;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReviewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Review> get serializer => _$ReviewSerializer();
}

class _$ReviewSerializer implements PrimitiveSerializer<Review> {
  @override
  final Iterable<Type> types = const [Review, _$Review];

  @override
  final String wireName = r'Review';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Review object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.starRating != null) {
      yield r'starRating';
      yield serializers.serialize(
        object.starRating,
        specifiedType: const FullType(int),
      );
    }
    if (object.wouldRecommend != null) {
      yield r'wouldRecommend';
      yield serializers.serialize(
        object.wouldRecommend,
        specifiedType: const FullType(bool),
      );
    }
    if (object.updateTime != null) {
      yield r'updateTime';
      yield serializers.serialize(
        object.updateTime,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Review object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReviewBuilder result,
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
        case r'starRating':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.starRating = valueDes;
          break;
        case r'wouldRecommend':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.wouldRecommend = valueDes;
          break;
        case r'updateTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updateTime = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Review deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReviewBuilder();
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

