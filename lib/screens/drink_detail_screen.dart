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
  // Layout constants for the header
  static const double _headerHeight = 200.0;
  static const double _appBarButtonHeight = 56.0;
  static const double _actionButtonsWidth = 110.0;

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
                      onPressed: () => context.go('/'),
                      tooltip: 'Home',
                    ),
                  ),
            actions: [
              Semantics(
                label: 'Share ${drink.name}',
                hint: 'Double tap to share drink details',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareDrink(context, drink, provider.currentFestival),
                ),
              ),
              Semantics(
                label: drink.isFavorite 
                    ? 'Remove ${drink.name} from favorites' 
                    : 'Add ${drink.name} to favorites',
                hint: 'Double tap to toggle',
                button: true,
                child: IconButton(
                  icon: Icon(
                    drink.isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                  onPressed: () => provider.toggleFavorite(drink),
                ),
              ),
            ],
            flexibleSpace: SafeArea(
              child: _buildHeader(context, drink),
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

  void _navigateToBreweryScreen(BuildContext context, String breweryId) {
    context.go('/brewery/$breweryId');
  }

  Widget _buildHeader(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    final categoryColor = CategoryColorHelper.getCategoryColor(context, drink.category);
    final brightness = theme.brightness;
    final initial = drink.name.isNotEmpty ? drink.name[0].toUpperCase() : '?';
    
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
            top: -10,
            child: Opacity(
              opacity: 0.06,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 140,
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
          // Content - drink name and brewery info with proper spacing for buttons
          Positioned(
            left: 16,
            right: _actionButtonsWidth, // Space for action buttons
            top: 8,
            bottom: 16,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drink name with wrapping
                  Text(
                    drink.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Brewery info
                  Text(
                    drink.breweryName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (drink.breweryLocation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      drink.breweryLocation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    final isSoldOut = drink.availabilityStatus == AvailabilityStatus.out;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Information title
          Text(
            'Key Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // ABV - compact display without progress bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ABVStrengthHelper.getABVColor(context, drink.abv).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ABVStrengthHelper.getABVColor(context, drink.abv).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.percent, 
                  size: 18, 
                  color: ABVStrengthHelper.getABVColor(context, drink.abv),
                ),
                const SizedBox(width: 8),
                Text(
                  '${drink.abv.toStringAsFixed(1)}% ABV',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ABVStrengthHelper.getABVColor(context, drink.abv),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ABVStrengthHelper.getABVStrengthLabel(drink.abv),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Sold out banner - prominent and full width
          if (isSoldOut)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cancel,
                    size: 22,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This drink is sold out',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Interactive and non-interactive chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Brewery chip - now clickable!
              InfoChip(
                label: drink.breweryName,
                icon: Icons.business,
                onTap: () => _navigateToBreweryScreen(context, drink.producer.id),
              ),
              
              // Style chip - clickable
              if (drink.style != null)
                InfoChip(
                  label: drink.style!,
                  icon: Icons.local_drink,
                  onTap: () => _navigateToStyleScreen(context, drink.style!),
                ),
              
              // Dispense - non-clickable
              ExcludeSemantics(
                child: InfoChip(
                  label: StringFormattingHelper.capitalizeFirst(drink.dispense),
                  icon: Icons.liquor,
                ),
              ),
              
              // Bar - non-clickable
              if (drink.bar != null)
                ExcludeSemantics(
                  child: InfoChip(
                    label: drink.bar!,
                    icon: Icons.location_on,
                  ),
                ),
              
              // Status - non-clickable (only show if not sold out, since we show that separately)
              if (drink.statusText != null && !isSoldOut)
                ExcludeSemantics(
                  child: InfoChip(
                    label: drink.statusText!,
                    icon: Icons.info_outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, Drink drink, BeerProvider provider) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Rating section for ${drink.name}',
      child: Padding(
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
      ),
    );
  }

  Widget _buildDescription(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            drink.notes!,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
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
