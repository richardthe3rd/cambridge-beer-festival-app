//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:myfestival_client/src/model/review.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_reviews_response.g.dart';

/// Response message for ListReviews.
///
/// Properties:
/// * [reviews] - The caller's reviews for this page, one per reviewed drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks the caller has reviewed at this festival.
@BuiltValue()
abstract class ListReviewsResponse implements Built<ListReviewsResponse, ListReviewsResponseBuilder> {
  /// The caller's reviews for this page, one per reviewed drink.
  @BuiltValueField(wireName: r'reviews')
  BuiltList<Review>? get reviews;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks the caller has reviewed at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListReviewsResponse._();

  factory ListReviewsResponse([void updates(ListReviewsResponseBuilder b)]) = _$ListReviewsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListReviewsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListReviewsResponse> get serializer => _$ListReviewsResponseSerializer();
}

class _$ListReviewsResponseSerializer implements PrimitiveSerializer<ListReviewsResponse> {
  @override
  final Iterable<Type> types = const [ListReviewsResponse, _$ListReviewsResponse];

  @override
  final String wireName = r'ListReviewsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListReviewsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.reviews != null) {
      yield r'reviews';
      yield serializers.serialize(
        object.reviews,
        specifiedType: const FullType(BuiltList, [FullType(Review)]),
      );
    }
    if (object.nextPageToken != null) {
      yield r'nextPageToken';
      yield serializers.serialize(
        object.nextPageToken,
        specifiedType: const FullType(String),
      );
    }
    if (object.totalSize != null) {
      yield r'totalSize';
      yield serializers.serialize(
        object.totalSize,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ListReviewsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListReviewsResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'reviews':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Review)]),
          ) as BuiltList<Review>;
          result.reviews.replace(valueDes);
          break;
        case r'nextPageToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nextPageToken = valueDes;
          break;
        case r'totalSize':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListReviewsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListReviewsResponseBuilder();
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

