import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
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

    // allDrinks cannot be selected directly — _replaceDrink mutates it in
    // place on every favourite/rating/tasted/notes write, so the List
    // reference never changes and a selector on it would never fire (see
    // BeerProvider.personalStateRevision doc). Subscribe to catalogue
    // reloads and personal-state writes via the revision counters instead;
    // the tuple itself is discarded, this call exists only to subscribe.
    context.select<BeerProvider, (int, int)>(
      (p) => (p.catalogueRevision, p.personalStateRevision),
    );

    final provider = context.read<BeerProvider>();

    // Get all drinks from this brewery
    final breweryDrinks = provider.allDrinks
        .where((drink) => drink.producerId == widget.breweryId)
        .toList();

    if (breweryDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brewery Not Found')),
        body: const Center(child: Text('No drinks found from this brewery.')),
      );
    }

    // Use the first drink to get brewery details
    final producer = breweryDrinks.first.producer;
    // Case-insensitive: the feed doesn't guarantee consistent casing for the
    // same style name across drinks (unlike category, which is normalised at
    // parse time), so compare lowercased to avoid over-counting.
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
            // Pinned bar: festival name at the top, fading to the brewery name
            // once the hero card below scrolls off.
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
  }
}
