// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_reviews_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListReviewsResponse extends ListReviewsResponse {
  @override
  final BuiltList<Review>? reviews;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListReviewsResponse(
          [void Function(ListReviewsResponseBuilder)? updates]) =>
      (ListReviewsResponseBuilder()..update(updates))._build();

  _$ListReviewsResponse._({this.reviews, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListReviewsResponse rebuild(
          void Function(ListReviewsResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListReviewsResponseBuilder toBuilder() =>
      ListReviewsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListReviewsResponse &&
        reviews == other.reviews &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, reviews.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListReviewsResponse')
          ..add('reviews', reviews)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListReviewsResponseBuilder
    implements Builder<ListReviewsResponse, ListReviewsResponseBuilder> {
  _$ListReviewsResponse? _$v;

  ListBuilder<Review>? _reviews;
  ListBuilder<Review> get reviews => _$this._reviews ??= ListBuilder<Review>();
  set reviews(ListBuilder<Review>? reviews) => _$this._reviews = reviews;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListReviewsResponseBuilder() {
    ListReviewsResponse._defaults(this);
  }

  ListReviewsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _reviews = $v.reviews?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListReviewsResponse other) {
    _$v = other as _$ListReviewsResponse;
  }

  @override
  void update(void Function(ListReviewsResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListReviewsResponse build() => _build();

  _$ListReviewsResponse _build() {
    _$ListReviewsResponse _$result;
    try {
      _$result = _$v ??
          _$ListReviewsResponse._(
            reviews: _reviews?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'reviews';
        _reviews?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListReviewsResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
