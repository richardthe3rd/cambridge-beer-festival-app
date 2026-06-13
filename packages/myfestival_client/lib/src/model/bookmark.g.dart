// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Bookmark extends Bookmark {
  @override
  final String? name;
  @override
  final DateTime? createTime;

  factory _$Bookmark([void Function(BookmarkBuilder)? updates]) =>
      (BookmarkBuilder()..update(updates))._build();

  _$Bookmark._({this.name, this.createTime}) : super._();
  @override
  Bookmark rebuild(void Function(BookmarkBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BookmarkBuilder toBuilder() => BookmarkBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Bookmark &&
        name == other.name &&
        createTime == other.createTime;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, createTime.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Bookmark')
          ..add('name', name)
          ..add('createTime', createTime))
        .toString();
  }
}

class BookmarkBuilder implements Builder<Bookmark, BookmarkBuilder> {
  _$Bookmark? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  DateTime? _createTime;
  DateTime? get createTime => _$this._createTime;
  set createTime(DateTime? createTime) => _$this._createTime = createTime;

  BookmarkBuilder() {
    Bookmark._defaults(this);
  }

  BookmarkBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _createTime = $v.createTime;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Bookmark other) {
    _$v = other as _$Bookmark;
  }

  @override
  void update(void Function(BookmarkBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Bookmark build() => _build();

  _$Bookmark _build() {
    final _$result = _$v ??
        _$Bookmark._(
          name: name,
          createTime: createTime,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
