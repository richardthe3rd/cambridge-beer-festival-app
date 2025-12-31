import 'package:flutter/material.dart';

/// A consistent section header for detail screens
///
/// Displays a title with an optional underline separator for visual hierarchy.
class SectionHeader extends StatelessWidget {
  /// The section title text
  final String title;

  /// Whether to show an underline separator below the title
  final bool showSeparator;

  /// Optional padding around the header
  final EdgeInsets? padding;

  const SectionHeader({
    required this.title,
    this.showSeparator = true,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (showSeparator) ...[
            const SizedBox(height: 4.0),
            Container(
              height: 1.0,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}
