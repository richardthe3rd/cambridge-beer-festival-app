//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tasting_summary.g.dart';

/// Computed, read-only aggregate of how many callers have tried a drink.   Useful for social discovery (\"N people have tried this\"). Keyed by drink  under the festival, matching the ReviewSummary pattern.
///
/// Properties:
/// * [name] - Resource name: festivals/{festival}/tastingSummaries/{drink}.
/// * [tasterCount] - Number of distinct callers who have logged a tasting for this drink.
/// * [totalPours] - Total pours logged across all callers.
@BuiltValue()
abstract class TastingSummary implements Built<TastingSummary, TastingSummaryBuilder> {
  /// Resource name: festivals/{festival}/tastingSummaries/{drink}.
  @BuiltValueField(wireName: r'name')
  String? get name;

  /// Number of distinct callers who have logged a tasting for this drink.
  @BuiltValueField(wireName: r'tasterCount')
  int? get tasterCount;

  /// Total pours logged across all callers.
  @BuiltValueField(wireName: r'totalPours')
  int? get totalPours;

  TastingSummary._();

  factory TastingSummary([void updates(TastingSummaryBuilder b)]) = _$TastingSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TastingSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TastingSummary> get serializer => _$TastingSummarySerializer();
}

class _$TastingSummarySerializer implements PrimitiveSerializer<TastingSummary> {
  @override
  final Iterable<Type> types = const [TastingSummary, _$TastingSummary];

  @override
  final String wireName = r'TastingSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TastingSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.tasterCount != null) {
      yield r'tasterCount';
      yield serializers.serialize(
        object.tasterCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.totalPours != null) {
      yield r'totalPours';
      yield serializers.serialize(
        object.totalPours,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    TastingSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TastingSummaryBuilder result,
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
        case r'tasterCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.tasterCount = valueDes;
          break;
        case r'totalPours':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalPours = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TastingSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TastingSummaryBuilder();
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

