import 'package:flutter/material.dart';

/// A prominent card displaying key decision-making information
///
/// Used at the top of detail screens to highlight the most important
/// information users need to make decisions (e.g., style, availability, ABV).
class HeroInfoCard extends StatelessWidget {
  /// List of information rows to display in the card
  final List<HeroInfoRow> rows;

  /// Optional padding around the card content
  final EdgeInsets? padding;

  const HeroInfoCard({
    required this.rows,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12.0),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A single row of information within a HeroInfoCard
class HeroInfoRow extends StatelessWidget {
  /// Icon to display before the text
  final IconData icon;

  /// Main text content
  final String text;

  /// Optional color for the icon
  final Color? iconColor;

  /// Optional text style
  final TextStyle? textStyle;

  const HeroInfoRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.textStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onPrimaryContainer,
    );

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ?? theme.colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: textStyle ?? defaultStyle,
          ),
        ),
      ],
    );
  }
}
