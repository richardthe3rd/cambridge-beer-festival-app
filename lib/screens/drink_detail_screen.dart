import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/utils.dart';
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

    // Show loading state while drinks are being fetched
    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            expandedHeight: 220,
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
          ..._buildSimilarDrinksSlivers(context, drink, provider),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
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
    final categoryColor = CategoryColorHelper.getCategoryColor(context, drink.category);
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
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
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
                    color: categoryColor.withValues(alpha: 0.15 - (index * 0.015)),
                  ),
                ),
              ),
            ),
          ),
          // Content - brewery info only (drink name is in title bar)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  drink.breweryName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (drink.breweryLocation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    drink.breweryLocation,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
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
                          ABVStrengthHelper.getABVStrengthLabel(drink.abv),
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
                        color: ABVStrengthHelper.getABVColor(context, drink.abv),
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
                InfoChip(
                  label: drink.style!,
                  icon: Icons.local_drink,
                  onTap: () => _navigateToStyleScreen(context, drink.style!),
                ),
              InfoChip(
                label: StringFormattingHelper.capitalizeFirst(drink.dispense),
                icon: Icons.liquor,
              ),
              if (drink.bar != null)
                InfoChip(
                  label: drink.bar!,
                  icon: Icons.location_on,
                ),
              if (drink.statusText != null)
                InfoChip(
                  label: drink.statusText!,
                  icon: Icons.info_outline,
                ),
            ],
          ),
        ],
      ),
    );
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
      child: SelectableText(drink.notes!, style: theme.textTheme.bodyLarge),
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
          Expanded(
            child: SelectableText(
              'Contains: ${drink.allergenText}',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
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

  /// Get list of drinks similar to the given drink with similarity reasons
  /// 
  /// Similarity is based on:
  /// - Same brewery (other drinks from same producer), OR
  /// - Same style AND very close ABV (within 0.5%)
  /// 
  /// Returns a list of tuples containing the drink and the reason it's similar
  List<(Drink, String)> _getSimilarDrinksWithReasons(Drink drink, List<Drink> allDrinks) {
    final results = <(Drink, String)>[];
    
    for (final d in allDrinks) {
      if (d.id == drink.id) continue; // Exclude the current drink
      
      // Check if same brewery
      if (d.producer.id == drink.producer.id) {
        results.add((d, 'Same brewery'));
        continue;
      }
      
      // Check if same style AND very close ABV (within 0.5%)
      if (d.style == drink.style && 
          d.style != null && 
          (d.abv - drink.abv).abs() <= 0.5) {
        results.add((d, 'Same style, similar strength'));
        continue;
      }
    }
    
    return results.take(10).toList(); // Limit to 10 similar drinks
  }

  /// Build similar drinks slivers using the reusable DrinkListSection widget
  /// 
  /// Returns a list of slivers that display similar drinks with reasons, or empty list if none found.
  List<Widget> _buildSimilarDrinksSlivers(BuildContext context, Drink drink, BeerProvider provider) {
    final similarDrinksWithReasons = _getSimilarDrinksWithReasons(drink, provider.allDrinks);
    
    return DrinkListSection.buildSliversWithSubtitles(
      context: context,
      title: 'Similar Drinks',
      drinksWithSubtitles: similarDrinksWithReasons,
      showCount: false,
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
