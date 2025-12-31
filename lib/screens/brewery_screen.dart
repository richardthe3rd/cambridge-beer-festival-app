import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  @override
  void initState() {
    super.initState();
    // Log brewery viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final breweryDrinks = provider.allDrinks
          .where((d) => d.producer.id == widget.breweryId)
          .toList();
      if (breweryDrinks.isNotEmpty) {
        final producer = breweryDrinks.first.producer;
        unawaited(provider.analyticsService.logBreweryViewed(producer.name));
      }
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

    // Get all drinks from this brewery
    final breweryDrinks = provider.allDrinks
        .where((drink) => drink.producer.id == widget.breweryId)
        .toList();

    if (breweryDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brewery Not Found')),
        body: const Center(
            child: Text('No drinks found from this brewery.')),
      );
    }

    // Use the first drink to get brewery details
    final producer = breweryDrinks.first.producer;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context, provider, producer),
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
            child: _buildHeader(context, producer, theme),
          ),
          // Hero info card
          SliverToBoxAdapter(
            child: _buildHeroCard(context, producer, breweryDrinks.length, theme),
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
    );
  }

  /// Build the app bar title with breadcrumb navigation
  Widget _buildAppBarTitle(
    BuildContext context,
    BeerProvider provider,
    Producer producer,
  ) {
    final festivalName = provider.currentFestival.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          producer.name,
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

  /// Build clean white header with brewery name and location
  Widget _buildHeader(BuildContext context, Producer producer, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            producer.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (producer.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    producer.location,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build hero info card with key brewery information
  Widget _buildHeroCard(
    BuildContext context,
    Producer producer,
    int drinkCount,
    ThemeData theme,
  ) {
    final rows = <HeroInfoRow>[
      // Location
      if (producer.location.isNotEmpty)
        HeroInfoRow(
          icon: Icons.location_on,
          text: producer.location,
        ),
      // Drink count
      HeroInfoRow(
        icon: Icons.local_bar,
        text: '$drinkCount ${drinkCount == 1 ? "drink" : "drinks"} at this festival',
      ),
    ];

    return HeroInfoCard(rows: rows);
  }
}
