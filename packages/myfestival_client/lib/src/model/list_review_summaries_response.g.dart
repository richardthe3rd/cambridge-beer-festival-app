// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_review_summaries_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListReviewSummariesResponse extends ListReviewSummariesResponse {
  @override
  final BuiltList<ReviewSummary>? reviewSummaries;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListReviewSummariesResponse(
          [void Function(ListReviewSummariesResponseBuilder)? updates]) =>
      (ListReviewSummariesResponseBuilder()..update(updates))._build();

  _$ListReviewSummariesResponse._(
      {this.reviewSummaries, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListReviewSummariesResponse rebuild(
          void Function(ListReviewSummariesResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListReviewSummariesResponseBuilder toBuilder() =>
      ListReviewSummariesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListReviewSummariesResponse &&
        reviewSummaries == other.reviewSummaries &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, reviewSummaries.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListReviewSummariesResponse')
          ..add('reviewSummaries', reviewSummaries)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListReviewSummariesResponseBuilder
    implements
        Builder<ListReviewSummariesResponse,
            ListReviewSummariesResponseBuilder> {
  _$ListReviewSummariesResponse? _$v;

  ListBuilder<ReviewSummary>? _reviewSummaries;
  ListBuilder<ReviewSummary> get reviewSummaries =>
      _$this._reviewSummaries ??= ListBuilder<ReviewSummary>();
  set reviewSummaries(ListBuilder<ReviewSummary>? reviewSummaries) =>
      _$this._reviewSummaries = reviewSummaries;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListReviewSummariesResponseBuilder() {
    ListReviewSummariesResponse._defaults(this);
  }

  ListReviewSummariesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _reviewSummaries = $v.reviewSummaries?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListReviewSummariesResponse other) {
    _$v = other as _$ListReviewSummariesResponse;
  }

  @override
  void update(void Function(ListReviewSummariesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListReviewSummariesResponse build() => _build();

  _$ListReviewSummariesResponse _build() {
    _$ListReviewSummariesResponse _$result;
    try {
      _$result = _$v ??
          _$ListReviewSummariesResponse._(
            reviewSummaries: _reviewSummaries?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'reviewSummaries';
        _reviewSummaries?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListReviewSummariesResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
