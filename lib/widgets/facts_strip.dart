import 'package:flutter/material.dart';

/// A horizontal strip of key facts at the top of a detail screen's identity
/// hero — a divided row of cells, each a centred value over a short label.
///
/// Owns the divider treatment: top and bottom borders around the whole strip
/// and a left border between adjacent cells. Callers supply only the [cells];
/// the strip computes the divider colour and applies the borders itself.
///
/// This file also holds [factValueText] and [HeroAboutSection], the other two
/// pieces every identity hero (drink, brewery, style) shares.
class FactsStrip extends StatelessWidget {
  /// The cells to lay out left-to-right, each an equal-width column.
  final List<FactCell> cells;

  const FactsStrip({required this.cells, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < cells.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: i == 0
                      ? const BoxDecoration()
                      : BoxDecoration(
                          border: Border(left: BorderSide(color: divider)),
                        ),
                  child: cells[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single cell of a [FactsStrip]: a centred [value] widget over a short,
/// letter-spaced [label] (callers pass their own casing, e.g. 'Avg ABV').
/// When [onTap] is provided the whole cell becomes a navigation button
/// carrying [semanticLabel]. The left divider between cells is owned by the
/// parent [FactsStrip], not the cell.
class FactCell extends StatelessWidget {
  final Widget value;
  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const FactCell({
    required this.value,
    required this.label,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          value,
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
      if (semanticLabel != null) {
        content = Semantics(
          label: semanticLabel,
          button: true,
          excludeSemantics: true,
          child: content,
        );
      }
    }

    return content;
  }
}

/// The centred, bold [FactCell] value text shared by every identity hero's
/// fact cells. [leading]/[trailing] add an icon either side (e.g. the
/// availability cell's check mark); [isLink] underlines the text for a
/// tappable cell; [color] overrides the default `onSurface`.
Widget factValueText(
  ThemeData theme,
  String text, {
  bool isLink = false,
  Color? color,
  Widget? leading,
  Widget? trailing,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (leading != null) ...[leading, const SizedBox(width: 4)],
      Flexible(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? theme.colorScheme.onSurface,
            decoration: isLink ? TextDecoration.underline : null,
            decorationColor: theme.colorScheme.primary,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

/// The "about this X" block at the foot of an identity hero card: a divider,
/// an uppercase [heading], and the entity's own descriptive [body] text.
/// Shared by the drink, brewery, and style hero panels.
class HeroAboutSection extends StatelessWidget {
  final String heading;
  final String body;

  const HeroAboutSection({
    required this.heading,
    required this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 1, color: divider),
        const SizedBox(height: 12),
        Text(
          heading,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
