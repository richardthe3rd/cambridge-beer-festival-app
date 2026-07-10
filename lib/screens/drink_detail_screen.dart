import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Date + time for a single tasting row, e.g. "Tue 10 Jun · 6:45 PM".
final DateFormat _tastingRowFormat = DateFormat('EEE d MMM · h:mm a');

/// Screen showing detailed information about a drink
class DrinkDetailScreen extends StatefulWidget {
  final String festivalId;
  final String drinkId;

  const DrinkDetailScreen({
    required this.festivalId,
    required this.drinkId,
    super.key,
  });

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen> {
  // Cached regex pattern for sanitizing festival IDs into hashtag-safe strings
  static final _hashtagSafeRegex = RegExp(r'[^a-zA-Z0-9_]');

  @override
  void initState() {
    super.initState();
    // Log drink viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final drink = provider.getDrinkById(widget.drinkId);
      if (drink != null) {
        unawaited(provider.analyticsService.logDrinkViewed(drink));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // Show loading state while drinks are being fetched
    if (provider.isLoading) {
      return buildLoadingScaffold();
    }

    final drink = provider.getDrinkById(widget.drinkId);

    if (drink == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Drink Not Found')),
        body: const Center(child: Text('This drink could not be found.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context, provider),
        leading: buildHomeLeadingButton(context, widget.festivalId),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Identity hero — name, brewery link, ABV, facts strip, share.
                SliverToBoxAdapter(
                  child: DrinkHeroPanel(
                    drink: drink,
                    onShareTap: () => unawaited(_shareDrink(context, drink)),
                    onBreweryTap: () => navigateToRoute(
                      context,
                      buildBreweryPath(widget.festivalId, drink.producerId),
                    ),
                    onStyleTap: drink.style != null
                        ? () => _navigateToStyleScreen(context, drink.style!)
                        : null,
                  ),
                ),
                // Your take — the user's own relationship to the drink
                // (want-to-try, rating, note), kept directly under the hero so
                // it reads as distinctly theirs, not the drink's facts.
                SliverToBoxAdapter(
                  child: YourTakeCard(
                    drink: drink,
                    onWantToTryTap: () => provider.toggleFavorite(drink),
                    onRatingChanged: (rating) =>
                        provider.setRating(drink, rating),
                    onEditNote: () => _editNotes(context, drink, provider),
                  ),
                ),
                // Description
                if (drink.notes != null && drink.notes!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildDescription(context, drink, theme),
                  ),
                // Allergens warning
                if (drink.allergenText != null)
                  SliverToBoxAdapter(
                    child: _buildAllergens(context, drink, theme),
                  ),
                // Your tasting log — the record of pours, kept below the
                // catalogue description.
                SliverToBoxAdapter(
                  child: _buildTastingLog(context, drink, provider, theme),
                ),
                // Similar drinks — discovery content, kept last.
                ..._buildSimilarDrinksSlivers(context, drink, provider),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            ),
          ),
          // Sticky bottom action bar
          _buildBottomActionBar(context, drink, provider),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, BeerProvider provider) {
    return Text(
      provider.currentFestival.name,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  void _navigateToStyleScreen(BuildContext context, String style) {
    // Log analytics event
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logStyleViewed(style));

    // Navigate to style screen
    navigateToRoute(context, buildStylePath(widget.festivalId, style));
  }

  Widget _buildDescription(BuildContext context, Drink drink, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'About This Drink'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SelectableText(drink.notes!, style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }

  Widget _buildAllergens(BuildContext context, Drink drink, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                'Contains: ${drink.allergenText}',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The user's tasting log for this drink — one row per recorded pour. Renders
  /// nothing until at least one tasting exists. (Rating and notes now live in
  /// the "Your take" card directly under the hero.)
  Widget _buildTastingLog(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
    ThemeData theme,
  ) {
    if (drink.tastingEvents.isEmpty) return const SizedBox.shrink();

    // Show tastings most-recent first; the stored order is not significant.
    final tastings = List<DateTime>.of(drink.tastingEvents)
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Your Tastings (${tastings.length})'),
        // Tasting timestamps can legitimately collide (rapid consecutive
        // pours truncate to the same millisecond), so key and label each row
        // by its position, not its timestamp — otherwise identical pours
        // produce duplicate sibling keys (a build error) and ambiguous
        // screen-reader/test targets.
        for (final (index, event) in tastings.indexed)
          _buildTastingRow(
            context,
            drink,
            provider,
            theme,
            event,
            index,
            tastings.length,
          ),
      ],
    );
  }

  Widget _buildTastingRow(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
    ThemeData theme,
    DateTime event,
    int index,
    int count,
  ) {
    final label = _tastingRowFormat.format(event);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Semantics(
            label: 'Remove tasting ${index + 1} of $count, $label',
            button: true,
            child: IconButton(
              key: ValueKey('delete-tasting-$index'),
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove this tasting',
              onPressed: () =>
                  _confirmDeleteTasting(context, drink, provider, event),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTasting(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
    DateTime event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this tasting?'),
        content: Text(
          'This removes the tasting recorded on '
          '${_tastingRowFormat.format(event)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await provider.removeTasting(drink, event);
    }
  }

  Future<void> _editNotes(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
  ) async {
    // The sheet owns its TextEditingController lifecycle (see
    // [_NotesEditorSheet]) so the controller outlives the route's exit
    // animation — disposing it here would crash mid-transition.
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _NotesEditorSheet(
        drinkName: drink.name,
        initialText: drink.userNotes ?? '',
      ),
    );
    // A null result means "cancelled"; only persist on an explicit save.
    if (result != null) {
      final trimmed = result.trim();
      await provider.setUserNotes(drink, trimmed.isEmpty ? null : trimmed);
    }
  }

  List<Widget> _buildSimilarDrinksSlivers(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
  ) {
    final similar = _getSimilarDrinksWithReasons(drink, provider.allDrinks);
    if (similar.isEmpty) {
      return const <Widget>[];
    }

    // A horizontal strip of compact cards. Its footprint is fixed regardless of
    // how many similar drinks there are, so this discovery section can never
    // dominate the scroll. Children are laid out eagerly (a Row, not a lazy
    // builder) so every card stays in the tree for widget-test finders.
    return [
      const SliverToBoxAdapter(child: SectionHeader(title: 'Similar Drinks')),
      SliverToBoxAdapter(
        // No fixed height: IntrinsicHeight sizes the strip to the tallest
        // card's content and stretches the others to match, so cards stay
        // equal height while still growing with the user's text scale. A fixed
        // height would clip the name/reason at large accessibility font sizes.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, (d, reason)) in similar.indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  _SimilarDrinkCard(
                    drink: d,
                    reason: reason,
                    festivalId: widget.festivalId,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<(Drink, String)> _getSimilarDrinksWithReasons(
    Drink drink,
    List<Drink> allDrinks,
  ) {
    final results = <(Drink, String)>[];

    for (final d in allDrinks) {
      if (d.id == drink.id) continue;

      // Don't recommend a drink you can't get. Exclude only *known* sold-out
      // drinks — unknown or low stock stays, so the carousel doesn't empty out
      // when a festival reports no live availability.
      if (d.availabilityStatus == AvailabilityStatus.out) continue;

      if (drink.isSameBrewery(d)) {
        results.add((d, 'Same brewery'));
        continue;
      }

      if (d.style == drink.style &&
          d.style != null &&
          (d.abv - drink.abv).abs() <= 0.5) {
        results.add((d, 'Same style, similar strength'));
        continue;
      }
    }

    return results.take(10).toList();
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
  ) {
    return BottomActionBar(
      actions: [
        // Log tasting — appends a pour each tap (multi-tasting). The additive
        // "+" icon signals this is an append action, not a toggle.
        ActionButton(
          key: const ValueKey('tasted-action'),
          icon: Icons.add_circle_outline,
          label: drink.tastingCount == 0
              ? 'Drunk it!'
              : 'Tasted ${drink.tastingCount}×',
          isActive: drink.isTasted,
          onPressed: () => provider.addTasting(drink),
          semanticLabel: drink.tastingCount == 0
              ? 'Log a tasting of ${drink.name}'
              : 'Tasted ${drink.name} ${drink.tastingCount} '
                    '${drink.tastingCount == 1 ? 'time' : 'times'}, '
                    'double tap to log another tasting',
        ),
      ],
    );
  }

  Future<void> _shareDrink(BuildContext context, Drink drink) async {
    final provider = context.read<BeerProvider>();
    // Use the drink's own festivalId rather than provider.currentFestival, which
    // can lag on deep-link entry before the provider catches up to the route.
    final festival =
        provider.getFestivalById(drink.festivalId) ?? provider.currentFestival;
    final hashtag =
        festival.hashtag ?? '#${festival.id.replaceAll(_hashtagSafeRegex, '')}';
    final url =
        'https://cambeerfestival.app${buildDrinkDetailPath(drink.festivalId, drink.category, drink.id)}';
    await SharePlus.instance.share(
      ShareParams(text: drink.getShareMessage(hashtag, url: url)),
    );
    unawaited(provider.analyticsService.logDrinkShared(drink));
  }
}

/// A compact, fixed-width card for the Similar Drinks carousel. The whole card
/// is a single navigation button; [reason] explains why the drink surfaced
/// (e.g. "Same brewery"). Uses plain [Text] rather than [SelectableText]
/// because the card is a tap target — text selection would fight both the tap
/// and the horizontal scroll gesture.
class _SimilarDrinkCard extends StatelessWidget {
  final Drink drink;
  final String reason;
  final String festivalId;

  const _SimilarDrinkCard({
    required this.drink,
    required this.reason,
    required this.festivalId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabel(),
      button: true,
      hint: 'Double tap for details',
      excludeSemantics: true,
      child: SizedBox(
        width: 200,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            key: ValueKey(drink.id),
            onTap: () => navigateToRoute(
              context,
              buildDrinkDetailPath(festivalId, drink.category, drink.id),
            ),
            child: Container(
              // Coloured left edge by category, matching the drink list card.
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: CategoryColorHelper.getAccentColor(drink.category),
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name grows to its natural 1–2 lines; IntrinsicHeight
                      // keeps all cards the same height without a fixed box
                      // that would clip at large text scales.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              drink.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                          _buildStatusIcon(theme),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        drink.breweryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${drink.abv.toStringAsFixed(1)}% ABV',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reason,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A small tasted / want-to-try indicator, mirroring the drink card's status
  /// language (tasted takes priority over want-to-try). Empty when neither.
  Widget _buildStatusIcon(ThemeData theme) {
    if (drink.tastingCount > 0) {
      // Shared "tasted" green, same as the drink card's status badge.
      final tastedColor = CategoryColorHelper.getTastedColor(theme.brightness);
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(Icons.check_circle, size: 18, color: tastedColor),
      );
    }
    if (drink.isFavorite) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(Icons.bookmark, size: 18, color: theme.colorScheme.primary),
      );
    }
    return const SizedBox.shrink();
  }

  String _semanticLabel() {
    final buffer = StringBuffer()
      ..write(drink.name)
      ..write(', ${drink.abv.toStringAsFixed(1)} percent ABV')
      ..write(', by ${drink.breweryName}')
      ..write('. $reason.');
    if (drink.tastingCount > 0) {
      buffer.write(
        drink.tastingCount == 1
            ? ' Tasted once.'
            : ' Tasted ${drink.tastingCount} times.',
      );
    } else if (drink.isFavorite) {
      buffer.write(' Added to want to try.');
    }
    return buffer.toString();
  }
}

/// A roomy bottom sheet for editing a drink's personal notes. It owns its
/// [TextEditingController] so the controller is disposed only when the sheet is
/// unmounted — after the route's exit animation — avoiding a "used after being
/// disposed" crash. Pops the entered text on Save, or `null` on Cancel/dismiss.
class _NotesEditorSheet extends StatefulWidget {
  final String drinkName;
  final String initialText;

  const _NotesEditorSheet({required this.drinkName, required this.initialText});

  @override
  State<_NotesEditorSheet> createState() => _NotesEditorSheetState();
}

class _NotesEditorSheetState extends State<_NotesEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Grow with the keyboard so the field and actions stay visible.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Notes for ${widget.drinkName}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('user-notes-field'),
                controller: _controller,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What did you think?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
