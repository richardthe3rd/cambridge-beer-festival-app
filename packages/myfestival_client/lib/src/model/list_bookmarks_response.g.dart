// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_bookmarks_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListBookmarksResponse extends ListBookmarksResponse {
  @override
  final BuiltList<Bookmark>? bookmarks;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListBookmarksResponse(
          [void Function(ListBookmarksResponseBuilder)? updates]) =>
      (ListBookmarksResponseBuilder()..update(updates))._build();

  _$ListBookmarksResponse._(
      {this.bookmarks, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListBookmarksResponse rebuild(
          void Function(ListBookmarksResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListBookmarksResponseBuilder toBuilder() =>
      ListBookmarksResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListBookmarksResponse &&
        bookmarks == other.bookmarks &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, bookmarks.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListBookmarksResponse')
          ..add('bookmarks', bookmarks)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListBookmarksResponseBuilder
    implements Builder<ListBookmarksResponse, ListBookmarksResponseBuilder> {
  _$ListBookmarksResponse? _$v;

  ListBuilder<Bookmark>? _bookmarks;
  ListBuilder<Bookmark> get bookmarks =>
      _$this._bookmarks ??= ListBuilder<Bookmark>();
  set bookmarks(ListBuilder<Bookmark>? bookmarks) =>
      _$this._bookmarks = bookmarks;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListBookmarksResponseBuilder() {
    ListBookmarksResponse._defaults(this);
  }

  ListBookmarksResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _bookmarks = $v.bookmarks?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListBookmarksResponse other) {
    _$v = other as _$ListBookmarksResponse;
  }

  @override
  void update(void Function(ListBookmarksResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListBookmarksResponse build() => _build();

  _$ListBookmarksResponse _build() {
    _$ListBookmarksResponse _$result;
    try {
      _$result = _$v ??
          _$ListBookmarksResponse._(
            bookmarks: _bookmarks?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'bookmarks';
        _bookmarks?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListBookmarksResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
