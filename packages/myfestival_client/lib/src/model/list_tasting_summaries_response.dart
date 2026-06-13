//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:myfestival_client/src/model/tasting_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_tasting_summaries_response.g.dart';

/// Response message for ListTastingSummaries.
///
/// Properties:
/// * [tastingSummaries] - Tasting counts for this page, one per tried drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks tried by at least one caller at this festival.
@BuiltValue()
abstract class ListTastingSummariesResponse implements Built<ListTastingSummariesResponse, ListTastingSummariesResponseBuilder> {
  /// Tasting counts for this page, one per tried drink.
  @BuiltValueField(wireName: r'tastingSummaries')
  BuiltList<TastingSummary>? get tastingSummaries;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks tried by at least one caller at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListTastingSummariesResponse._();

  factory ListTastingSummariesResponse([void updates(ListTastingSummariesResponseBuilder b)]) = _$ListTastingSummariesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListTastingSummariesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListTastingSummariesResponse> get serializer => _$ListTastingSummariesResponseSerializer();
}

class _$ListTastingSummariesResponseSerializer implements PrimitiveSerializer<ListTastingSummariesResponse> {
  @override
  final Iterable<Type> types = const [ListTastingSummariesResponse, _$ListTastingSummariesResponse];

  @override
  final String wireName = r'ListTastingSummariesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListTastingSummariesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.tastingSummaries != null) {
      yield r'tastingSummaries';
      yield serializers.serialize(
        object.tastingSummaries,
        specifiedType: const FullType(BuiltList, [FullType(TastingSummary)]),
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
    ListTastingSummariesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListTastingSummariesResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'tastingSummaries':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TastingSummary)]),
          ) as BuiltList<TastingSummary>;
          result.tastingSummaries.replace(valueDes);
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
  ListTastingSummariesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListTastingSummariesResponseBuilder();
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

