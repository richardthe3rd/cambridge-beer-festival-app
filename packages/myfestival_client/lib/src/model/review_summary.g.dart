// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReviewSummary extends ReviewSummary {
  @override
  final String? name;
  @override
  final int? ratingCount;
  @override
  final double? averageRating;
  @override
  final int? responseCount;
  @override
  final int? recommendCount;
  @override
  final double? recommendRate;

  factory _$ReviewSummary([void Function(ReviewSummaryBuilder)? updates]) =>
      (ReviewSummaryBuilder()..update(updates))._build();

  _$ReviewSummary._(
      {this.name,
      this.ratingCount,
      this.averageRating,
      this.responseCount,
      this.recommendCount,
      this.recommendRate})
      : super._();
  @override
  ReviewSummary rebuild(void Function(ReviewSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReviewSummaryBuilder toBuilder() => ReviewSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReviewSummary &&
        name == other.name &&
        ratingCount == other.ratingCount &&
        averageRating == other.averageRating &&
        responseCount == other.responseCount &&
        recommendCount == other.recommendCount &&
        recommendRate == other.recommendRate;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, ratingCount.hashCode);
    _$hash = $jc(_$hash, averageRating.hashCode);
    _$hash = $jc(_$hash, responseCount.hashCode);
    _$hash = $jc(_$hash, recommendCount.hashCode);
    _$hash = $jc(_$hash, recommendRate.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReviewSummary')
          ..add('name', name)
          ..add('ratingCount', ratingCount)
          ..add('averageRating', averageRating)
          ..add('responseCount', responseCount)
          ..add('recommendCount', recommendCount)
          ..add('recommendRate', recommendRate))
        .toString();
  }
}

class ReviewSummaryBuilder
    implements Builder<ReviewSummary, ReviewSummaryBuilder> {
  _$ReviewSummary? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _ratingCount;
  int? get ratingCount => _$this._ratingCount;
  set ratingCount(int? ratingCount) => _$this._ratingCount = ratingCount;

  double? _averageRating;
  double? get averageRating => _$this._averageRating;
  set averageRating(double? averageRating) =>
      _$this._averageRating = averageRating;

  int? _responseCount;
  int? get responseCount => _$this._responseCount;
  set responseCount(int? responseCount) =>
      _$this._responseCount = responseCount;

  int? _recommendCount;
  int? get recommendCount => _$this._recommendCount;
  set recommendCount(int? recommendCount) =>
      _$this._recommendCount = recommendCount;

  double? _recommendRate;
  double? get recommendRate => _$this._recommendRate;
  set recommendRate(double? recommendRate) =>
      _$this._recommendRate = recommendRate;

  ReviewSummaryBuilder() {
    ReviewSummary._defaults(this);
  }

  ReviewSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _ratingCount = $v.ratingCount;
      _averageRating = $v.averageRating;
      _responseCount = $v.responseCount;
      _recommendCount = $v.recommendCount;
      _recommendRate = $v.recommendRate;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReviewSummary other) {
    _$v = other as _$ReviewSummary;
  }

  @override
  void update(void Function(ReviewSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReviewSummary build() => _build();

  _$ReviewSummary _build() {
    final _$result = _$v ??
        _$ReviewSummary._(
          name: name,
          ratingCount: ratingCount,
          averageRating: averageRating,
          responseCount: responseCount,
          recommendCount: recommendCount,
          recommendRate: recommendRate,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
