import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// Tappable banner under the app bar showing the current festival's dates and
/// location. Hidden when the festival has neither. Tapping opens festival info.
class FestivalBanner extends StatelessWidget {
  const FestivalBanner({
    required this.provider,
    required this.festivalId,
    super.key,
  });

  final BeerProvider provider;
  final String festivalId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final festival = provider.currentFestival;

    // Only show banner if festival has dates or location
    if (festival.formattedDates.isEmpty && festival.location == null) {
      return const SizedBox.shrink();
    }

    final semanticLabel = [
      if (festival.formattedDates.isNotEmpty) festival.formattedDates,
      if (festival.location != null) festival.location,
    ].join(', ');

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Semantics(
        label: 'Festival information: $semanticLabel',
        hint: 'Double tap for more details',
        button: true,
        child: InkWell(
          onTap: () => context.push(buildFestivalInfoPath(festivalId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (festival.formattedDates.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              festival.formattedDates,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      if (festival.location != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              festival.location!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
