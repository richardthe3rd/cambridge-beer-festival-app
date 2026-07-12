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
    final provider = context.watch<BeerProvider>();

    // Show loading state while drinks are being fetched
    if (provider.isLoading) {
      return buildLoadingScaffold();
    }

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
    final styleCount = breweryDrinks
        .map((d) => d.style)
        .whereType<String>()
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context, provider),
        leading: buildHomeLeadingButton(context, widget.festivalId),
      ),
      body: CustomScrollView(
        slivers: [
          // Identity hero
          SliverToBoxAdapter(
            child: BreweryHeroPanel(
              producer: producer,
              drinkCount: breweryDrinks.length,
              styleCount: styleCount,
              accentCategory: _dominantCategory(breweryDrinks),
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
    );
  }

  /// Build the app bar title with breadcrumb navigation
  Widget _buildAppBarTitle(BuildContext context, BeerProvider provider) {
    return Text(
      provider.currentFestival.name,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The most frequent category among [drinks], used to colour the hero's edge.
  /// A brewery can span categories; ties break to the first category seen in
  /// iteration order, keeping the result deterministic.
  String _dominantCategory(List<Drink> drinks) {
    final counts = <String, int>{};
    for (final drink in drinks) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    var dominant = drinks.first.category;
    var best = 0;
    for (final drink in drinks) {
      final count = counts[drink.category]!;
      if (count > best) {
        best = count;
        dominant = drink.category;
      }
    }
    return dominant;
  }
}
