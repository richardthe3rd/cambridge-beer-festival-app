import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing drinks of a specific style
class StyleScreen extends StatefulWidget {
  final String festivalId;
  final String style;

  const StyleScreen({required this.festivalId, required this.style, super.key});

  @override
  State<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends State<StyleScreen> {
  // Drives the collapsing app-bar title: the style name fades into the bar as
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
    // Log style viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      unawaited(provider.analyticsService.logStyleViewed(widget.style));
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
        // Get all drinks with this style
        final styleDrinks = allDrinks
            .where(
              (drink) =>
                  drink.style?.toLowerCase() == widget.style.toLowerCase(),
            )
            .toList();

        if (styleDrinks.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Style Not Found')),
            body: const Center(child: Text('No drinks found with this style.')),
          );
        }

        // Style URLs use a lowercase canonical form, so widget.style may be
        // lowercased. Display the original mixed-case name from a matched
        // drink.
        final displayStyle = styleDrinks.first.style ?? widget.style;

        // A style is *usually* scoped to one category, but the match above
        // is on style text alone — a style name could coincidentally be
        // reused across categories. Use the dominant category among the
        // matched drinks rather than an arbitrary first match, so the
        // accent/fact stays representative.
        final category = CategoryColorHelper.dominantCategory(styleDrinks);

        // Average ABV across the matched drinks that actually have one.
        //
        // Drinks of unknown strength are excluded rather than counted as 0.0,
        // which dragged the average down by however many the feed happened to
        // omit (#593). When none of them has an ABV there is no average to
        // report, and the hero says so.
        final knownAbvs = styleDrinks
            .map((d) => d.abv)
            .whereType<double>()
            .toList();
        final avgABV = knownAbvs.isEmpty
            ? null
            : knownAbvs.reduce((a, b) => a + b) / knownAbvs.length;

        return PageTitle(
          pageTitle: displayStyle,
          contextLabel: currentFestivalName,
          child: Scaffold(
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Pinned bar: festival name at the top, fading to the style
                // name once the hero card below scrolls off.
                CollapsingDetailAppBar(
                  scrollController: _scrollController,
                  contextTitle: currentFestivalName,
                  collapsedTitle: displayStyle,
                  leading: buildHomeLeadingButton(context, widget.festivalId),
                  actions: [buildDrinksListAction(context, widget.festivalId)],
                ),
                // Identity hero — the description slots into the same card
                // once the future resolves, so the about section appears in
                // place.
                SliverToBoxAdapter(
                  child: FutureBuilder<String?>(
                    future: StyleDescriptionHelper.getStyleDescription(
                      widget.style,
                    ),
                    builder: (context, snapshot) {
                      return StyleHeroPanel(
                        styleName: displayStyle,
                        category: category,
                        drinkCount: styleDrinks.length,
                        averageAbv: avgABV,
                        description: snapshot.data,
                      );
                    },
                  ),
                ),
                // Drinks list
                ...DrinkListSection.buildSlivers(
                  context: context,
                  festivalId: widget.festivalId,
                  title: 'Drinks',
                  drinks: styleDrinks,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
