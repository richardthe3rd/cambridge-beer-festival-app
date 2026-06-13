//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myfestival_client/src/model/note.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_notes_response.g.dart';

/// Response message for ListNotes.
///
/// Properties:
/// * [notes] - The caller's notes for this page, one per noted drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks the caller has notes for at this festival.
@BuiltValue()
abstract class ListNotesResponse implements Built<ListNotesResponse, ListNotesResponseBuilder> {
  /// The caller's notes for this page, one per noted drink.
  @BuiltValueField(wireName: r'notes')
  BuiltList<Note>? get notes;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks the caller has notes for at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListNotesResponse._();

  factory ListNotesResponse([void updates(ListNotesResponseBuilder b)]) = _$ListNotesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListNotesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListNotesResponse> get serializer => _$ListNotesResponseSerializer();
}

class _$ListNotesResponseSerializer implements PrimitiveSerializer<ListNotesResponse> {
  @override
  final Iterable<Type> types = const [ListNotesResponse, _$ListNotesResponse];

  @override
  final String wireName = r'ListNotesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListNotesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.notes != null) {
      yield r'notes';
      yield serializers.serialize(
        object.notes,
        specifiedType: const FullType(BuiltList, [FullType(Note)]),
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
    ListNotesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListNotesResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'notes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Note)]),
          ) as BuiltList<Note>;
          result.notes.replace(valueDes);
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
  ListNotesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListNotesResponseBuilder();
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

