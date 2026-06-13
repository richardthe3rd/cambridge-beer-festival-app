//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tasting.g.dart';

/// A record that the caller has tried a drink at a festival.   Singleton resource — one per (caller, drink). The caller is implicit in the  auth context. `pours` tracks how many times the caller has had this drink at  the festival (e.g. returned for a second half-pint); absent means one pour.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/drinks/{drink}/tasting.
/// * [pours] - How many times the caller has had this drink. Absent means one pour.  Must be >= 1 when present.
/// * [createTime] - When the caller first tried this drink.
/// * [updateTime] - When this record was last updated.
@BuiltValue()
abstract class Tasting implements Built<Tasting, TastingBuilder> {
  /// Resource name: festivals/{festival}/drinks/{drink}/tasting.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// How many times the caller has had this drink. Absent means one pour.  Must be >= 1 when present.
  @BuiltValueField(wireName: r'pours')
  int? get pours;

  /// When the caller first tried this drink.
  @BuiltValueField(wireName: r'createTime')
  DateTime? get createTime;

  /// When this record was last updated.
  @BuiltValueField(wireName: r'updateTime')
  DateTime? get updateTime;

  Tasting._();

  factory Tasting([void updates(TastingBuilder b)]) = _$Tasting;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TastingBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Tasting> get serializer => _$TastingSerializer();
}

class _$TastingSerializer implements PrimitiveSerializer<Tasting> {
  @override
  final Iterable<Type> types = const [Tasting, _$Tasting];

  @override
  final String wireName = r'Tasting';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Tasting object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.pours != null) {
      yield r'pours';
      yield serializers.serialize(
        object.pours,
        specifiedType: const FullType(int),
      );
    }
    if (object.createTime != null) {
      yield r'createTime';
      yield serializers.serialize(
        object.createTime,
        specifiedType: const FullType(DateTime),
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
    Tasting object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TastingBuilder result,
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
        case r'pours':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.pours = valueDes;
          break;
        case r'createTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createTime = valueDes;
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
  Tasting deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TastingBuilder();
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

