//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myfestival_client/src/model/bookmark.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'list_bookmarks_response.g.dart';

/// Response message for ListBookmarks.
///
/// Properties:
/// * [bookmarks] - The caller's bookmarks for this page, one per bookmarked drink.
/// * [nextPageToken] - Token for the next page; empty when there are no more results.
/// * [totalSize] - Total number of drinks the caller has bookmarked at this festival.
@BuiltValue()
abstract class ListBookmarksResponse implements Built<ListBookmarksResponse, ListBookmarksResponseBuilder> {
  /// The caller's bookmarks for this page, one per bookmarked drink.
  @BuiltValueField(wireName: r'bookmarks')
  BuiltList<Bookmark>? get bookmarks;

  /// Token for the next page; empty when there are no more results.
  @BuiltValueField(wireName: r'nextPageToken')
  String? get nextPageToken;

  /// Total number of drinks the caller has bookmarked at this festival.
  @BuiltValueField(wireName: r'totalSize')
  int? get totalSize;

  ListBookmarksResponse._();

  factory ListBookmarksResponse([void updates(ListBookmarksResponseBuilder b)]) = _$ListBookmarksResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListBookmarksResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListBookmarksResponse> get serializer => _$ListBookmarksResponseSerializer();
}

class _$ListBookmarksResponseSerializer implements PrimitiveSerializer<ListBookmarksResponse> {
  @override
  final Iterable<Type> types = const [ListBookmarksResponse, _$ListBookmarksResponse];

  @override
  final String wireName = r'ListBookmarksResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListBookmarksResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.bookmarks != null) {
      yield r'bookmarks';
      yield serializers.serialize(
        object.bookmarks,
        specifiedType: const FullType(BuiltList, [FullType(Bookmark)]),
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
    ListBookmarksResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListBookmarksResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'bookmarks':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Bookmark)]),
          ) as BuiltList<Bookmark>;
          result.bookmarks.replace(valueDes);
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
  ListBookmarksResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListBookmarksResponseBuilder();
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

