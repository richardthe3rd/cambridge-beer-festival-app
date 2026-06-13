//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bookmark.g.dart';

/// A drink the caller has bookmarked at a festival.   Singleton resource — one per (caller, drink). The resource's mere existence  means the drink is bookmarked; deleting it removes the bookmark. The caller  is implicit in the auth context.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/drinks/{drink}/bookmark.
/// * [createTime] - When the bookmark was created.
@BuiltValue()
abstract class Bookmark implements Built<Bookmark, BookmarkBuilder> {
  /// Resource name: festivals/{festival}/drinks/{drink}/bookmark.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// When the bookmark was created.
  @BuiltValueField(wireName: r'createTime')
  DateTime? get createTime;

  Bookmark._();

  factory Bookmark([void updates(BookmarkBuilder b)]) = _$Bookmark;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BookmarkBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Bookmark> get serializer => _$BookmarkSerializer();
}

class _$BookmarkSerializer implements PrimitiveSerializer<Bookmark> {
  @override
  final Iterable<Type> types = const [Bookmark, _$Bookmark];

  @override
  final String wireName = r'Bookmark';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Bookmark object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.createTime != null) {
      yield r'createTime';
      yield serializers.serialize(
        object.createTime,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Bookmark object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BookmarkBuilder result,
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
        case r'createTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createTime = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Bookmark deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BookmarkBuilder();
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

