import 'package:flutter/material.dart';

/// Renders [text] with every case-insensitive occurrence of [query] visually
/// emphasised, so a user can see *which* words caused a search result to match.
///
/// When [query] is blank or absent from [text], this degrades to a plain [Text]
/// — callers can pass it unconditionally. Built on [Text.rich] (a [Text]
/// widget) rather than a bare [RichText] so `find.text(...)` in widget tests
/// still resolves the full string via its plain-text form.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    super.key,
  });

  /// The full text to display.
  final String text;

  /// The search term to emphasise within [text]. Matched case-insensitively.
  final String query;

  /// Base style for the whole string.
  final TextStyle? style;

  /// Style applied to matched runs. Defaults to a bold, theme-primary tint with
  /// a subtle highlight background that reads correctly in light and dark.
  final TextStyle? highlightStyle;

  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = query.trim();
    final lowerQuery = trimmedQuery.toLowerCase();
    if (lowerQuery.isEmpty || !text.toLowerCase().contains(lowerQuery)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHighlight =
        highlightStyle ??
        (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
        );

    return Text.rich(
      TextSpan(
        style: style,
        children: _buildSpans(lowerQuery, effectiveHighlight),
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<TextSpan> _buildSpans(String lowerQuery, TextStyle highlightStyle) {
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: highlightStyle,
        ),
      );
      start = index + lowerQuery.length;
    }
    return spans;
  }
}
