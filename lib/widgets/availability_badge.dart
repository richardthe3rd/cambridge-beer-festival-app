import 'package:flutter/material.dart';
import '../models/models.dart';

/// A badge indicating drink availability status
///
/// Shows "Available" (green) or "Sold Out" (red) based on availability.
class AvailabilityBadge extends StatelessWidget {
  /// Availability status to display
  final AvailabilityStatus status;

  /// Optional custom text (overrides status-based text)
  final String? customText;

  /// Whether to show as a compact chip or full-width banner
  final bool compact;

  const AvailabilityBadge({
    required this.status,
    this.customText,
    this.compact = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSoldOut = status == AvailabilityStatus.out;

    final backgroundColor = isSoldOut
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;

    final foregroundColor = isSoldOut
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    final icon = isSoldOut ? Icons.cancel : Icons.check_circle;
    final text = customText ?? (isSoldOut ? 'Sold Out' : 'Available');

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 4),
            Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Full-width banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
