import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Screen showing drinks of a specific style
class StyleScreen extends StatelessWidget {
  final String style;

  const StyleScreen({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BeerProvider>();

    return EntityDetailScreen(
      title: style,
      notFoundTitle: 'Style Not Found',
      notFoundMessage: 'No drinks found for this style.',
      expandedHeight: 280,
      filterDrinks: (allDrinks) =>
          allDrinks.where((d) => d.style == style).toList(),
      buildHeader: (context, drinks) {
        final avgAbv = drinks.fold<double>(0, (sum, d) => sum + d.abv) / drinks.length;
        final categories = drinks.map((d) => d.category).toSet();
        final mainCategory = categories.isNotEmpty ? categories.first : 'beer';
        return _buildHeader(context, style, drinks.length, avgAbv, mainCategory);
      },
      logAnalytics: (drinks) async {
        unawaited(provider.analyticsService.logStyleViewed(style));
      },
    );
  }

  Widget _buildHeader(BuildContext context, String style, int drinkCount, double avgAbv, String category) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accentColor = CategoryColorHelper.getCategoryColor(context, category);
    
    return FutureBuilder<String?>(
      future: StyleDescriptionHelper.getStyleDescription(style),
      builder: (context, snapshot) {
        final description = snapshot.data;
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brightness == Brightness.dark
                  ? [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ]
                  : [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
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
              // Content - changed from Positioned to Padding for proper top-to-bottom layout
              Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add spacing to account for title bar when expanded
                      const SizedBox(height: 56),
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
                      // Stats row - made more compact
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
              ),
            ],
          ),
        );
      },
    );
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
