import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing a brewery and its drinks
class BreweryScreen extends StatefulWidget {
  final String festivalId;
  final String breweryId;

  const BreweryScreen({
    required this.festivalId,
    required this.breweryId,
    super.key,
  });

  @override
  State<BreweryScreen> createState() => _BreweryScreenState();
}

class _BreweryScreenState extends State<BreweryScreen> {
  // Drives the collapsing app-bar title: the brewery name fades into the bar as
  // the hero card scrolls under it.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Log brewery viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final breweryDrinks = provider.allDrinks
          .where((d) => d.producerId == widget.breweryId)
          .toList();
      if (breweryDrinks.isNotEmpty) {
        final producer = breweryDrinks.first.producer;
        unawaited(provider.analyticsService.logBreweryViewed(producer.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Narrow per-concern selects instead of a bare watch<BeerProvider>() —
    // see DrinksScreen (#523/#550) for the established pattern.
    //
    // Festival-flash guard: on a URL-driven festival change the provider
    // switches in a post-frame callback, so without this the screen would
    // resolve its content against the PREVIOUS festival's catalogue for a
    // frame — showing the wrong entity or a spurious "not found" (#397).
    // Festival.== is id-scoped by design, so this selects the id
    // specifically rather than the whole Festival object.
    final currentFestivalId = context.select<BeerProvider, String>(
      (p) => p.currentFestival.id,
    );
    if (currentFestivalId != widget.festivalId) {
      return buildLoadingScaffold();
    }

    // Show loading state while drinks are being fetched
    final isLoading = context.select<BeerProvider, bool>((p) => p.isLoading);
    if (isLoading) {
      return buildLoadingScaffold();
    }

    final currentFestivalName = context.select<BeerProvider, String>(
      (p) => p.currentFestival.name,
    );

    // The catalogue failed to load and nothing is cached (issue #639): the
    // "Brewery Not Found" branch below only checks whether any drink in
    // allDrinks matches this brewery — it can't tell "the catalogue never
    // loaded" from "the catalogue loaded and this brewery genuinely has no
    // drinks in it". Checking `error` first distinguishes the two and gives
    // the user a Retry instead of a dead end.
    final error = context.select<BeerProvider, String?>((p) => p.error);

    // allDrinks changes identity on every catalogue load and every
    // personal-state write (BeerProvider._replaceDrink), but Drink.== is
    // id+festivalId-scoped (drink.dart:321) — so a userState-only change
    // (favourite/rating/tasted/notes) still compares deep-equal under
    // context.select's DeepCollectionEquality, the same trap
    // FestivalInfoScreen documents for Festival.==. A Selector with an
    // identity-based shouldRebuild sidesteps it: it rebuilds exactly when
    // [_setAllDrinks]/[_replaceDrink] hand back a genuinely new list.
    return Selector<BeerProvider, List<Drink>>(
      selector: (_, p) => p.allDrinks,
      shouldRebuild: (prev, next) => !identical(prev, next),
      builder: (context, allDrinks, _) {
        if (error != null && allDrinks.isEmpty) {
          final provider = context.read<BeerProvider>();
          return Scaffold(
            appBar: AppBar(title: const Text('Error Loading Brewery')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CatalogueErrorView(
                  error: error,
                  onRetry: provider.loadDrinks,
                ),
              ),
            ),
          );
        }

        // Get all drinks from this brewery
        final breweryDrinks = allDrinks
            .where((drink) => drink.producerId == widget.breweryId)
            .toList();

        if (breweryDrinks.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Brewery Not Found')),
            body: const Center(
              child: Text('No drinks found from this brewery.'),
            ),
          );
        }

        // Use the first drink to get brewery details
        final producer = breweryDrinks.first.producer;
        // Case-insensitive: the feed doesn't guarantee consistent casing for
        // the same style name across drinks (unlike category, which is
        // normalised at parse time), so compare lowercased to avoid
        // over-counting.
        final styleCount = breweryDrinks
            .map((d) => d.style?.toLowerCase())
            .whereType<String>()
            .toSet()
            .length;

        return PageTitle(
          pageTitle: producer.name,
          contextLabel: currentFestivalName,
          child: Scaffold(
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Pinned bar: festival name at the top, fading to the
                // brewery name once the hero card below scrolls off.
                CollapsingDetailAppBar(
                  scrollController: _scrollController,
                  contextTitle: currentFestivalName,
                  collapsedTitle: producer.name,
                  leading: buildHomeLeadingButton(context, widget.festivalId),
                  actions: [buildDrinksListAction(context, widget.festivalId)],
                ),
                // Identity hero
                SliverToBoxAdapter(
                  child: BreweryHeroPanel(
                    producer: producer,
                    drinkCount: breweryDrinks.length,
                    styleCount: styleCount,
                    accentCategory: CategoryColorHelper.dominantCategory(
                      breweryDrinks,
                    ),
                  ),
                ),
                // Drinks list
                ...DrinkListSection.buildSlivers(
                  context: context,
                  festivalId: widget.festivalId,
                  title: 'Drinks',
                  drinks: breweryDrinks,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
