// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasting.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Tasting extends Tasting {
  @override
  final String? name;
  @override
  final int? pours;
  @override
  final DateTime? createTime;
  @override
  final DateTime? updateTime;

  factory _$Tasting([void Function(TastingBuilder)? updates]) =>
      (TastingBuilder()..update(updates))._build();

  _$Tasting._({this.name, this.pours, this.createTime, this.updateTime})
      : super._();
  @override
  Tasting rebuild(void Function(TastingBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TastingBuilder toBuilder() => TastingBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Tasting &&
        name == other.name &&
        pours == other.pours &&
        createTime == other.createTime &&
        updateTime == other.updateTime;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, pours.hashCode);
    _$hash = $jc(_$hash, createTime.hashCode);
    _$hash = $jc(_$hash, updateTime.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Tasting')
          ..add('name', name)
          ..add('pours', pours)
          ..add('createTime', createTime)
          ..add('updateTime', updateTime))
        .toString();
  }
}

class TastingBuilder implements Builder<Tasting, TastingBuilder> {
  _$Tasting? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _pours;
  int? get pours => _$this._pours;
  set pours(int? pours) => _$this._pours = pours;

  DateTime? _createTime;
  DateTime? get createTime => _$this._createTime;
  set createTime(DateTime? createTime) => _$this._createTime = createTime;

  DateTime? _updateTime;
  DateTime? get updateTime => _$this._updateTime;
  set updateTime(DateTime? updateTime) => _$this._updateTime = updateTime;

  TastingBuilder() {
    Tasting._defaults(this);
  }

  TastingBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _pours = $v.pours;
      _createTime = $v.createTime;
      _updateTime = $v.updateTime;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Tasting other) {
    _$v = other as _$Tasting;
  }

  @override
  void update(void Function(TastingBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Tasting build() => _build();

  _$Tasting _build() {
    final _$result = _$v ??
        _$Tasting._(
          name: name,
          pours: pours,
          createTime: createTime,
          updateTime: updateTime,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
