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

/// Whether a searchable field is already shown on a result card, which decides
/// whether a match in it needs an explanatory excerpt.
enum _FieldVisibility {
  /// Rendered directly on the card (name, brewery, style) — a match is
  /// self-evident, so no excerpt is warranted.
  visibleOnCard,

  /// Not shown on the card (catalogue description, the user's own note) — a
  /// match here is the reason an excerpt exists.
  hiddenOnCard,
}

/// Pure logic for locating *why* a drink matched a search query.
///
/// Owns the single source of truth for which fields free-text search covers,
/// each tagged with whether the card already shows it (see [_searchableFields]).
/// Both the boolean match path ([matches]) and the "why did this match" excerpt
/// ([hiddenFieldExcerpt]) derive from that one list — including the
/// visible/hidden split — so adding or reclassifying a field can't leave them
/// inconsistent. Independent of Flutter — testable in isolation.
class SearchMatchService {
  const SearchMatchService();

  /// Characters of surrounding context kept on each side of a match when
  /// windowing a long field into an excerpt.
  static const int _contextRadius = 30;

  static const String _ellipsis = '…';

  /// The searchable text fields of [d], in display-priority order, each tagged
  /// with whether the card already shows it. Name and brewery are always
  /// present; style, the catalogue description, and the user's own note are
  /// included only when non-null.
  ///
  /// Single source of truth for what search covers *and* how each field is
  /// surfaced — [matches], the filter service, and [hiddenFieldExcerpt] all
  /// derive from it.
  Iterable<(_FieldVisibility, String)> _searchableFields(Drink d) sync* {
    yield (_FieldVisibility.visibleOnCard, d.name);
    yield (_FieldVisibility.visibleOnCard, d.breweryName);
    final style = d.style;
    if (style != null) yield (_FieldVisibility.visibleOnCard, style);
    final notes = d.notes;
    if (notes != null) yield (_FieldVisibility.hiddenOnCard, notes);
    final userNotes = d.userNotes;
    if (userNotes != null) yield (_FieldVisibility.hiddenOnCard, userNotes);
  }

  /// Whether [drink] matches an already-lowercased [lowerQuery] in any
  /// searchable field.
  bool matches(Drink drink, String lowerQuery) => _searchableFields(
    drink,
  ).any((f) => f.$2.toLowerCase().contains(lowerQuery));

  /// An excerpt explaining a match that the result card's visible fields (name,
  /// brewery, style) don't already reveal — i.e. [query] hit the catalogue
  /// description or the user's own note.
  ///
  /// Returns null when [query] is blank, when it doesn't match a hidden field,
  /// or when it already matches a visible field (the match is self-evident, so
  /// no excerpt is warranted). Hidden fields are considered in
  /// [_searchableFields] order — the catalogue description before the user note.
  SearchExcerpt? hiddenFieldExcerpt(Drink drink, String query) {
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return null;

    final fields = _searchableFields(drink).toList();

    // A visible field already shows the match — no excerpt needed.
    final visibleMatch = fields.any(
      (f) =>
          f.$1 == _FieldVisibility.visibleOnCard &&
          f.$2.toLowerCase().contains(lowerQuery),
    );
    if (visibleMatch) return null;

    for (final field in fields) {
      if (field.$1 != _FieldVisibility.hiddenOnCard) continue;
      final excerpt = _excerpt(field.$2, lowerQuery);
      if (excerpt != null) return excerpt;
    }
    return null;
  }

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
