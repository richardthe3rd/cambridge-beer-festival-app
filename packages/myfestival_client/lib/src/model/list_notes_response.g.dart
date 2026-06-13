// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_notes_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListNotesResponse extends ListNotesResponse {
  @override
  final BuiltList<Note>? notes;
  @override
  final String? nextPageToken;
  @override
  final int? totalSize;

  factory _$ListNotesResponse(
          [void Function(ListNotesResponseBuilder)? updates]) =>
      (ListNotesResponseBuilder()..update(updates))._build();

  _$ListNotesResponse._({this.notes, this.nextPageToken, this.totalSize})
      : super._();
  @override
  ListNotesResponse rebuild(void Function(ListNotesResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ListNotesResponseBuilder toBuilder() =>
      ListNotesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListNotesResponse &&
        notes == other.notes &&
        nextPageToken == other.nextPageToken &&
        totalSize == other.totalSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, notes.hashCode);
    _$hash = $jc(_$hash, nextPageToken.hashCode);
    _$hash = $jc(_$hash, totalSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListNotesResponse')
          ..add('notes', notes)
          ..add('nextPageToken', nextPageToken)
          ..add('totalSize', totalSize))
        .toString();
  }
}

class ListNotesResponseBuilder
    implements Builder<ListNotesResponse, ListNotesResponseBuilder> {
  _$ListNotesResponse? _$v;

  ListBuilder<Note>? _notes;
  ListBuilder<Note> get notes => _$this._notes ??= ListBuilder<Note>();
  set notes(ListBuilder<Note>? notes) => _$this._notes = notes;

  String? _nextPageToken;
  String? get nextPageToken => _$this._nextPageToken;
  set nextPageToken(String? nextPageToken) =>
      _$this._nextPageToken = nextPageToken;

  int? _totalSize;
  int? get totalSize => _$this._totalSize;
  set totalSize(int? totalSize) => _$this._totalSize = totalSize;

  ListNotesResponseBuilder() {
    ListNotesResponse._defaults(this);
  }

  ListNotesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _notes = $v.notes?.toBuilder();
      _nextPageToken = $v.nextPageToken;
      _totalSize = $v.totalSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListNotesResponse other) {
    _$v = other as _$ListNotesResponse;
  }

  @override
  void update(void Function(ListNotesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListNotesResponse build() => _build();

  _$ListNotesResponse _build() {
    _$ListNotesResponse _$result;
    try {
      _$result = _$v ??
          _$ListNotesResponse._(
            notes: _notes?.build(),
            nextPageToken: nextPageToken,
            totalSize: totalSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'notes';
        _notes?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ListNotesResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
