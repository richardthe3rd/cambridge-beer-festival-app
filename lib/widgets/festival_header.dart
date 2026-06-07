import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// App-bar title for the drinks screen: app icon, current festival name, the
/// drink count, and a coloured status badge.
class FestivalHeader extends StatelessWidget {
  const FestivalHeader({required this.provider, super.key});

  final BeerProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = Festival.getStatusInContext(
      provider.currentFestival,
      provider.sortedFestivals,
    );
    final drinkCount = provider.drinks.length;
    final drinkCountLabel =
        '$drinkCount ${drinkCount == 1 ? 'drink' : 'drinks'}';

    // Fold the status into the label and exclude child semantics so screen
    // readers announce one coherent phrase instead of the name, count, and
    // badge separately. Matches the pattern in DrinkCard, HeroInfoCard, etc.
    return Semantics(
      label:
          'Current festival: ${provider.currentFestival.name}, '
          '$drinkCountLabel, ${FestivalStatusBadge.spokenLabel(status)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/app_icon.png', width: 32, height: 32),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.currentFestival.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        drinkCountLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FestivalStatusBadge(status: status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small coloured pill summarising a festival's [FestivalStatus]
/// (LIVE / SOON / RECENT / PAST). Colours adapt to light and dark themes.
class FestivalStatusBadge extends StatelessWidget {
  const FestivalStatusBadge({required this.status, super.key});

  final FestivalStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (badgeLabel, _, lightColor, darkColor) = _styleFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? darkColor : lightColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        badgeLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Spoken form of the status for screen-reader labels (the badge text is
  /// terse and is excluded from semantics at the parent level).
  static String spokenLabel(FestivalStatus status) => _styleFor(status).$2;

  /// Returns the badge label, spoken label, and (light, dark) background
  /// colours for [status]. Single source of truth for all status styling.
  static (String, String, Color, Color) _styleFor(FestivalStatus status) {
    switch (status) {
      case FestivalStatus.live:
        return const ('LIVE', 'live now', Color(0xFF2E7D32), Color(0xFF4CAF50));
      case FestivalStatus.upcoming:
        return const (
          'SOON',
          'starting soon',
          Color(0xFF1976D2),
          Color(0xFF42A5F5),
        );
      case FestivalStatus.mostRecent:
        return const (
          'RECENT',
          'most recent',
          Color(0xFFEF6C00),
          Color(0xFFFF9800),
        );
      case FestivalStatus.past:
        return const ('PAST', 'past', Color(0xFF616161), Color(0xFF9E9E9E));
    }
  }
}
