//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myfestival_client/src/model/review_summary.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_review_summaries_response.g.dart';

/// Response message for ListReviewSummaries.
///
/// Properties:
/// * [reviewSummaries] - Aggregate review signals for this page, one per reviewed drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks with at least one review at this festival.
@BuiltValue()
abstract class ListReviewSummariesResponse implements Built<ListReviewSummariesResponse, ListReviewSummariesResponseBuilder> {
  /// Aggregate review signals for this page, one per reviewed drink.
  @BuiltValueField(wireName: r'reviewSummaries')
  BuiltList<ReviewSummary>? get reviewSummaries;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks with at least one review at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListReviewSummariesResponse._();

  factory ListReviewSummariesResponse([void updates(ListReviewSummariesResponseBuilder b)]) = _$ListReviewSummariesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListReviewSummariesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListReviewSummariesResponse> get serializer => _$ListReviewSummariesResponseSerializer();
}

class _$ListReviewSummariesResponseSerializer implements PrimitiveSerializer<ListReviewSummariesResponse> {
  @override
  final Iterable<Type> types = const [ListReviewSummariesResponse, _$ListReviewSummariesResponse];

  @override
  final String wireName = r'ListReviewSummariesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListReviewSummariesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.reviewSummaries != null) {
      yield r'reviewSummaries';
      yield serializers.serialize(
        object.reviewSummaries,
        specifiedType: const FullType(BuiltList, [FullType(ReviewSummary)]),
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
    ListReviewSummariesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListReviewSummariesResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'reviewSummaries':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ReviewSummary)]),
          ) as BuiltList<ReviewSummary>;
          result.reviewSummaries.replace(valueDes);
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
  ListReviewSummariesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListReviewSummariesResponseBuilder();
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

