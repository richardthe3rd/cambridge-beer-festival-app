import 'package:flutter/material.dart';

/// Tonal pill button used in the drinks-screen bottom control row for the
/// category, style, and sort pickers. Shows an active state with a clear (x)
/// affordance when a filter is applied.
class FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final String? semanticLabel;

  const FilterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isActive,
    this.semanticLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabel = semanticLabel ?? label;
    // Tapping always opens the filter sheet (where the filter can be changed or
    // cleared); it never clears in place, so the active hint must not promise
    // that.
    final semanticHint = isActive
        ? 'Double tap to change or clear this filter'
        : 'Double tap to select filter';

    return Semantics(
      label: effectiveLabel,
      hint: semanticHint,
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Square toggle button that opens/closes the drinks search bar. Highlights
/// when a search query is active but the bar is closed.
class SearchButton extends StatelessWidget {
  final bool isActive;
  final bool hasQuery;
  final VoidCallback onPressed;

  const SearchButton({
    required this.isActive,
    this.hasQuery = false,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isActive ? 'Close search' : 'Search drinks';
    final hint = isActive
        ? 'Double tap to close search bar'
        : 'Double tap to open search bar';

    return Semantics(
      label: label,
      hint: hint,
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          backgroundColor: hasQuery && !isActive
              ? theme.colorScheme.primaryContainer
              : null,
        ),
        child: Icon(isActive ? Icons.search_off : Icons.search, size: 20),
      ),
    );
  }
}

/// Square button opening the availability/dietary view filters, with a badge
/// showing how many filters are currently active.
class VisibilityFilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const VisibilityFilterButton({
    required this.activeCount,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = activeCount > 0;
    final label = isActive ? 'View filters ($activeCount)' : 'View filters';
    const hint = 'Double tap to set availability and dietary filters';

    return Semantics(
      label: label,
      hint: hint,
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          backgroundColor: isActive ? theme.colorScheme.primaryContainer : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isActive ? Icons.visibility : Icons.visibility_outlined,
              size: 20,
            ),
            if (isActive)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
