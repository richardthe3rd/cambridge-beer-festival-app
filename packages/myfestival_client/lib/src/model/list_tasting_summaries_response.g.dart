// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_tasting_summaries_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListTastingSummariesResponse extends ListTastingSummariesResponse {
  @override
  final BuiltList<TastingSummary>? tastingSummaries;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListTastingSummariesResponse(
          [void Function(ListTastingSummariesResponseBuilder)? updates]) =>
      (ListTastingSummariesResponseBuilder()..update(updates))._build();

  _$ListTastingSummariesResponse._(
      {this.tastingSummaries, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListTastingSummariesResponse rebuild(
          void Function(ListTastingSummariesResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListTastingSummariesResponseBuilder toBuilder() =>
      ListTastingSummariesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListTastingSummariesResponse &&
        tastingSummaries == other.tastingSummaries &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tastingSummaries.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListTastingSummariesResponse')
          ..add('tastingSummaries', tastingSummaries)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListTastingSummariesResponseBuilder
    implements
        Builder<ListTastingSummariesResponse,
            ListTastingSummariesResponseBuilder> {
  _$ListTastingSummariesResponse? _$v;

  ListBuilder<TastingSummary>? _tastingSummaries;
  ListBuilder<TastingSummary> get tastingSummaries =>
      _$this._tastingSummaries ??= ListBuilder<TastingSummary>();
  set tastingSummaries(ListBuilder<TastingSummary>? tastingSummaries) =>
      _$this._tastingSummaries = tastingSummaries;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListTastingSummariesResponseBuilder() {
    ListTastingSummariesResponse._defaults(this);
  }

  ListTastingSummariesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tastingSummaries = $v.tastingSummaries?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListTastingSummariesResponse other) {
    _$v = other as _$ListTastingSummariesResponse;
  }

  @override
  void update(void Function(ListTastingSummariesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListTastingSummariesResponse build() => _build();

  _$ListTastingSummariesResponse _build() {
    _$ListTastingSummariesResponse _$result;
    try {
      _$result = _$v ??
          _$ListTastingSummariesResponse._(
            tastingSummaries: _tastingSummaries?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tastingSummaries';
        _tastingSummaries?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListTastingSummariesResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
