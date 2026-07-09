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
                // Header section
                SliverToBoxAdapter(
                  child: DetailHeader(
                    title: drink.name,
                    subtitle: drink.breweryLocation.isNotEmpty
                        ? '${drink.breweryName} · ${drink.breweryLocation}'
                        : drink.breweryName,
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  ),
                ),
                // Hero info card
                SliverToBoxAdapter(
                  child: _buildHeroCard(context, drink, theme),
                ),
                // Style chip for navigation
                if (drink.style != null)
                  SliverToBoxAdapter(child: _buildStyleChip(context, drink)),
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
                // Personal tasting log + notes — kept high so a user's own
                // tastings and notes are reachable without scrolling past the
                // brewery link and the (long) Similar Drinks list.
                SliverToBoxAdapter(
                  child: _buildPersonalSection(context, drink, provider, theme),
                ),
                // Brewery section
                SliverToBoxAdapter(child: _buildBrewerySection(context, drink)),
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

  Widget _buildHeroCard(BuildContext context, Drink drink, ThemeData theme) {
    final isSoldOut = drink.availabilityStatus == AvailabilityStatus.out;

    return HeroInfoCard(
      rows: [
        // Style, dispense, ABV
        HeroInfoRow(
          icon: Icons.local_drink,
          text:
              '${drink.style ?? drink.category} · ${StringFormattingHelper.capitalizeFirst(drink.dispense)} · ${drink.abv.toStringAsFixed(1)}%',
        ),
        // Availability
        if (drink.bar != null || isSoldOut)
          HeroInfoRow(
            icon: isSoldOut ? Icons.cancel : Icons.check_circle,
            text: isSoldOut ? 'Sold Out' : 'Available at ${drink.bar}',
            iconColor: isSoldOut
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
        // Vegan indicator
        if (drink.isVegan == true)
          HeroInfoRow(
            icon: Icons.eco,
            text: 'Vegan',
            iconColor: theme.colorScheme.primary,
            semanticLabel: 'This drink is vegan',
          ),
      ],
    );
  }

  Widget _buildStyleChip(BuildContext context, Drink drink) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Semantics(
        label: 'View all ${drink.style} drinks',
        hint: 'Double tap to see all drinks with this style',
        button: true,
        child: InkWell(
          onTap: () => _navigateToStyleScreen(context, drink.style!),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_drink,
                  size: 16,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  drink.style!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ],
            ),
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

  /// The user's personal tasting log and notes for this drink. The tasting
  /// list only renders once at least one tasting exists; the notes editor is
  /// always available so a note can be added at any time.
  Widget _buildPersonalSection(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
    ThemeData theme,
  ) {
    // Show tastings most-recent first; the stored order is not significant.
    final tastings = List<DateTime>.of(drink.tastingEvents)
      ..sort((a, b) => b.compareTo(a));
    final userNotes = drink.userNotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tastings.isNotEmpty) ...[
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
        const SectionHeader(title: 'Your Notes'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
          child: Semantics(
            label: userNotes != null && userNotes.isNotEmpty
                ? 'Edit your notes for ${drink.name}'
                : 'Add your notes for ${drink.name}',
            button: true,
            child: Card(
              child: InkWell(
                key: const ValueKey('user-notes-editor'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editNotes(context, drink, provider),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          userNotes != null && userNotes.isNotEmpty
                              ? userNotes
                              : 'Tap to add your notes',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: userNotes != null && userNotes.isNotEmpty
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontStyle: userNotes != null && userNotes.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    // The dialog owns its TextEditingController lifecycle (see
    // [_NotesEditorDialog]) so the controller outlives the route's exit
    // animation — disposing it here would crash mid-transition.
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _NotesEditorDialog(
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

  Widget _buildBrewerySection(BuildContext context, Drink drink) {
    final breweryLabel = drink.breweryLocation.isNotEmpty
        ? '${drink.breweryName} from ${drink.breweryLocation}'
        : drink.breweryName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Brewery'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Semantics(
            label: 'View all drinks from $breweryLabel',
            hint: 'Double tap to see brewery details',
            button: true,
            child: Card(
              child: ListTile(
                title: Text(drink.breweryName),
                subtitle: drink.breweryLocation.isNotEmpty
                    ? Text(drink.breweryLocation)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => navigateToRoute(
                  context,
                  buildBreweryPath(widget.festivalId, drink.producerId),
                ),
              ),
            ),
          ),
        ),
      ],
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
        child: SizedBox(
          height: 168,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
        // Rating
        Semantics(
          label: 'Rate ${drink.name}',
          hint: 'Double tap to rate from 1 to 5 stars',
          button: true,
          child: InkWell(
            onTap: () => _showRatingDialog(context, drink, provider),
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 24,
                    color: drink.rating != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drink.rating != null ? '${drink.rating}/5' : 'Rate',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: drink.rating != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: drink.rating != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Want to Try — the bookmark toggle (was the heart "Favorite")
        ActionButton(
          key: const ValueKey('want-to-try-action'),
          icon: drink.isFavorite ? Icons.bookmark : Icons.bookmark_border,
          label: 'Want to Try',
          isActive: drink.isFavorite,
          onPressed: () => provider.toggleFavorite(drink),
          semanticLabel: drink.isFavorite
              ? 'Remove ${drink.name} from want to try'
              : 'Add ${drink.name} to want to try',
        ),
        // Share
        ActionButton(
          icon: Icons.share,
          label: 'Share',
          onPressed: () => unawaited(_shareDrink(context, drink)),
          semanticLabel: 'Share ${drink.name}',
        ),
      ],
    );
  }

  void _showRatingDialog(
    BuildContext context,
    Drink drink,
    BeerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rate ${drink.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRating(
              rating: drink.rating,
              isEditable: true,
              starSize: 40,
              onRatingChanged: (rating) {
                provider.setRating(drink, rating);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          if (drink.rating != null)
            TextButton(
              onPressed: () {
                provider.setRating(drink, null);
                Navigator.of(context).pop();
              },
              child: const Text('Clear Rating'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          ),
                        ),
                      ),
                      _buildStatusIcon(theme),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drink.breweryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${drink.abv.toStringAsFixed(1)}% ABV',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      // Same "tasted" green used on the drink card's status badge.
      final tastedColor = theme.brightness == Brightness.dark
          ? const Color(0xFF4CAF50)
          : const Color(0xFF2E7D32);
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

/// A dialog for editing a drink's personal notes. It owns its
/// [TextEditingController] so the controller is disposed only when the dialog
/// is unmounted — after the route's exit animation — avoiding a
/// "used after being disposed" crash. Pops the entered text on Save, or `null`
/// on Cancel.
class _NotesEditorDialog extends StatefulWidget {
  final String drinkName;
  final String initialText;

  const _NotesEditorDialog({
    required this.drinkName,
    required this.initialText,
  });

  @override
  State<_NotesEditorDialog> createState() => _NotesEditorDialogState();
}

class _NotesEditorDialogState extends State<_NotesEditorDialog> {
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
    return AlertDialog(
      title: Text('Notes for ${widget.drinkName}'),
      content: TextField(
        key: const ValueKey('user-notes-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 5,
        minLines: 3,
        decoration: const InputDecoration(
          hintText: 'What did you think?',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
