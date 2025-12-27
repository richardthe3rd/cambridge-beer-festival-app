import 'package:flutter/material.dart';

/// A navigation breadcrumb bar for detail screens.
///
/// Shows a back button with context text (e.g., "Beer / Oakham Ales").
/// Text sections can be made clickable by providing navigation callbacks.
/// Optimized for mobile with large touch targets.
///
/// Example usage:
/// ```dart
/// BreadcrumbBar(
///   backLabel: 'Beer',
///   contextLabel: 'Oakham Ales',
///   onBack: () => Navigator.pop(context),
///   onBackLabelTap: () => context.go('/beer'),
///   onContextLabelTap: () => context.go('/brewery/oakham'),
/// )
/// ```
class BreadcrumbBar extends StatelessWidget {
  /// Creates a breadcrumb bar.
  const BreadcrumbBar({
    required this.backLabel,
    required this.onBack,
    this.contextLabel,
    this.onBackLabelTap,
    this.onContextLabelTap,
    super.key,
  });

  /// Label for the back button (e.g., "Beer", "Drinks").
  final String backLabel;

  /// Optional context text (e.g., brewery name, style name).
  final String? contextLabel;

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  /// Optional callback when the back label text is tapped.
  /// If provided, makes the back label clickable.
  final VoidCallback? onBackLabelTap;

  /// Optional callback when the context label text is tapped.
  /// If provided, makes the context label clickable.
  final VoidCallback? onContextLabelTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final linkStyle = textStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Large back button with semantics
          Semantics(
            label: 'Back to $backLabel',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              tooltip: 'Back to $backLabel',
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 8),
          // Breadcrumb text (can be interactive)
          Expanded(
            child: Row(
              children: [
                // Back label (clickable if callback provided)
                Flexible(
                  child: _buildTextSegment(
                    context,
                    backLabel,
                    onBackLabelTap,
                    onBackLabelTap != null ? linkStyle : textStyle,
                  ),
                ),
                // Separator and context label
                if (contextLabel != null) ...[
                  Text(' / ', style: textStyle),
                  Flexible(
                    child: _buildTextSegment(
                      context,
                      contextLabel!,
                      onContextLabelTap,
                      onContextLabelTap != null ? linkStyle : textStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a text segment that may be clickable.
  Widget _buildTextSegment(
    BuildContext context,
    String text,
    VoidCallback? onTap,
    TextStyle? style,
  ) {
    final textWidget = Text(
      text,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    if (onTap == null) {
      return textWidget;
    }

    return Semantics(
      label: 'Navigate to $text',
      button: true,
      hint: 'Double tap to navigate',
      child: InkWell(
        onTap: onTap,
        child: textWidget,
      ),
    );
  }
}
