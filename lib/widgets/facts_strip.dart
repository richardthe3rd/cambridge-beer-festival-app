import 'package:flutter/material.dart';

/// A horizontal strip of key facts at the top of a detail screen's identity
/// hero — a divided row of cells, each a centred value over a short label.
///
/// Owns the divider treatment: top and bottom borders around the whole strip
/// and a left border between adjacent cells. Callers supply only the [cells];
/// the strip computes the divider colour and applies the borders itself.
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

/// A single cell of a [FactsStrip]: a centred [value] widget over an uppercase
/// [label]. When [onTap] is provided the whole cell becomes a navigation button
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
