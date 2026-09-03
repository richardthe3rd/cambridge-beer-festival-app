import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing detailed festival information
class FestivalInfoScreen extends StatelessWidget {
  const FestivalInfoScreen({required this.festivalId, super.key});

  final String festivalId;

  /// Counts runs of this screen's [Selector] builder, for rebuild-scope
  /// regression tests (issue #523). Incremented inside an `assert`, whose
  /// body is stripped in profile and release builds, so this costs nothing
  /// in production. Mirrors `DrinkDetailScreen.debugBuildCount`.
  ///
  /// Note the position: it counts the *builder*, not [build]. Unlike the
  /// other narrowed screens, this one's provider subscription lives in the
  /// Selector's own State rather than in [build], so [build] does not re-run
  /// on a provider notification. Measured on a same-id festival refresh: a
  /// counter in [build] increments 0 times, one in the builder increments 1.
  /// Moving this into [build] would silently make the rebuild tests vacuous.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  Widget build(BuildContext context) {
    // Unlike BreweryScreen/DrinksScreen/StyleScreen (#523/#550), this screen
    // deliberately does NOT select currentFestival.id (or the whole Festival,
    // which compares by id via Festival.==, festival.dart:151). Those other
    // screens select the id purely as a festival-flash guard and read their
    // actual content from elsewhere; this screen's entire body is ~20 fields
    // read off Festival itself. FestivalController.setSource/
    // setCachedFestivals (festival_controller.dart:85-91, :116-124) re-point
    // _currentFestival at a REFRESHED Festival object carrying the SAME id
    // whenever the festivals list reloads from cache to network — an
    // id-select (or a Festival-object select) would treat that as "nothing
    // changed" and this screen would keep showing stale metadata after a
    // refresh. Festival is fully immutable (every field final,
    // festival.dart:20-36), so any content change necessarily produces a new
    // instance — use identity, not ==, as the rebuild trigger.
    return Selector<BeerProvider, Festival>(
      selector: (_, p) => p.currentFestival,
      shouldRebuild: (prev, next) => !identical(prev, next),
      builder: (context, festival, _) {
        assert(() {
          FestivalInfoScreen.debugBuildCount++;
          return true;
        }());

        return PageTitle(
          pageTitle: 'Festival Info',
          contextLabel: festival.name,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Festival Info'),
              leading: canPopNavigation(context)
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.home),
                      tooltip: 'Home',
                      onPressed: () => context.go('/'),
                    ),
              actions: [buildDrinksListAction(context, festivalId)],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, festival),
                  _buildOverview(context, festival),
                  if (festival.location != null || festival.address != null)
                    _buildLocation(context, festival),
                  if (festival.hours != null && festival.hours!.isNotEmpty)
                    _buildHours(context, festival),
                  if (festival.description != null)
                    _buildDescription(context, festival),
                  _buildActions(context, festival),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            festival.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          if (festival.formattedDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 8),
                SelectableText(
                  festival.formattedDates,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (festival.hashtag != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              festival.hashtag!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
          if (festival.isActive) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: festival.availableBeverageTypes.map((type) {
              final label = BeverageTypeHelper.formatBeverageType(type);
              return Semantics(
                label: 'Show all $label',
                hint: 'Double tap to see this festival\'s $label',
                button: true,
                excludeSemantics: true,
                child: ActionChip(
                  key: ValueKey('beverage-type-$type'),
                  label: Text(label),
                  avatar: Icon(
                    BeverageTypeHelper.getBeverageIcon(type),
                    size: 18,
                  ),
                  onPressed: () => _showCategory(context, type),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Filter the drinks list to a single beverage type and return to it.
  ///
  /// The category filter lives on the provider, not in the URL — there is no
  /// category-filtered route — so the selection is set before navigating.
  /// [returnToDrinksList] collapses the detail stack rather than pushing a
  /// second drinks list on top of this screen.
  void _showCategory(BuildContext context, String beverageType) {
    // The chip carries a feed-file slug; the filter matches Drink.category.
    // Those differ for international-beer and apple-juice, so go through
    // BeverageCategories.feedCategoryFor rather than filtering on the slug —
    // filtering on the raw slug matched nothing for those two.
    context.read<BeerProvider>().selectOnlyCategory(
      BeverageCategories.feedCategoryFor(beverageType),
    );
    returnToDrinksList(context, festivalId);
  }

  Widget _buildLocation(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(festival.location ?? 'Location TBA'),
              subtitle: festival.address != null
                  ? Text(festival.address!)
                  : null,
              trailing: festival.latitude != null && festival.longitude != null
                  ? Semantics(
                      label: 'Open location in maps',
                      hint: 'Double tap to view festival location on map',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _openMaps(context, festival),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHours(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Festival Hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: festival.hours!.entries.map((entry) {
                  // A day with two sessions arrives as one comma-separated
                  // string ('12:00 - 15:00, 17:00 - 22:00'). Give each
                  // session its own line so a long day name never squeezes
                  // the value into a wrap that splits a single time range
                  // across two lines.
                  final sessions = entry.value
                      .split(',')
                      .map((session) => session.trim())
                      .where((session) => session.isNotEmpty)
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final session
                                  in sessions.isEmpty
                                      ? [entry.value]
                                      : sessions)
                                Text(
                                  session,
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.end,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            festival.description!,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Festival festival) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (festival.charityPartnerName != null &&
              festival.charityDonationUrl != null) ...[
            Semantics(
              label: 'Donate to ${festival.charityPartnerName}',
              hint: 'Double tap to open donation page in browser',
              button: true,
              child: FilledButton.icon(
                onPressed: () => _openDonation(context, festival),
                icon: const Icon(Icons.favorite),
                label: Text('Donate to ${festival.charityPartnerName}'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (festival.websiteUrl != null)
            Semantics(
              label: 'Visit festival website',
              hint: 'Double tap to open festival website in browser',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () => _openWebsite(context, festival),
                icon: const Icon(Icons.language),
                label: const Text('Visit Festival Website'),
              ),
            ),
          if (festival.websiteUrl != null) const SizedBox(height: 12),
          Semantics(
            label: 'View app source code on GitHub',
            hint: 'Double tap to open GitHub repository in browser',
            button: true,
            child: OutlinedButton.icon(
              onPressed: () => _openGitHub(context),
              icon: const Icon(Icons.code),
              label: const Text('View App on GitHub'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDonation(BuildContext context, Festival festival) async {
    if (festival.charityDonationUrl == null) return;
    await UrlLauncherHelper.launchURL(
      context,
      festival.charityDonationUrl!,
      errorMessage: 'Could not open donation page',
    );
  }

  Future<void> _openMaps(BuildContext context, Festival festival) async {
    if (festival.latitude == null || festival.longitude == null) return;

    final url =
        'https://www.google.com/maps/search/?api=1&query=${festival.latitude},${festival.longitude}';
    await UrlLauncherHelper.launchURL(
      context,
      url,
      errorMessage: 'Could not open maps',
    );
  }

  Future<void> _openWebsite(BuildContext context, Festival festival) async {
    if (festival.websiteUrl == null) return;

    await UrlLauncherHelper.launchURL(
      context,
      festival.websiteUrl!,
      errorMessage: 'Could not open website',
    );
  }

  Future<void> _openGitHub(BuildContext context) async {
    await UrlLauncherHelper.launchURL(
      context,
      kGithubUrl,
      errorMessage: 'Could not open GitHub',
    );
  }
}
