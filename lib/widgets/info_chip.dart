import 'package:flutter/material.dart';

/// A small chip displaying information with an icon and label
///
/// Used to display drink metadata like style, dispense method, bar location, etc.
/// Can be made interactive with an onTap callback.
class InfoChip extends StatelessWidget {
  /// The text label to display
  final String label;

  /// The icon to display
  final IconData icon;

  /// Optional callback when the chip is tapped
  final VoidCallback? onTap;

  const InfoChip({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = onTap != null;
    
    // Interactive chips get a more button-like appearance
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isInteractive 
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isInteractive 
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: isInteractive 
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isInteractive 
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isInteractive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isInteractive) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        label: label,
        hint: 'Tap to view details about $label',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: chip,
        ),
      );
    }

    return chip;
  }
}
