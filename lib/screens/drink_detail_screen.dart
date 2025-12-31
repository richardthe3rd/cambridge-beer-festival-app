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
      appBar: AppBar(
        title: _buildAppBarTitle(context, provider, drink),
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
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Header section
                SliverToBoxAdapter(
                  child: _buildHeader(context, drink, theme),
                ),
                // Hero info card
                SliverToBoxAdapter(
                  child: _buildHeroCard(context, drink, theme),
                ),
                // Description
                if (drink.notes != null && drink.notes!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildDescription(context, drink, theme),
                  ),
                // Allergens warning
                if (drink.allergenText != null)
                  SliverToBoxAdapter(
                    child: _buildAllergens(context, drink, theme),
                  ),
                // Brewery section
                SliverToBoxAdapter(
                  child: _buildBrewerySection(context, drink),
                ),
                // Similar drinks
                ..._buildSimilarDrinksSlivers(context, drink, provider),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            ),
          ),
          // Sticky bottom action bar
          _buildBottomActionBar(context, drink, provider),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, BeerProvider provider, Drink drink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${provider.currentFestival.id} > ${drink.breweryName}',
          style: Theme.of(context).textTheme.labelSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Drink drink, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drink name
          SelectableText(
            drink.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Brewery info
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  drink.breweryLocation.isNotEmpty
                      ? '${drink.breweryName} · ${drink.breweryLocation}'
                      : drink.breweryName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Drink drink, ThemeData theme) {
    final strengthLabel = ABVStrengthHelper.getABVStrengthLabel(drink.abv);
    final isSoldOut = drink.availabilityStatus == AvailabilityStatus.out;

    return HeroInfoCard(
      rows: [
        // Style, dispense, ABV
        HeroInfoRow(
          icon: Icons.local_drink,
          text: '${drink.style ?? drink.category} · ${StringFormattingHelper.capitalizeFirst(drink.dispense)} · ${drink.abv.toStringAsFixed(1)}% ABV ($strengthLabel)',
        ),
        // Availability
        if (drink.bar != null || isSoldOut)
          HeroInfoRow(
            icon: isSoldOut ? Icons.cancel : Icons.check_circle,
            text: isSoldOut
                ? 'Sold Out'
                : 'Available at ${drink.bar}',
            iconColor: isSoldOut
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, Drink drink, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'About This Drink'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SelectableText(
            drink.notes!,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildAllergens(BuildContext context, Drink drink, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
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
      ),
    );
  }

  Widget _buildBrewerySection(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    final breweryLabel = drink.breweryLocation.isNotEmpty
        ? '${drink.breweryName} from ${drink.breweryLocation}'
        : drink.breweryName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Brewery'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Semantics(
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
        ),
      ],
    );
  }

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

  List<(Drink, String)> _getSimilarDrinksWithReasons(Drink drink, List<Drink> allDrinks) {
    final results = <(Drink, String)>[];

    for (final d in allDrinks) {
      if (d.id == drink.id) continue;

      if (d.producer.id == drink.producer.id) {
        results.add((d, 'Same brewery'));
        continue;
      }

      if (d.style == drink.style &&
          d.style != null &&
          (d.abv - drink.abv).abs() <= 0.5) {
        results.add((d, 'Same style, similar strength'));
        continue;
      }
    }

    return results.take(10).toList();
  }

  Widget _buildBottomActionBar(BuildContext context, Drink drink, BeerProvider provider) {
    return BottomActionBar(
      actions: [
        // Tasted checkbox
        ActionButton(
          icon: drink.isTasted ? Icons.check_box : Icons.check_box_outline_blank,
          label: 'Tasted',
          isActive: drink.isTasted,
          onPressed: () => provider.toggleTasted(drink),
          semanticLabel: drink.isTasted
              ? 'Mark ${drink.name} as not tasted'
              : 'Mark ${drink.name} as tasted',
        ),
        // Rating
        Semantics(
          label: 'Rate ${drink.name}',
          child: InkWell(
            onTap: () => _showRatingDialog(context, drink, provider),
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 24,
                    color: drink.rating != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drink.rating != null ? '${drink.rating}/5' : 'Rate',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: drink.rating != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: drink.rating != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Favorite
        ActionButton(
          icon: drink.isFavorite ? Icons.favorite : Icons.favorite_border,
          label: 'Favorite',
          isActive: drink.isFavorite,
          onPressed: () => provider.toggleFavorite(drink),
          semanticLabel: drink.isFavorite
              ? 'Remove ${drink.name} from favorites'
              : 'Add ${drink.name} to favorites',
        ),
        // Share
        ActionButton(
          icon: Icons.share,
          label: 'Share',
          onPressed: () => _shareDrink(context, drink, provider.currentFestival),
          semanticLabel: 'Share ${drink.name}',
        ),
      ],
    );
  }

  void _showRatingDialog(BuildContext context, Drink drink, BeerProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rate ${drink.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRating(
              rating: drink.rating,
              isEditable: true,
              starSize: 40,
              onRatingChanged: (rating) {
                provider.setRating(drink, rating);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          if (drink.rating != null)
            TextButton(
              onPressed: () {
                provider.setRating(drink, null);
                Navigator.of(context).pop();
              },
              child: const Text('Clear Rating'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _shareDrink(BuildContext context, Drink drink, Festival festival) {
    final hashtag = festival.hashtag ?? '#${festival.id.replaceAll(_hashtagSafeRegex, '')}';
    Share.share(drink.getShareMessage(hashtag));
    // Log share event (fire and forget)
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logDrinkShared(drink));
  }

  bool _canPop(BuildContext context) {
    try {
      GoRouter.of(context);
      return context.canPop();
    } catch (e) {
      return true;
    }
  }
}
