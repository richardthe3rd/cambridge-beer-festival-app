import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing drinks of a specific style
class StyleScreen extends StatefulWidget {
  final String festivalId;
  final String style;

  const StyleScreen({
    required this.festivalId,
    required this.style,
    super.key,
  });

  @override
  State<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends State<StyleScreen> {
  @override
  void initState() {
    super.initState();
    // Log style viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      unawaited(provider.analyticsService.logStyleViewed(widget.style));
    });
  }

  /// Safely check if we can pop (handles test contexts without GoRouter)
  bool _canPop(BuildContext context) {
    try {
      return GoRouter.of(context).canPop();
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // Show loading state while drinks are being fetched
    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get all drinks with this style
    final styleDrinks = provider.allDrinks
        .where((drink) =>
            drink.product.style?.toLowerCase() == widget.style.toLowerCase())
        .toList();

    if (styleDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style Not Found')),
        body: const Center(
            child: Text('No drinks found with this style.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context, provider),
        leading: _canPop(context)
            ? null
            : Semantics(
                label: 'Go to home screen',
                hint: 'Double tap to return to drinks list',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () =>
                      context.go(buildFestivalHome(widget.festivalId)),
                  tooltip: 'Home',
                ),
              ),
      ),
      body: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: _buildHeader(context, theme),
          ),
          // Hero info card
          SliverToBoxAdapter(
            child: _buildHeroCard(context, styleDrinks, theme),
          ),
          // Description (if available)
          SliverToBoxAdapter(
            child: FutureBuilder<String?>(
              future: StyleDescriptionHelper.getStyleDescription(widget.style),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return _buildDescription(context, snapshot.data!, theme);
                }
                return const SizedBox.shrink();
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

  /// Build the app bar title with breadcrumb navigation
  Widget _buildAppBarTitle(BuildContext context, BeerProvider provider) {
    final festivalName = provider.currentFestival.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.style,
          style: Theme.of(context).textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          festivalName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build clean white header with style name
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.style,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Build hero info card with key style information
  Widget _buildHeroCard(
    BuildContext context,
    List<Drink> styleDrinks,
    ThemeData theme,
  ) {
    // Calculate average ABV
    final avgABV = styleDrinks.isEmpty
        ? 0.0
        : styleDrinks.map((d) => d.product.abv).reduce((a, b) => a + b) /
            styleDrinks.length;

    final rows = <HeroInfoRow>[
      // Drink count
      HeroInfoRow(
        icon: Icons.local_bar,
        text: '${styleDrinks.length} ${styleDrinks.length == 1 ? "drink" : "drinks"} at this festival',
      ),
      // Average ABV
      if (styleDrinks.isNotEmpty)
        HeroInfoRow(
          icon: Icons.science,
          text: 'Average ABV: ${avgABV.toStringAsFixed(1)}%',
        ),
    ];

    return HeroInfoCard(rows: rows);
  }

  /// Build description section
  Widget _buildDescription(
    BuildContext context,
    String description,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'About This Style'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SelectableText(
            description,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
