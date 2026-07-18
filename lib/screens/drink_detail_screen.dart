import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _DrinkDetailScreenState extends State<DrinkDetailScreen>
    with SingleTickerProviderStateMixin {
  // Cached regex pattern for sanitizing festival IDs into hashtag-safe strings
  static final _hashtagSafeRegex = RegExp(r'[^a-zA-Z0-9_]');

  // A quick scale-bounce on the "Drunk it!" FAB, so logging a pour is felt at
  // the button as well as confirmed by the SnackBar below.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  // A screen-scoped messenger so the "Drunk it!" confirmation SnackBar (with
  // its drink-specific Undo) can't outlive this screen — navigating away
  // covers or disposes it rather than floating it over an unrelated screen.
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey();

  // Drives the collapsing app-bar title: the drink name fades into the bar as
  // the hero card scrolls under it.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_pulseController);

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
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Log a pour with layered confirmation: a haptic thunk, a scale-bounce on
  /// the FAB, and a SnackBar (with Undo) — so it clearly feels like it
  /// happened even when the tasting log is scrolled out of view.
  Future<void> _logTasting(BeerProvider provider, Drink drink) async {
    final messenger = _messengerKey.currentState;
    unawaited(HapticFeedback.mediumImpact());
    _pulseController.forward(from: 0);

    // addTasting returns the exact timestamp it logged, so Undo removes that
    // precise pour rather than guessing at the newest event.
    final event = await provider.addTasting(drink);
    if (!mounted || messenger == null) return;

    final updated = provider.getDrinkById(drink.id);
    if (updated == null || updated.tastingEvents.isEmpty) return;

    final count = updated.tastingCount;
    final message = count == 1
        ? 'Logged your first tasting'
        : 'Logged — $count tastings';

    _showUndoSnackBar(
      messenger,
      message: message,
      onUndo: () => unawaited(provider.removeTasting(updated, event)),
    );
  }

  /// The shared confirmation shape for reversible tasting mutations: a
  /// floating SnackBar whose message dismisses on tap, with an Undo action.
  void _showUndoSnackBar(
    ScaffoldMessengerState messenger, {
    required String message,
    required VoidCallback onUndo,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          // A small gap above the FAB — by default Flutter floats a SnackBar
          // flush against a centered FAB with no breathing room at all.
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          duration: const Duration(seconds: 3),
          // SnackBars only swipe-dismiss by default, which most users never
          // discover; let a tap on the message itself dismiss it too.
          content: Semantics(
            label: message,
            button: true,
            hint: 'Double tap to dismiss',
            child: GestureDetector(
              onTap: messenger.hideCurrentSnackBar,
              child: Text(message),
            ),
          ),
          action: SnackBarAction(label: 'Undo', onPressed: onUndo),
        ),
      );
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

    return PageTitle(
      pageTitle: drink.name,
      contextLabel: provider.currentFestival.name,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          // The one repeated action — logging a pour — floats; want-to-try,
          // rating and share have moved to the hero / "Your take" card. Centred so
          // it doesn't sit over the right-aligned tasting-log delete buttons.
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: ScaleTransition(
            scale: _pulseScale,
            child: FloatingActionButton.extended(
              key: const ValueKey('tasted-action'),
              onPressed: () => unawaited(_logTasting(provider, drink)),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Drunk it!'),
              tooltip: 'Log a tasting of ${drink.name}',
            ),
          ),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Pinned bar: festival name at the top, fading to the drink name
              // and brewery once the hero card below scrolls off.
              CollapsingDetailAppBar(
                scrollController: _scrollController,
                contextTitle: provider.currentFestival.name,
                collapsedTitle: drink.name,
                collapsedSubtitle: drink.breweryName,
                leading: buildHomeLeadingButton(context, widget.festivalId),
                actions: [buildDrinksListAction(context, widget.festivalId)],
              ),
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
              // Your take — the user's own relationship to the drink (want-to-try,
              // rating, note). Below the drink's content so ownership reads in two
              // clean blocks: the drink, then you.
              SliverToBoxAdapter(
                child: YourTakeCard(
                  drink: drink,
                  onWantToTryTap: () => provider.toggleFavorite(drink),
                  onRatingChanged: (rating) =>
                      provider.setRating(drink, rating),
                  onNotesChanged: (notes) =>
                      provider.setUserNotes(drink, notes),
                ),
              ),
              // Your tasting log — the record of pours.
              SliverToBoxAdapter(
                child: _buildTastingLog(context, drink, provider, theme),
              ),
              // Similar drinks — discovery content, kept last.
              ..._buildSimilarDrinksSlivers(context, drink, provider),
              // Extra bottom room so the floating button never covers content.
              const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToStyleScreen(BuildContext context, String style) {
    // Log analytics event
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logStyleViewed(style));

    // Navigate to style screen
    navigateToRoute(context, buildStylePath(widget.festivalId, style));
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
            hint: 'Double tap to remove immediately. Undo available after.',
            child: IconButton(
              key: ValueKey('delete-tasting-$index'),
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove this tasting',
              onPressed: () => unawaited(
                _deleteTastingWithUndo(context, drink, provider, event),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Remove a tasting immediately (no confirmation dialog) and offer Undo,
  /// mirroring [_logTasting]'s SnackBar shape and Undo pattern.
  Future<void> _deleteTastingWithUndo(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
    DateTime event,
  ) async {
    final messenger = _messengerKey.currentState;
    unawaited(HapticFeedback.mediumImpact());

    await provider.removeTasting(drink, event);
    if (!mounted || messenger == null) return;

    _showUndoSnackBar(
      messenger,
      message: 'Removed — ${_tastingRowFormat.format(event)}',
      onUndo: () => unawaited(provider.addTasting(drink, at: event)),
    );
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
