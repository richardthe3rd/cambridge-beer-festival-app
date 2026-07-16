import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
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
    final provider = context.watch<BeerProvider>();

    // Show loading state while drinks are being fetched
    if (provider.isLoading) {
      return buildLoadingScaffold();
    }

    // Get all drinks with this style
    final styleDrinks = provider.allDrinks
        .where(
          (drink) => drink.style?.toLowerCase() == widget.style.toLowerCase(),
        )
        .toList();

    if (styleDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style Not Found')),
        body: const Center(child: Text('No drinks found with this style.')),
      );
    }

    // Style URLs use a lowercase canonical form, so widget.style may be
    // lowercased. Display the original mixed-case name from a matched drink.
    final displayStyle = styleDrinks.first.style ?? widget.style;

    // A style is *usually* scoped to one category, but the match above is on
    // style text alone — a style name could coincidentally be reused across
    // categories. Use the dominant category among the matched drinks rather
    // than an arbitrary first match, so the accent/fact stays representative.
    final category = CategoryColorHelper.dominantCategory(styleDrinks);

    // Calculate average ABV across the matched drinks.
    final avgABV =
        styleDrinks.map((d) => d.abv).reduce((a, b) => a + b) /
        styleDrinks.length;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Pinned bar: festival name at the top, fading to the style name once
          // the hero card below scrolls off.
          CollapsingDetailAppBar(
            scrollController: _scrollController,
            contextTitle: provider.currentFestival.name,
            collapsedTitle: displayStyle,
            leading: buildHomeLeadingButton(context, widget.festivalId),
          ),
          // Identity hero — the description slots into the same card once the
          // future resolves, so the about section appears in place.
          SliverToBoxAdapter(
            child: FutureBuilder<String?>(
              future: StyleDescriptionHelper.getStyleDescription(widget.style),
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
    );
  }
}
