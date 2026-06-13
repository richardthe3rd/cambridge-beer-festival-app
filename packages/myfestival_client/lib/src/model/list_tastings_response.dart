//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:myfestival_client/src/model/tasting.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_tastings_response.g.dart';

/// Response message for ListTastings.
///
/// Properties:
/// * [tastings] - The caller's tasting records for this page, one per tried drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks the caller has tried at this festival.
@BuiltValue()
abstract class ListTastingsResponse implements Built<ListTastingsResponse, ListTastingsResponseBuilder> {
  /// The caller's tasting records for this page, one per tried drink.
  @BuiltValueField(wireName: r'tastings')
  BuiltList<Tasting>? get tastings;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks the caller has tried at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListTastingsResponse._();

  factory ListTastingsResponse([void updates(ListTastingsResponseBuilder b)]) = _$ListTastingsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListTastingsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListTastingsResponse> get serializer => _$ListTastingsResponseSerializer();
}

class _$ListTastingsResponseSerializer implements PrimitiveSerializer<ListTastingsResponse> {
  @override
  final Iterable<Type> types = const [ListTastingsResponse, _$ListTastingsResponse];

  @override
  final String wireName = r'ListTastingsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListTastingsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.tastings != null) {
      yield r'tastings';
      yield serializers.serialize(
        object.tastings,
        specifiedType: const FullType(BuiltList, [FullType(Tasting)]),
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
    ListTastingsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListTastingsResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'tastings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Tasting)]),
          ) as BuiltList<Tasting>;
          result.tastings.replace(valueDes);
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
  ListTastingsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListTastingsResponseBuilder();
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

