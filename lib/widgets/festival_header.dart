import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// App-bar title for the drinks screen: app icon, current festival name, the
/// drink count, and a coloured status badge.
class FestivalHeader extends StatelessWidget {
  const FestivalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final festivalName = context.select<BeerProvider, String>(
      (p) => p.currentFestival.name,
    );
    // Select the derived enum rather than currentFestival/sortedFestivals
    // directly: Festival.== is id-scoped by design (would swallow an
    // in-place metadata refresh), and sortedFestivals is a derived List with
    // no stable identity across rebuilds.
    final status = context.select<BeerProvider, FestivalStatus>(
      (p) => Festival.getStatusInContext(p.currentFestival, p.sortedFestivals),
    );
    final drinkCount = context.select<BeerProvider, int>(
      (p) => p.drinks.length,
    );
    final drinkCountLabel = StringFormattingHelper.drinkCountLabel(drinkCount);

    // Fold the status into the label and exclude child semantics so screen
    // readers announce one coherent phrase instead of the name, count, and
    // badge separately. Matches the pattern in DrinkCard, DrinkHeroPanel, etc.
    return Semantics(
      label:
          'Current festival: $festivalName, '
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
                  festivalName,
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
                    FestivalStatusBadge(status: status, compact: true),
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

/// Small coloured pill summarising a festival's [FestivalStatus].
///
/// [compact] selects both the label wording and the geometry:
/// - `compact: true` (app-bar header) — short labels (LIVE / SOON / RECENT /
///   PAST), tighter padding, smaller radius and font.
/// - `compact: false` (default, festival browser cards) — long labels
///   (LIVE / COMING SOON / MOST RECENT / PAST), roomier padding, larger
///   radius and font.
///
/// Colours adapt to light and dark themes and are identical for both modes.
class FestivalStatusBadge extends StatelessWidget {
  const FestivalStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final FestivalStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (compactLabel, longLabel, _, lightColor, darkColor) = _styleFor(
      status,
    );

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? darkColor : lightColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Text(
        compact ? compactLabel : longLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Spoken form of the status for screen-reader labels (the badge text is
  /// terse and is excluded from semantics at the parent level).
  static String spokenLabel(FestivalStatus status) => _styleFor(status).$3;

  /// Returns the compact label, long label, spoken label, and (light, dark)
  /// background colours for [status]. Single source of truth for all status
  /// styling, shared by the app-bar header and the festival browser cards.
  static (String, String, String, Color, Color) _styleFor(
    FestivalStatus status,
  ) {
    switch (status) {
      case FestivalStatus.live:
        return const (
          'LIVE',
          'LIVE',
          'live now',
          Color(0xFF2E7D32),
          Color(0xFF4CAF50),
        );
      case FestivalStatus.upcoming:
        return const (
          'SOON',
          'COMING SOON',
          'starting soon',
          Color(0xFF1976D2),
          Color(0xFF42A5F5),
        );
      case FestivalStatus.mostRecent:
        return const (
          'RECENT',
          'MOST RECENT',
          'most recent',
          Color(0xFFEF6C00),
          Color(0xFFFF9800),
        );
      case FestivalStatus.past:
        return const (
          'PAST',
          'PAST',
          'past',
          Color(0xFF616161),
          Color(0xFF9E9E9E),
        );
    }
  }
}
