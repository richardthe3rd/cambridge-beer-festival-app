// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_tastings_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListTastingsResponse extends ListTastingsResponse {
  @override
  final BuiltList<Tasting>? tastings;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListTastingsResponse(
          [void Function(ListTastingsResponseBuilder)? updates]) =>
      (ListTastingsResponseBuilder()..update(updates))._build();

  _$ListTastingsResponse._({this.tastings, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListTastingsResponse rebuild(
          void Function(ListTastingsResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListTastingsResponseBuilder toBuilder() =>
      ListTastingsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListTastingsResponse &&
        tastings == other.tastings &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tastings.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListTastingsResponse')
          ..add('tastings', tastings)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListTastingsResponseBuilder
    implements Builder<ListTastingsResponse, ListTastingsResponseBuilder> {
  _$ListTastingsResponse? _$v;

  ListBuilder<Tasting>? _tastings;
  ListBuilder<Tasting> get tastings =>
      _$this._tastings ??= ListBuilder<Tasting>();
  set tastings(ListBuilder<Tasting>? tastings) => _$this._tastings = tastings;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListTastingsResponseBuilder() {
    ListTastingsResponse._defaults(this);
  }

  ListTastingsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tastings = $v.tastings?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListTastingsResponse other) {
    _$v = other as _$ListTastingsResponse;
  }

  @override
  void update(void Function(ListTastingsResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListTastingsResponse build() => _build();

  _$ListTastingsResponse _build() {
    _$ListTastingsResponse _$result;
    try {
      _$result = _$v ??
          _$ListTastingsResponse._(
            tastings: _tastings?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tastings';
        _tastings?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListTastingsResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
