// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasting_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TastingSummary extends TastingSummary {
  @override
  final String? name;
  @override
  final int? tasterCount;
  @override
  final int? totalPours;

  factory _$TastingSummary([void Function(TastingSummaryBuilder)? updates]) =>
      (TastingSummaryBuilder()..update(updates))._build();

  _$TastingSummary._({this.name, this.tasterCount, this.totalPours})
      : super._();
  @override
  TastingSummary rebuild(void Function(TastingSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TastingSummaryBuilder toBuilder() => TastingSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TastingSummary &&
        name == other.name &&
        tasterCount == other.tasterCount &&
        totalPours == other.totalPours;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, tasterCount.hashCode);
    _$hash = $jc(_$hash, totalPours.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TastingSummary')
          ..add('name', name)
          ..add('tasterCount', tasterCount)
          ..add('totalPours', totalPours))
        .toString();
  }
}

class TastingSummaryBuilder
    implements Builder<TastingSummary, TastingSummaryBuilder> {
  _$TastingSummary? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _tasterCount;
  int? get tasterCount => _$this._tasterCount;
  set tasterCount(int? tasterCount) => _$this._tasterCount = tasterCount;

  int? _totalPours;
  int? get totalPours => _$this._totalPours;
  set totalPours(int? totalPours) => _$this._totalPours = totalPours;

  TastingSummaryBuilder() {
    TastingSummary._defaults(this);
  }

  TastingSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _tasterCount = $v.tasterCount;
      _totalPours = $v.totalPours;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TastingSummary other) {
    _$v = other as _$TastingSummary;
  }

  @override
  void update(void Function(TastingSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TastingSummary build() => _build();

  _$TastingSummary _build() {
    final _$result = _$v ??
        _$TastingSummary._(
          name: name,
          tasterCount: tasterCount,
          totalPours: totalPours,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
