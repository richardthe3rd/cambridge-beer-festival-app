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

/// The user's personal note for [entry], or null when there is none.
/// Whitespace-only notes are treated as absent.
String? _noteText(MyFestivalEntry entry) {
  final note = entry.state.notes?.trim();
  return (note == null || note.isEmpty) ? null : note;
}

/// The recognition/decision facts for a Want to Try row: brewery, style (when
/// known), and ABV — the cues that help you pick your next pour.
String _wantToTryFacts(Drink drink) {
  final facts = StringBuffer(drink.breweryName);
  final style = drink.style;
  if (style != null) facts.write(' • $style');
  facts.write(' • ${drink.abv.toStringAsFixed(1)}%');
  return facts.toString();
}

/// A short "act now" phrase for an at-risk [status], or null when the drink is
/// comfortably available (or availability is unknown) — used in the row's
/// Semantics label to mirror the visible [_AvailabilityHint] badge.
String? _availabilityPhrase(AvailabilityStatus? status) {
  switch (status) {
    case AvailabilityStatus.out:
      return 'Sold out';
    case AvailabilityStatus.veryLow:
      return 'Nearly gone';
    case AvailabilityStatus.low:
      return 'Low availability';
    case AvailabilityStatus.plenty:
    case AvailabilityStatus.good:
    case AvailabilityStatus.unknown:
    case null:
      return null;
  }
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

  /// Counts calls to `_MyFestivalScreenState.build()`, for rebuild-scope
  /// regression tests (issue #563). Incremented inside an `assert`, whose
  /// body is stripped in profile and release builds, so this costs nothing in
  /// production. Mirrors `DrinkDetailScreen.debugBuildCount`.
  @visibleForTesting
  static int debugBuildCount = 0;

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
    assert(() {
      MyFestivalScreen.debugBuildCount++;
      return true;
    }());
    // Narrowed per #563 (the last bare context.watch<BeerProvider>() in
    // lib/) to exactly the three values this screen reads: the current
    // festival's id (festival-flash guard) and name (app bar/PageTitle), and
    // myFestivalEntries. myFestivalEntries is memoised in BeerProvider
    // against _personalStateRevision/_catalogueRevision/festival id
    // (beer_provider.dart:186-189) — it returns the SAME cached instance
    // until one of those changes, so selecting on its object identity is a
    // valid, cheap rebuild trigger rather than a false-positive on every
    // notification.
    final currentFestivalId = context.select<BeerProvider, String>(
      (p) => p.currentFestival.id,
    );
    // Festival-flash guard: without this, switching festivals can render one
    // frame of the previous festival's entries before the provider catches up
    // (issue #397). Keep it first in build().
    if (currentFestivalId != widget.festivalId) {
      return buildLoadingScaffold();
    }

    final currentFestivalName = context.select<BeerProvider, String>(
      (p) => p.currentFestival.name,
    );
    final myFestivalEntries = context.select<BeerProvider, MyFestivalEntries>(
      (p) => p.myFestivalEntries,
    );

    final festivalId = widget.festivalId;
    // Tasted takes display priority: a drink that is both want-to-try and
    // tasted is shown only in the Tasted section (vision.md "Screen layout").
    final wantToTry = myFestivalEntries.wantToTry
        .where((entry) => !entry.state.isTasted)
        .toList();
    final tasted = myFestivalEntries.tasted;
    final theme = Theme.of(context);
    final appBarForeground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final totalCount = wantToTry.length + tasted.length;

    return PageTitle(
      pageTitle: 'My Festival',
      contextLabel: currentFestivalName,
      child: Scaffold(
        appBar: AppBar(
          // The text theme bakes `colorScheme.onSurface` into every style, so
          // using titleMedium/bodySmall unmodified here paints near-black text
          // on the navy app bar (1.45:1 and 1.27:1 — far below WCAG AA). Force
          // the app bar's own foreground colour back on.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentFestivalName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: appBarForeground,
                ),
              ),
              Text(
                '$totalCount in My Festival',
                // Same colour as the title, not a muted variant: the size and
                // weight difference already carries the hierarchy, and a
                // translucent variant would erode contrast on the navy bar.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: appBarForeground,
                ),
              ),
            ],
          ),
          actions: [buildOverflowMenu(context)],
        ),
        body: wantToTry.isEmpty && tasted.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  ..._buildWantToTrySection(festivalId, wantToTry),
                  const Divider(height: 32, thickness: 1),
                  ..._buildTastedSection(festivalId, tasted),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildWantToTrySection(
    String festivalId,
    List<MyFestivalEntry> wantToTry,
  ) {
    return [
      _SectionHeader(title: 'Want to Try', count: wantToTry.length),
      if (wantToTry.isEmpty)
        const _SectionEmptyHint(
          message: 'No drinks in your want-to-try list yet.',
        )
      else
        for (final entry in wantToTry)
          _WantToTryRow(festivalId: festivalId, entry: entry),
    ];
  }

  List<Widget> _buildTastedSection(
    String festivalId,
    List<MyFestivalEntry> tasted,
  ) {
    if (tasted.isEmpty) {
      return [
        const _SectionHeader(title: 'Tasted', count: 0),
        const _SectionEmptyHint(
          message:
              'Nothing tasted yet — mark a drink as tasted to start your log.',
        ),
      ];
    }
    final dayGroups = _groupTastedByDay(tasted);
    return [
      _SectionHeader(title: 'Tasted', count: tasted.length),
      for (final group in dayGroups) ...[
        _DayHeader(day: group.day),
        for (final entry in group.entries)
          _TastedRow(festivalId: festivalId, entry: entry),
      ],
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Icon(
                Icons.local_bar_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '$title section, ${StringFormattingHelper.drinkCountLabel(count)}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        // Use the theme's titleLarge (the app's Playfair "poster" voice) rather
        // than a generic inline TextStyle, so the headers share the app's
        // typographic identity.
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // onSurfaceVariant rather than Colors.grey: the fixed grey is 2.7:1 against
    // a light surface, below the 4.5:1 WCAG AA needs for body text (it only
    // passes in dark mode). The theme colour adapts to both.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

class _WantToTryRow extends StatelessWidget {
  const _WantToTryRow({required this.festivalId, required this.entry});

  final String festivalId;
  final MyFestivalEntry entry;

  @override
  Widget build(BuildContext context) {
    final drink = entry.drink;
    if (drink == null) {
      return _PlaceholderRow(entry: entry, wantToTry: true);
    }
    final note = _noteText(entry);
    // Want to Try is a *plan*, not a record: surface recognition/decision cues
    // the tasted timeline omits. Availability is the actionable one — a beer on
    // your shortlist can sell out — so hint it only when it's at risk.
    final availability = drink.availabilityStatus;
    final availabilityPhrase = _availabilityPhrase(availability);
    return _RowCard(
      accent: CategoryColorHelper.getAccentColor(
        drink.category,
        Theme.of(context).brightness,
      ),
      child: Semantics(
        label:
            '${drink.name}, ${drink.abv.toStringAsFixed(1)}% ABV'
            '${drink.style != null ? ', ${drink.style}' : ''}'
            ', by ${drink.breweryName}'
            '${availabilityPhrase != null ? ', $availabilityPhrase' : ''}'
            ', want to try'
            '${note != null ? ', your note: $note' : ''}',
        hint: 'Double tap for details',
        button: true,
        // The label above is a complete superset of the ListTile's content,
        // so exclude the child nodes to avoid double announcements — matching
        // the DrinkCard pattern.
        excludeSemantics: true,
        child: ListTile(
          key: ValueKey('want-to-try-${drink.id}'),
          leading: const Icon(Icons.radio_button_unchecked),
          title: Text(drink.name),
          subtitle: _RowSubtitle(factsLine: _wantToTryFacts(drink), note: note),
          isThreeLine: note != null,
          // A literal null (not an empty widget) when the drink is comfortably
          // available, so the ListTile reserves no trailing space at all — see
          // [_AvailabilityHint].
          trailing: availabilityPhrase != null
              ? _AvailabilityHint(status: availability)
              : null,
          onTap: () => navigateToRoute(
            context,
            buildDrinkDetailPath(festivalId, drink.category, drink.id),
          ),
        ),
      ),
    );
  }
}

class _TastedRow extends StatelessWidget {
  const _TastedRow({required this.festivalId, required this.entry});

  final String festivalId;
  final MyFestivalEntry entry;

  @override
  Widget build(BuildContext context) {
    final drink = entry.drink;
    if (drink == null) {
      return _PlaceholderRow(entry: entry, wantToTry: false);
    }
    final count = entry.state.tastingCount;
    final lastTastedAt = entry.state.lastTastedAt!;
    final tastedLabel = 'Tasted $count×';
    final timeLabel = _tastingTimeFormat.format(lastTastedAt);
    final note = _noteText(entry);
    return _RowCard(
      accent: CategoryColorHelper.getAccentColor(
        drink.category,
        Theme.of(context).brightness,
      ),
      child: Semantics(
        label:
            '${drink.name}, by ${drink.breweryName}, $tastedLabel, '
            'last tasted at $timeLabel'
            '${note != null ? ', your note: $note' : ''}',
        hint: 'Double tap for details',
        button: true,
        excludeSemantics: true,
        child: ListTile(
          key: ValueKey('tasted-${drink.id}'),
          leading: Icon(
            Icons.check_circle,
            color: CategoryColorHelper.getTastedColor(
              Theme.of(context).brightness,
            ),
          ),
          title: Text(drink.name),
          subtitle: _RowSubtitle(
            factsLine: '${drink.breweryName} • $tastedLabel',
            note: note,
          ),
          isThreeLine: note != null,
          trailing: Text(timeLabel),
          onTap: () => navigateToRoute(
            context,
            buildDrinkDetailPath(festivalId, drink.category, drink.id),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.entry, required this.wantToTry});

  final MyFestivalEntry entry;
  final bool wantToTry;

  @override
  Widget build(BuildContext context) {
    final note = _noteText(entry);
    // No catalogue category yet, so no accent colour — a muted edge keeps the
    // card shape consistent with hydrated rows.
    return _RowCard(
      accent: null,
      child: Semantics(
        label:
            '${wantToTry ? 'Want to try' : 'Tasted'} drink ${entry.drinkId}, '
            'details loading'
            '${note != null ? ', your note: $note' : ''}',
        excludeSemantics: true,
        child: ListTile(
          key: ValueKey('placeholder-${entry.drinkId}'),
          title: Text(entry.drinkId),
          subtitle: _RowSubtitle(factsLine: 'Loading details…', note: note),
          isThreeLine: note != null,
        ),
      ),
    );
  }
}

/// Wraps a My Festival row in a card with a category-coloured left accent
/// edge, matching the drinks list's [DrinkCard] visual language so the two
/// surfaces share one motif. [accent] is null for placeholder rows (no
/// catalogue category yet), which fall back to a muted [outlineVariant] edge.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.accent, required this.child});

  final Color? accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edge = accent ?? Theme.of(context).colorScheme.outlineVariant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: edge, width: 4)),
        ),
        child: child,
      ),
    );
  }
}

/// A [ListTile] subtitle showing the drink's own facts ([factsLine]) and,
/// when present, the user's [note] on a second, visually distinct line.
///
/// The note is truncated to two lines — the full note stays on the drink
/// detail screen. Rendered in a subtle italic [onSurfaceVariant] style so it
/// reads as the user's own annotation rather than a catalogue fact.
class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle({required this.factsLine, this.note});

  final String factsLine;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final currentNote = note;
    if (currentNote == null) return Text(factsLine);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(factsLine),
        Text(
          currentNote,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A compact availability badge for a Want to Try row, shown only for at-risk
/// states (sold out / nearly gone / low) so a planned beer's dwindling stock
/// is visible at a glance. Styled to echo the drinks list's availability
/// chip.
///
/// Callers only construct this for an at-risk [status] (see
/// [_availabilityPhrase]) — for the comfortable states pass a literal `null`
/// [ListTile.trailing] instead, so the row's layout doesn't reserve trailing
/// space for an empty badge. The comfortable-state branches below exist only
/// so the switch stays exhaustive without a wildcard arm (matching the
/// convention in [_availabilityPhrase] and `_AvailabilityChip`, see #534).
class _AvailabilityHint extends StatelessWidget {
  const _AvailabilityHint({required this.status});

  final AvailabilityStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bound in the switch so the at-risk status is non-null below; the calm
    // states all return early.
    final AvailabilityStatus atRisk;
    final IconData icon;
    final String label;
    switch (status) {
      case AvailabilityStatus.out:
        atRisk = AvailabilityStatus.out;
        icon = Icons.cancel;
        label = 'Sold Out';
      case AvailabilityStatus.veryLow:
        atRisk = AvailabilityStatus.veryLow;
        icon = Icons.warning_amber;
        label = 'Nearly Gone';
      case AvailabilityStatus.low:
        atRisk = AvailabilityStatus.low;
        icon = Icons.warning;
        label = 'Low';
      case AvailabilityStatus.plenty:
      case AvailabilityStatus.good:
      case AvailabilityStatus.unknown:
      case null:
        return const SizedBox.shrink();
    }
    final color = CategoryColorHelper.getAvailabilityColor(
      atRisk,
      theme.colorScheme,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
