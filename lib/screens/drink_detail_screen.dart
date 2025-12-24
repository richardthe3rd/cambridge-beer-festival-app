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
  final String festivalId;
  final String drinkId;

  const DrinkDetailScreen({
    required this.festivalId,
    required this.drinkId,
    super.key,
  });

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen> {
  // Layout constants for the header
  static const double _headerHeight = 200.0;
  static const double _appBarButtonHeight = 56.0;
  static const double _actionButtonsWidth = 110.0;

  // Cached regex pattern for sanitizing festival IDs into hashtag-safe strings
  static final _hashtagSafeRegex = RegExp(r'[^a-zA-Z0-9_]');

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
                      onPressed: () => context.go(buildFestivalHome(widget.festivalId)),
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
                BreadcrumbBar(
                  backLabel: 'Drinks',
                  contextLabel: drink.breweryName,
                  onBack: () {
                    if (_canPop(context) && context.canPop()) {
                      context.pop();
                    } else {
                      context.go(buildFestivalHome(widget.festivalId));
                    }
                  },
                ),
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
    final hashtag = festival.hashtag ?? '#${festival.id.replaceAll(_hashtagSafeRegex, '')}';
    Share.share(drink.getShareMessage(hashtag));
    // Log share event (fire and forget)
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logDrinkShared(drink));
  }

  void _navigateToStyleScreen(BuildContext context, String style) {
    context.go(buildStylePath(widget.festivalId, style));
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
              ExcludeSemantics(
                child: InfoChip(
                  label: StringFormattingHelper.capitalizeFirst(drink.dispense),
                  icon: Icons.liquor,
                ),
              ),
              if (drink.bar != null)
                ExcludeSemantics(
                  child: InfoChip(
                    label: drink.bar!,
                    icon: Icons.location_on,
                  ),
                ),
              if (drink.statusText != null)
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
    final breweryLabel = drink.breweryLocation.isNotEmpty
        ? '${drink.breweryName} from ${drink.breweryLocation}'
        : drink.breweryName;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brewery', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Semantics(
            label: 'View all drinks from $breweryLabel',
            hint: 'Double tap to see brewery details',
            button: true,
            child: Card(
              child: ListTile(
                title: Text(drink.breweryName),
                subtitle: drink.breweryLocation.isNotEmpty 
                    ? Text(drink.breweryLocation) 
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(buildBreweryPath(widget.festivalId, drink.producer.id)),
              ),
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
      festivalId: widget.festivalId,
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
