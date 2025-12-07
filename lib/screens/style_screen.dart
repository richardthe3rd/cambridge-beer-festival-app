import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

/// Screen showing drinks of a specific style
class StyleScreen extends StatefulWidget {
  final String style;

  const StyleScreen({super.key, required this.style});

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // Find all drinks with this style
    final styleDrinks = provider.allDrinks
        .where((d) => d.style == widget.style)
        .toList();

    if (styleDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style Not Found')),
        body: const Center(child: Text('No drinks found for this style.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            title: Text(widget.style),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: _buildHeader(context, widget.style, styleDrinks.length),
              ),
              titlePadding: EdgeInsets.zero,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drinks (${styleDrinks.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final drink = styleDrinks[index];
                return DrinkCard(
                  drink: drink,
                  onTap: () => context.go('/drink/${drink.id}'),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
              childCount: styleDrinks.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String style, int drinkCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, kToolbarHeight, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            style,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$drinkCount drinks at this festival',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
