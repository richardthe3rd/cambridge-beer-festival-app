import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'widgets.dart';

/// Generic detail screen for entities (breweries, styles, etc.) that display a list of drinks
///
/// This widget provides a common layout pattern used by BreweryScreen and StyleScreen:
/// - SliverAppBar with expandable header
/// - Custom header content
/// - Filtered list of drinks
/// - Analytics tracking
class EntityDetailScreen extends StatefulWidget {
  /// Festival ID for URL scoping
  final String festivalId;

  /// Title to display in the app bar
  final String title;

  /// Back button label for breadcrumb bar
  final String backLabel;

  /// Message to show when no drinks are found
  final String notFoundMessage;

  /// Message to show in the app bar when entity is not found
  final String notFoundTitle;

  /// Height of the expanded app bar
  final double expandedHeight;

  /// Function to filter drinks from the full list
  final List<Drink> Function(List<Drink> allDrinks) filterDrinks;

  /// Builder for the header content
  ///
  /// Note: This function is only called when [drinks] is non-empty,
  /// as guaranteed by the EntityDetailScreen implementation.
  /// It's safe to access drinks.first or calculate averages without null checks.
  final Widget Function(BuildContext context, List<Drink> drinks) buildHeader;

  /// Optional analytics logger called after first frame
  /// The filtered drinks list is passed to the callback for convenience.
  final Future<void> Function(List<Drink> drinks)? logAnalytics;

  const EntityDetailScreen({
    super.key,
    required this.festivalId,
    required this.title,
    required this.backLabel,
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
        final provider = context.read<BeerProvider>();
        final filteredDrinks = widget.filterDrinks(provider.allDrinks);
        if (filteredDrinks.isNotEmpty) {
          widget.logAnalytics!(filteredDrinks);
        }
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
                : Semantics(
                    label: 'Go to home screen',
                    hint: 'Double tap to return to drinks list',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.home),
                      onPressed: () => context.go(buildFestivalHome(widget.festivalId)),
                      tooltip: 'Home',
                    ),
                  ),
            title: Text(widget.title),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Builder(
                  builder: (context) {
                    assert(filteredDrinks.isNotEmpty,
                        'buildHeader should only be called with non-empty drinks list');
                    return widget.buildHeader(context, filteredDrinks);
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: BreadcrumbBar(
              backLabel: widget.backLabel,
              contextLabel: widget.title,
              onBack: () {
                if (_canPop(context) && context.canPop()) {
                  context.pop();
                } else {
                  context.go(buildFestivalHome(widget.festivalId));
                }
              },
            ),
          ),
          ...DrinkListSection.buildSlivers(
            context: context,
            festivalId: widget.festivalId,
            title: 'Drinks',
            drinks: filteredDrinks,
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
