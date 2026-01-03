import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../utils/navigation_helpers.dart';

/// Screen showing the user's festival log (My Festival)
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.festivalId,
    super.key,
  });

  final String festivalId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => provider.loadDrinks(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: _buildTitle(context, provider),
              actions: [
                buildOverflowMenu(context),
              ],
            ),
            _buildFestivalLogSliver(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Festival'),
        Text(
          provider.currentFestival.name,
          style: theme.textTheme.labelSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFestivalLogSliver(BuildContext context, BeerProvider provider) {
    // Get all favorite drinks
    final allDrinks = provider.allDrinks.where((d) => d.isFavorite).toList();

    if (allDrinks.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    // Build list of drinks with their statuses
    return FutureBuilder<List<(Drink, String?, int, List<DateTime>)>>(
      future: Future.wait(
        allDrinks.map((drink) async {
          final status = await provider.getFavoriteStatus(drink);
          final tryCount = await provider.getTryCount(drink);
          final timestamps = await provider.getTastingTimestamps(drink);
          return (drink, status, tryCount, timestamps);
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final drinksWithStatus = snapshot.data!;

        // Separate want to try and tasted drinks
        final wantToTry = drinksWithStatus
            .where((d) => d.$2 == 'want_to_try')
            .toList();
        final tasted = drinksWithStatus
            .where((d) => d.$2 == 'tasted')
            .toList();

        // Sort want to try by name
        wantToTry.sort((a, b) => a.$1.name.compareTo(b.$1.name));

        // Group tasted drinks by day of most recent tasting
        final tastedByDay = <String, List<(Drink, String?, int, List<DateTime>)>>{};
        for (final item in tasted) {
          final timestamps = item.$4;
          if (timestamps.isNotEmpty) {
            final mostRecent = timestamps.last;
            final dayKey = _getDayLabel(mostRecent);
            tastedByDay.putIfAbsent(dayKey, () => []).add(item);
          }
        }

        // Sort each day's drinks by most recent tasting time
        for (final drinks in tastedByDay.values) {
          drinks.sort((a, b) {
            final timeA = a.$4.isNotEmpty ? a.$4.last : DateTime(2000);
            final timeB = b.$4.isNotEmpty ? b.$4.last : DateTime(2000);
            return timeB.compareTo(timeA); // Most recent first
          });
        }

        // Get ordered list of day keys (most recent first)
        final dayKeys = tastedByDay.keys.toList()
          ..sort((a, b) {
            final drinksA = tastedByDay[a]!;
            final drinksB = tastedByDay[b]!;
            final timeA = drinksA.first.$4.isNotEmpty ? drinksA.first.$4.last : DateTime(2000);
            final timeB = drinksB.first.$4.isNotEmpty ? drinksB.first.$4.last : DateTime(2000);
            return timeB.compareTo(timeA); // Most recent day first
          });

        // Build flat list of widgets
        final widgets = <Widget>[];

        // Add "Want to Try" section
        if (wantToTry.isNotEmpty) {
          widgets.add(_buildSectionHeader(context, 'Want to Try', wantToTry.length));
          for (final (drink, _, _, _) in wantToTry) {
            widgets.add(_buildDrinkCard(context, drink));
          }
        }

        // Add tasted sections by day
        for (final dayKey in dayKeys) {
          final dayDrinks = tastedByDay[dayKey]!;
          widgets.add(_buildDayHeader(context, dayKey, dayDrinks.length));
          for (final (drink, _, tryCount, timestamps) in dayDrinks) {
            widgets.add(_buildTastedDrinkCard(
              context,
              drink,
              tryCount,
              timestamps.isNotEmpty ? timestamps.last : DateTime.now(),
            ));
          }
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => widgets[index],
            childCount: widgets.length,
          ),
        );
      },
    );
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(dateDay).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      // Show day of week for recent dates
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else {
      // Show date for older entries
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            title == 'Want to Try' ? Icons.bookmark_border : Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, String dayLabel, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: theme.colorScheme.secondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            dayLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkCard(BuildContext context, Drink drink) {
    final provider = context.read<BeerProvider>();
    return Semantics(
      label: '${drink.name} by ${drink.breweryName}',
      hint: 'Double tap to view drink details',
      button: true,
      child: DrinkCard(
        drink: drink,
        onTap: () => context.go(buildDrinkDetailPath(festivalId, drink.id)),
        onFavoriteTap: () => provider.toggleFavorite(drink),
      ),
    );
  }

  Widget _buildTastedDrinkCard(BuildContext context, Drink drink, int tryCount, DateTime lastTasted) {
    final provider = context.read<BeerProvider>();
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Semantics(
          label: '${drink.name} by ${drink.breweryName}, tasted at ${_formatTime(lastTasted)}',
          hint: 'Double tap to view drink details',
          button: true,
          child: InkWell(
            onTap: () => context.go(buildDrinkDetailPath(festivalId, drink.id)),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Check icon with count badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      if (tryCount > 1)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              tryCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Drink info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drink.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          drink.breweryName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(lastTasted),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bookmark button
                  Semantics(
                    label: 'Remove from want to try',
                    hint: 'Double tap to toggle',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        drink.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        color: drink.isFavorite
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => provider.toggleFavorite(drink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Your festival log is empty',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on drinks you want to try or mark drinks as tasted to build your festival log',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
