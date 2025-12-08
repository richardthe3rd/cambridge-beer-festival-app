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

    // Calculate statistics (safe because we checked isEmpty above)
    final avgAbv = styleDrinks.fold<double>(0, (sum, d) => sum + d.abv) / styleDrinks.length;
    final categories = styleDrinks.map((d) => d.category).toSet();
    final mainCategory = categories.isNotEmpty ? categories.first : 'beer';

    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            leading: context.canPop()
                ? null
                : IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () => context.go('/'),
                    tooltip: 'Home',
                  ),
            title: Text(widget.style),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: _buildHeader(context, widget.style, styleDrinks.length, avgAbv, mainCategory),
              ),
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

  Widget _buildHeader(BuildContext context, String style, int drinkCount, double avgAbv, String category) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accentColor = _getCategoryColor(context, category);
    final initial = style.isNotEmpty ? style[0].toUpperCase() : '?';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brightness == Brightness.dark
              ? [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withOpacity(0.7),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withOpacity(0.5),
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
          // Large decorative letter
          Positioned(
            right: -30,
            top: -40,
            child: Opacity(
              opacity: 0.08,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 220,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  height: 1.0,
                ),
              ),
            ),
          ),
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
                    color: accentColor.withOpacity(0.2 - (index * 0.03)),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        style,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.format_list_numbered,
                        label: 'Drinks',
                        value: '$drinkCount',
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
        ],
      ),
    );
  }

  /// Get color for drink category (theme-aware)
  Color _getCategoryColor(BuildContext context, String category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final cat = category.toLowerCase();
    
    if (cat.contains('beer')) {
      return brightness == Brightness.dark
          ? colorScheme.secondary.withOpacity(0.8)
          : colorScheme.secondary;
    } else if (cat.contains('cider')) {
      return brightness == Brightness.dark
          ? const Color(0xFF8BC34A).withOpacity(0.8)
          : const Color(0xFF689F38);
    } else if (cat.contains('perry')) {
      return brightness == Brightness.dark
          ? const Color(0xFFCDDC39).withOpacity(0.8)
          : const Color(0xFFAFB42B);
    } else if (cat.contains('mead')) {
      return brightness == Brightness.dark
          ? const Color(0xFFFFEB3B).withOpacity(0.8)
          : const Color(0xFFF9A825);
    } else if (cat.contains('wine')) {
      return brightness == Brightness.dark
          ? const Color(0xFF9C27B0).withOpacity(0.8)
          : const Color(0xFF7B1FA2);
    } else if (cat.contains('low') || cat.contains('no')) {
      return brightness == Brightness.dark
          ? colorScheme.primary.withOpacity(0.8)
          : colorScheme.primary;
    }
    return colorScheme.outline;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
