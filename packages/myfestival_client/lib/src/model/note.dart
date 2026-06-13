//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'note.g.dart';

/// The caller's free-text tasting note for one drink at one festival.   Singleton resource — one per (caller, drink). The caller is implicit in the  auth context. A note is independent of a Review: you can note without rating,  or rate without noting.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/drinks/{drink}/note.
/// * [content] - The caller's note text. Max 2000 Unicode characters.
/// * [updateTime] - When this note was last written.
@BuiltValue()
abstract class Note implements Built<Note, NoteBuilder> {
  /// Resource name: festivals/{festival}/drinks/{drink}/note.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// The caller's note text. Max 2000 Unicode characters.
  @BuiltValueField(wireName: r'content')
  String get content;

  /// When this note was last written.
  @BuiltValueField(wireName: r'updateTime')
  DateTime? get updateTime;

  Note._();

  factory Note([void updates(NoteBuilder b)]) = _$Note;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NoteBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Note> get serializer => _$NoteSerializer();
}

class _$NoteSerializer implements PrimitiveSerializer<Note> {
  @override
  final Iterable<Type> types = const [Note, _$Note];

  @override
  final String wireName = r'Note';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Note object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    yield r'content';
    yield serializers.serialize(
      object.content,
      specifiedType: const FullType(String),
    );
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
    Note object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NoteBuilder result,
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
        case r'content':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.content = valueDes;
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
  Note deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NoteBuilder();
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

