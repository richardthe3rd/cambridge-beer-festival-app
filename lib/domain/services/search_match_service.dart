import '../../models/models.dart';

/// A short, match-centred window taken from a longer text field, together with
/// the location of the matched substring within the window so the UI can
/// highlight it.
///
/// [text] may be bracketed with ellipses when the source text extends beyond
/// the window; [matchStart]/[matchLength] are offsets into [text] (ellipses
/// included), not into the original field.
class SearchExcerpt {
  const SearchExcerpt({
    required this.text,
    required this.matchStart,
    required this.matchLength,
  });

  /// The windowed excerpt, e.g. `…recommended by Tom for the…`.
  final String text;

  /// Offset of the matched run within [text].
  final int matchStart;

  /// Length of the matched run (equal to the query length).
  final int matchLength;

  @override
  bool operator ==(Object other) =>
      other is SearchExcerpt &&
      other.text == text &&
      other.matchStart == matchStart &&
      other.matchLength == matchLength;

  @override
  int get hashCode => Object.hash(text, matchStart, matchLength);

  @override
  String toString() =>
      'SearchExcerpt(text: $text, matchStart: $matchStart, '
      'matchLength: $matchLength)';
}

/// Pure logic for locating *why* a drink matched a search query.
///
/// Owns the single source of truth for which fields free-text search covers
/// (see [_searchableTexts]) so the boolean filter path ([matches]) and the
/// UI's "why did this match" excerpt ([hiddenFieldExcerpt]) can never drift
/// apart. Independent of Flutter — testable in isolation.
class SearchMatchService {
  const SearchMatchService();

  /// Characters of surrounding context kept on each side of a match when
  /// windowing a long field into an excerpt.
  static const int _contextRadius = 30;

  static const String _ellipsis = '…';

  /// The searchable text fields of [d], in display-priority order. Name and
  /// brewery are always present; style, the catalogue description, and the
  /// user's own note are included only when non-null.
  ///
  /// This is the single source of truth for what search covers — both [matches]
  /// and the filter service derive from it.
  Iterable<String> _searchableTexts(Drink d) sync* {
    yield d.name;
    yield d.breweryName;
    final style = d.style;
    if (style != null) yield style;
    final notes = d.notes;
    if (notes != null) yield notes;
    final userNotes = d.userNotes;
    if (userNotes != null) yield userNotes;
  }

  /// Whether [drink] matches an already-lowercased [lowerQuery] in any
  /// searchable field.
  bool matches(Drink drink, String lowerQuery) =>
      _searchableTexts(drink).any((t) => t.toLowerCase().contains(lowerQuery));

  /// An excerpt explaining a match that the result card's visible fields (name,
  /// brewery, style) don't already reveal — i.e. [query] hit the catalogue
  /// description or the user's own note.
  ///
  /// Returns null when [query] is blank, when it doesn't match a hidden field,
  /// or when it already matches a visible field (the match is self-evident, so
  /// no excerpt is warranted). The catalogue description is preferred over the
  /// user note when both match.
  SearchExcerpt? hiddenFieldExcerpt(Drink drink, String query) {
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return null;

    // A visible field already shows the match — no excerpt needed.
    if (_contains(drink.name, lowerQuery) ||
        _contains(drink.breweryName, lowerQuery) ||
        _contains(drink.style, lowerQuery)) {
      return null;
    }

    for (final text in [drink.notes, drink.userNotes]) {
      final excerpt = _excerpt(text, lowerQuery);
      if (excerpt != null) return excerpt;
    }
    return null;
  }

  bool _contains(String? text, String lowerQuery) =>
      text != null && text.toLowerCase().contains(lowerQuery);

  /// Builds a match-centred window of [text] for [lowerQuery], or null if the
  /// query isn't present. Window edges are snapped to whitespace so words
  /// aren't cut mid-way, and bracketed with an ellipsis when text is elided.
  SearchExcerpt? _excerpt(String? text, String lowerQuery) {
    if (text == null) return null;
    final index = text.toLowerCase().indexOf(lowerQuery);
    if (index < 0) return null;
    final matchEnd = index + lowerQuery.length;

    // Expand a fixed radius either side, then snap to word boundaries so the
    // window doesn't begin or end mid-word.
    var start = (index - _contextRadius).clamp(0, text.length);
    if (start > 0) {
      final space = text.lastIndexOf(RegExp(r'\s'), start);
      if (space >= 0) start = space + 1;
    }
    var end = (matchEnd + _contextRadius).clamp(0, text.length);
    if (end < text.length) {
      final space = text.indexOf(RegExp(r'\s'), end);
      if (space >= 0) end = space;
    }

    final leading = start > 0 ? _ellipsis : '';
    final trailing = end < text.length ? _ellipsis : '';
    final excerptText = '$leading${text.substring(start, end)}$trailing';

    return SearchExcerpt(
      text: excerptText,
      matchStart: leading.length + (index - start),
      matchLength: lowerQuery.length,
    );
  }
}
