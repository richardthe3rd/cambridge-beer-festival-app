// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Note extends Note {
  @override
  final String? name;
  @override
  final String content;
  @override
  final DateTime? updateTime;

  factory _$Note([void Function(NoteBuilder)? updates]) =>
      (NoteBuilder()..update(updates))._build();

  _$Note._({this.name, required this.content, this.updateTime}) : super._();
  @override
  Note rebuild(void Function(NoteBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NoteBuilder toBuilder() => NoteBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Note &&
        name == other.name &&
        content == other.content &&
        updateTime == other.updateTime;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jc(_$hash, updateTime.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Note')
          ..add('name', name)
          ..add('content', content)
          ..add('updateTime', updateTime))
        .toString();
  }
}

class NoteBuilder implements Builder<Note, NoteBuilder> {
  _$Note? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _content;
  String? get content => _$this._content;
  set content(String? content) => _$this._content = content;

  DateTime? _updateTime;
  DateTime? get updateTime => _$this._updateTime;
  set updateTime(DateTime? updateTime) => _$this._updateTime = updateTime;

  NoteBuilder() {
    Note._defaults(this);
  }

  NoteBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _content = $v.content;
      _updateTime = $v.updateTime;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Note other) {
    _$v = other as _$Note;
  }

  @override
  void update(void Function(NoteBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Note build() => _build();

  _$Note _build() {
    final _$result = _$v ??
        _$Note._(
          name: name,
          content: BuiltValueNullFieldError.checkNotNull(
              content, r'Note', 'content'),
          updateTime: updateTime,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
