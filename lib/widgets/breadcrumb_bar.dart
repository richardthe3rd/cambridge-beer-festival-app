import 'package:flutter/material.dart';

/// A navigation breadcrumb bar for detail screens.
///
/// Shows a back button with context text (e.g., "Beer / Oakham Ales").
/// Optimized for mobile with large touch targets.
///
/// Example usage:
/// ```dart
/// BreadcrumbBar(
///   backLabel: 'Beer',
///   contextLabel: 'Oakham Ales',
///   onBack: () => Navigator.pop(context),
/// )
/// ```
class BreadcrumbBar extends StatelessWidget {
  /// Creates a breadcrumb bar.
  const BreadcrumbBar({
    required this.backLabel,
    required this.onBack,
    this.contextLabel,
    super.key,
  });

  /// Label for the back button (e.g., "Beer", "Drinks").
  final String backLabel;

  /// Optional context text (e.g., brewery name, style name).
  final String? contextLabel;

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          // Context text (non-interactive)
          Expanded(
            child: Text(
              contextLabel != null ? '$backLabel / $contextLabel' : backLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
