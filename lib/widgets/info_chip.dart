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
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
