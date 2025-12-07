import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

/// Screen showing detailed information about a drink
class DrinkDetailScreen extends StatefulWidget {
  final String drinkId;

  const DrinkDetailScreen({super.key, required this.drinkId});

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Log drink viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final drink = provider.getDrinkById(widget.drinkId);
      if (drink != null) {
        unawaited(provider.analyticsService.logDrinkViewed(drink));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final drink = provider.getDrinkById(widget.drinkId);

    if (drink == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Drink Not Found')),
        body: const Center(child: Text('This drink could not be found.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            title: Text(drink.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareDrink(context, drink, provider.currentFestival),
              ),
              IconButton(
                icon: Icon(
                  drink.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed: () => provider.toggleFavorite(drink),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: _buildHeader(context, drink),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRatingSection(context, drink, provider),
                _buildInfoChips(context, drink),
                if (drink.notes != null) _buildDescription(context, drink),
                if (drink.allergenText != null) _buildAllergens(context, drink),
                _buildBrewerySection(context, drink, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareDrink(BuildContext context, Drink drink, Festival festival) {
    // Use festival hashtag, or generate a hashtag-safe version from the ID
    final hashtag = festival.hashtag ?? '#${festival.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}';
    Share.share(drink.getShareMessage(hashtag));
    // Log share event (fire and forget)
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logDrinkShared(drink));
  }

  void _navigateToStyleScreen(BuildContext context, String style) {
    context.go('/style/${Uri.encodeComponent(style)}');
  }

  Widget _buildHeader(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(context, drink);
    final brightness = theme.brightness;
    final initial = drink.name.isNotEmpty ? drink.name[0].toUpperCase() : '?';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brightness == Brightness.dark
              ? [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withOpacity(0.8),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withOpacity(0.3),
                ],
        ),
        border: Border(
          left: BorderSide(
            color: categoryColor,
            width: 8.0,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Large decorative letter
          Positioned(
            right: -20,
            top: -30,
            child: Opacity(
              opacity: 0.06,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 160,
                  fontWeight: FontWeight.w900,
                  color: categoryColor,
                  height: 1.0,
                ),
              ),
            ),
          ),
          // Wave pattern using small circles
          Positioned(
            left: 0,
            bottom: 0,
            child: Row(
              children: List.generate(
                8,
                (index) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 6,
                  height: 6 + (index % 3) * 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: categoryColor.withOpacity(0.15 - (index * 0.015)),
                  ),
                ),
              ),
            ),
          ),
          // Content
          ClipRect(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, kToolbarHeight, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  drink.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  drink.breweryName,
                  style: theme.textTheme.titleMedium,
                ),
                if (drink.breweryLocation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    drink.breweryLocation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    final abvColor = _getABVColor(context, drink.abv);
    final isSoldOut = drink.availabilityStatus == AvailabilityStatus.out;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ABV with strength indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.percent, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'ABV: ${drink.abv.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getABVStrengthLabel(drink.abv),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (drink.abv / 15.0).clamp(0.0, 1.0),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: abvColor,
                        minHeight: 6.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sold out indicator
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cancel,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This drink is sold out',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Other info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (drink.style != null)
                _InfoChip(
                  label: drink.style!,
                  icon: Icons.local_drink,
                  onTap: () => _navigateToStyleScreen(context, drink.style!),
                ),
              _InfoChip(
                label: _formatDispense(drink.dispense),
                icon: Icons.liquor,
              ),
              if (drink.bar != null)
                _InfoChip(
                  label: drink.bar!,
                  icon: Icons.location_on,
                ),
              if (drink.statusText != null)
                _InfoChip(
                  label: drink.statusText!,
                  icon: Icons.info_outline,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDispense(String dispense) {
    if (dispense.isEmpty) return dispense;
    return dispense[0].toUpperCase() + dispense.substring(1);
  }

  Widget _buildRatingSection(BuildContext context, Drink drink, BeerProvider provider) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Rating', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              StarRating(
                rating: drink.rating,
                isEditable: true,
                starSize: 32,
                onRatingChanged: (rating) => provider.setRating(drink, rating),
              ),
              if (drink.rating != null) ...[
                const SizedBox(width: 16),
                Text(
                  '${drink.rating}/5',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(drink.notes!, style: theme.textTheme.bodyLarge),
    );
  }

  Widget _buildAllergens(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Text(
            'Contains: ${drink.allergenText}',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildBrewerySection(BuildContext context, Drink drink, BeerProvider provider) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brewery', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(drink.breweryName),
              subtitle: drink.breweryLocation.isNotEmpty 
                  ? Text(drink.breweryLocation) 
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/brewery/${drink.producer.id}'),
            ),
          ),
        ],
      ),
    );
  }

  /// Get color for drink category
  /// Colors are theme-aware and supplementary visual aids, not primary indicators (accessibility)
  Color _getCategoryColor(BuildContext context, Drink drink) {
    final category = drink.category.toLowerCase();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    if (category.contains('beer')) {
      // Amber-like color
      return brightness == Brightness.dark
          ? colorScheme.secondary.withOpacity(0.8)
          : colorScheme.secondary;
    } else if (category.contains('cider')) {
      // Green-ish color
      return brightness == Brightness.dark
          ? const Color(0xFF8BC34A).withOpacity(0.8)
          : const Color(0xFF689F38);
    } else if (category.contains('perry')) {
      // Lime-ish color
      return brightness == Brightness.dark
          ? const Color(0xFFCDDC39).withOpacity(0.8)
          : const Color(0xFFAFB42B);
    } else if (category.contains('mead')) {
      // Yellow-ish color
      return brightness == Brightness.dark
          ? const Color(0xFFFFEB3B).withOpacity(0.8)
          : const Color(0xFFF9A825);
    } else if (category.contains('wine')) {
      // Deep purple/red color
      return brightness == Brightness.dark
          ? const Color(0xFF9C27B0).withOpacity(0.8)
          : const Color(0xFF7B1FA2);
    } else if (category.contains('low') || category.contains('no')) {
      // Blue-ish color
      return brightness == Brightness.dark
          ? colorScheme.primary.withOpacity(0.8)
          : colorScheme.primary;
    }
    // Default fallback
    return colorScheme.outline;
  }

  /// Get color for ABV strength indicator
  /// Low ABV: Blue, Medium: Amber, High: Deep Orange
  Color _getABVColor(BuildContext context, double abv) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    if (abv < 4.0) {
      // Low ABV: Blue-ish
      return brightness == Brightness.dark
          ? colorScheme.primary.withOpacity(0.7)
          : colorScheme.primary;
    } else if (abv < 7.0) {
      // Medium ABV: Amber/Secondary
      return brightness == Brightness.dark
          ? colorScheme.secondary.withOpacity(0.8)
          : colorScheme.secondary;
    } else {
      // High ABV: Deep Orange/Tertiary
      return brightness == Brightness.dark
          ? const Color(0xFFFF5722).withOpacity(0.85)
          : const Color(0xFFE64A19);
    }
  }

  /// Get human-readable label for ABV strength
  String _getABVStrengthLabel(double abv) {
    if (abv < 4.0) {
      return '(Low)';
    } else if (abv < 7.0) {
      return '(Medium)';
    } else {
      return '(High)';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        label: label,
        hint: 'Tap to view details about $label',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: chip,
        ),
      );
    }

    return chip;
  }
}
