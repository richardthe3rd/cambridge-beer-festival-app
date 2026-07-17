import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Day-formatted header for a group of tastings, e.g. "Tuesday 10 June".
final DateFormat _dayHeaderFormat = DateFormat('EEEE d MMMM');

/// Time-of-day for the most recent tasting in a row, e.g. "6:45 PM".
final DateFormat _tastingTimeFormat = DateFormat('h:mm a');

/// One calendar day's worth of tasted entries, most-recently-tasted first.
class _TastedDayGroup {
  _TastedDayGroup({required this.day, required this.entries});

  final DateTime day;
  final List<MyFestivalEntry> entries;
}

/// Groups already-sorted (lastTastedAt descending) tasted entries by the
/// calendar day of each entry's most recent tasting. Because the input is
/// sorted by exact timestamp, entries for the same day are always contiguous.
List<_TastedDayGroup> _groupTastedByDay(List<MyFestivalEntry> tasted) {
  final groups = <_TastedDayGroup>[];
  for (final entry in tasted) {
    final lastTastedAt = entry.state.lastTastedAt!;
    final day = DateTime(
      lastTastedAt.year,
      lastTastedAt.month,
      lastTastedAt.day,
    );
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.entries.add(entry);
    } else {
      groups.add(_TastedDayGroup(day: day, entries: [entry]));
    }
  }
  return groups;
}

/// Personal companion screen: a plan of drinks the user wants to try, and a
/// timeline of drinks they've already tasted this festival.
///
/// Kept at the historical `/:festivalId/favorites` route — see AGENTS.md and
/// the my-festival-campaign skill for why the URL is a public contract that
/// must not be renamed even though the tab label/icon have moved on.
class MyFestivalScreen extends StatefulWidget {
  const MyFestivalScreen({required this.festivalId, super.key});

  final String festivalId;

  @override
  State<MyFestivalScreen> createState() => _MyFestivalScreenState();
}

class _MyFestivalScreenState extends State<MyFestivalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<BeerProvider>();
      unawaited(provider.analyticsService.logFestivalLogViewed());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    // Festival-flash guard: without this, switching festivals can render one
    // frame of the previous festival's entries before the provider catches up
    // (issue #397). Keep it first in build().
    if (provider.currentFestival.id != widget.festivalId) {
      return buildLoadingScaffold();
    }

    final festivalId = widget.festivalId;
    final myFestivalEntries = provider.myFestivalEntries;
    // Tasted takes display priority: a drink that is both want-to-try and
    // tasted is shown only in the Tasted section (vision.md "Screen layout").
    final wantToTry = myFestivalEntries.wantToTry
        .where((entry) => !entry.state.isTasted)
        .toList();
    final tasted = myFestivalEntries.tasted;
    final theme = Theme.of(context);
    final totalCount = wantToTry.length + tasted.length;

    return PageTitle(
      pageTitle: 'My Festival',
      contextLabel: provider.currentFestival.name,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.currentFestival.name,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '$totalCount in My Festival',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [buildOverflowMenu(context)],
        ),
        body: wantToTry.isEmpty && tasted.isEmpty
            ? _buildEmptyState(theme)
            : ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  ..._buildWantToTrySection(context, festivalId, wantToTry),
                  const Divider(height: 32, thickness: 1),
                  ..._buildTastedSection(context, festivalId, tasted, theme),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    const message =
        'Nothing in My Festival yet. Browse drinks and add them to your '
        'want-to-try list, or mark them as tasted, to see them here.';
    return Semantics(
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_bar_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing in My Festival yet',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse drinks and add them to your want-to-try list, '
                'or mark them as tasted, to build your personal diary.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWantToTrySection(
    BuildContext context,
    String festivalId,
    List<MyFestivalEntry> wantToTry,
  ) {
    return [
      _buildSectionHeader('Want to Try', wantToTry.length),
      if (wantToTry.isEmpty)
        _buildSectionEmptyHint('No drinks in your want-to-try list yet.')
      else
        for (final entry in wantToTry)
          _buildWantToTryRow(context, festivalId, entry),
    ];
  }

  List<Widget> _buildTastedSection(
    BuildContext context,
    String festivalId,
    List<MyFestivalEntry> tasted,
    ThemeData theme,
  ) {
    if (tasted.isEmpty) {
      return [
        _buildSectionHeader('Tasted', 0),
        _buildSectionEmptyHint(
          'Nothing tasted yet — mark a drink as tasted to start your log.',
        ),
      ];
    }
    final dayGroups = _groupTastedByDay(tasted);
    return [
      _buildSectionHeader('Tasted', tasted.length),
      for (final group in dayGroups) ...[
        _buildDayHeader(theme, group.day),
        for (final entry in group.entries)
          _buildTastedRow(context, festivalId, entry),
      ],
    ];
  }

  Widget _buildSectionHeader(String title, int count) {
    return Semantics(
      header: true,
      label: '$title section, $count ${count == 1 ? 'drink' : 'drinks'}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionEmptyHint(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildDayHeader(ThemeData theme, DateTime day) {
    final label = _dayHeaderFormat.format(day);
    return Semantics(
      header: true,
      label: 'Tasted on $label',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWantToTryRow(
    BuildContext context,
    String festivalId,
    MyFestivalEntry entry,
  ) {
    final drink = entry.drink;
    if (drink == null) {
      return _buildPlaceholderRow(entry, wantToTry: true);
    }
    return Semantics(
      label: '${drink.name}, by ${drink.breweryName}, want to try',
      hint: 'Double tap for details',
      button: true,
      child: ListTile(
        key: ValueKey('want-to-try-${drink.id}'),
        leading: const Icon(Icons.radio_button_unchecked),
        title: Text(drink.name),
        subtitle: Text(drink.breweryName),
        onTap: () => navigateToRoute(
          context,
          buildDrinkDetailPath(festivalId, drink.category, drink.id),
        ),
      ),
    );
  }

  Widget _buildTastedRow(
    BuildContext context,
    String festivalId,
    MyFestivalEntry entry,
  ) {
    final drink = entry.drink;
    if (drink == null) {
      return _buildPlaceholderRow(entry, wantToTry: false);
    }
    final count = entry.state.tastingCount;
    final lastTastedAt = entry.state.lastTastedAt!;
    final tastedLabel = 'Tasted $count×';
    final timeLabel = _tastingTimeFormat.format(lastTastedAt);
    return Semantics(
      label:
          '${drink.name}, by ${drink.breweryName}, $tastedLabel, '
          'last tasted at $timeLabel',
      hint: 'Double tap for details',
      button: true,
      child: ListTile(
        key: ValueKey('tasted-${drink.id}'),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(drink.name),
        subtitle: Text('${drink.breweryName} • $tastedLabel'),
        trailing: Text(timeLabel),
        onTap: () => navigateToRoute(
          context,
          buildDrinkDetailPath(festivalId, drink.category, drink.id),
        ),
      ),
    );
  }

  Widget _buildPlaceholderRow(
    MyFestivalEntry entry, {
    required bool wantToTry,
  }) {
    return Semantics(
      label:
          '${wantToTry ? 'Want to try' : 'Tasted'} drink ${entry.drinkId}, '
          'details loading',
      child: ListTile(
        key: ValueKey('placeholder-${entry.drinkId}'),
        title: Text(entry.drinkId),
        subtitle: const Text('Loading details…'),
      ),
    );
  }
}
