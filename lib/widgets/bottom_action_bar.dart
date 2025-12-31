import 'package:flutter/material.dart';

/// A sticky bottom action bar for detail screens
///
/// Provides persistent access to important actions like tasting log,
/// rating, favorites, and sharing.
class BottomActionBar extends StatelessWidget {
  /// List of action buttons to display
  final List<Widget> actions;

  /// Optional background color (defaults to surface with elevation)
  final Color? backgroundColor;

  const BottomActionBar({
    required this.actions,
    this.backgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: actions,
          ),
        ),
      ),
    );
  }
}

/// A single action button for use in BottomActionBar
class ActionButton extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Label text
  final String label;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Whether the action is active/selected
  final bool isActive;

  /// Optional semantic label for accessibility
  final String? semanticLabel;

  const ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.semanticLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
