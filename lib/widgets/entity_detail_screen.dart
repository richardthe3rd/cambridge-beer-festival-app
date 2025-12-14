import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import 'widgets.dart';

/// Generic detail screen for entities (breweries, styles, etc.) that display a list of drinks
///
/// This widget provides a common layout pattern used by BreweryScreen and StyleScreen:
/// - SliverAppBar with expandable header
/// - Custom header content
/// - Filtered list of drinks
/// - Analytics tracking
class EntityDetailScreen extends StatefulWidget {
  /// Title to display in the app bar
  final String title;

  /// Message to show when no drinks are found
  final String notFoundMessage;

  /// Message to show in the app bar when entity is not found
  final String notFoundTitle;

  /// Height of the expanded app bar
  final double expandedHeight;

  /// Function to filter drinks from the full list
  final List<Drink> Function(List<Drink> allDrinks) filterDrinks;

  /// Builder for the header content
  final Widget Function(BuildContext context, List<Drink> drinks) buildHeader;

  /// Optional analytics logger called after first frame
  final Future<void> Function()? logAnalytics;

  const EntityDetailScreen({
    super.key,
    required this.title,
    required this.notFoundMessage,
    required this.notFoundTitle,
    required this.expandedHeight,
    required this.filterDrinks,
    required this.buildHeader,
    this.logAnalytics,
  });

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Log analytics event after the first frame
    if (widget.logAnalytics != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.logAnalytics!();
      });
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

    // Filter drinks using provided function
    final filteredDrinks = widget.filterDrinks(provider.allDrinks);

    if (filteredDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.notFoundTitle)),
        body: Center(child: Text(widget.notFoundMessage)),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: widget.expandedHeight,
            pinned: true,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            leading: _canPop(context)
                ? null
                : IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () => context.go('/'),
                    tooltip: 'Home',
                  ),
            title: Text(widget.title),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: widget.buildHeader(context, filteredDrinks),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drinks (${filteredDrinks.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final drink = filteredDrinks[index];
                return DrinkCard(
                  key: ValueKey(drink.id),
                  drink: drink,
                  onTap: () => context.go('/drink/${drink.id}'),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
              childCount: filteredDrinks.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  /// Safely check if we can pop (handles tests without GoRouter)
  bool _canPop(BuildContext context) {
    try {
      // Try to get the GoRouter - if this fails, GoRouter is not available
      GoRouter.of(context);
      return context.canPop();
    } catch (e) {
      // GoRouter not available (e.g., in tests), assume we can't pop
      return true; // Return true to hide the home button in tests
    }
  }
}
