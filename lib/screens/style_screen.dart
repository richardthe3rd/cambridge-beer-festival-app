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
  // Layout constants for the header
  static const double _headerHeight = 280.0;
  static const double _appBarButtonHeight = 56.0;

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
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Filter drinks for this style
    final styleDrinks = provider.allDrinks
        .where((d) => d.style?.toLowerCase() == widget.style.toLowerCase())
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
            expandedHeight: _headerHeight,
            collapsedHeight: _headerHeight, // Keep header always visible (never collapse)
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
            flexibleSpace: SafeArea(
              child: _buildHeader(context, widget.style, styleDrinks),
            ),
          ),
          SliverToBoxAdapter(
            child: BreadcrumbBar(
              backLabel: provider.currentFestival.id,
              contextLabel: widget.style,
              onBack: () {
                if (_canPop(context) && context.canPop()) {
                  context.pop();
                } else {
                  context.go(buildFestivalHome(widget.festivalId));
                }
              },
              onBackLabelTap: () => context.go(buildFestivalHome(widget.festivalId)),
              // Note: onContextLabelTap is not provided because this is the current page
            ),
          ),
          ...DrinkListSection.buildSlivers(
            context: context,
            festivalId: widget.festivalId,
            title: 'Drinks',
            drinks: styleDrinks,
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String style, List<Drink> drinks) {
    final theme = Theme.of(context);
    final provider = context.read<BeerProvider>();
    final brightness = theme.brightness;
    final avgAbv = drinks.fold<double>(0, (sum, d) => sum + d.abv) / drinks.length;
    final categories = drinks.map((d) => d.category).toSet();
    final mainCategory = categories.isNotEmpty ? categories.first : 'beer';
    final accentColor = CategoryColorHelper.getCategoryColor(context, mainCategory);

    return FutureBuilder<String?>(
      future: StyleDescriptionHelper.getStyleDescription(style),
      builder: (context, snapshot) {
        final description = snapshot.data;

        return Container(
          width: double.infinity,
          height: _headerHeight, // Match the SliverAppBar height
          padding: const EdgeInsets.only(top: _appBarButtonHeight), // Space for app bar buttons
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brightness == Brightness.dark
                  ? [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    ]
                  : [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
            ),
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 8.0,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Decorative dots pattern
              Positioned(
                left: 30,
                bottom: 30,
                child: Row(
                  children: List.generate(
                    5,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 8 - (index * 1.2),
                      height: 8 - (index * 1.2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.2 - (index * 0.03)),
                      ),
                    ),
                  ),
                ),
              ),
              // Content - style info
              Positioned(
                left: 24,
                right: 24,
                top: 8,
                bottom: 16,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Style name with festival context
                      SelectableText(
                        '$style at ${provider.currentFestival.name}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description (if available)
                      if (description != null && description.isNotEmpty) ...[
                        SelectableText(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.format_list_numbered,
                              label: 'Drinks',
                              value: '${drinks.length}',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.percent,
                              label: 'Avg ABV',
                              value: '${avgAbv.toStringAsFixed(1)}%',
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

/// Widget for displaying a statistic card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
