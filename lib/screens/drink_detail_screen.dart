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
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              drink.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              drink.breweryName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
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
    );
  }

  Widget _buildInfoChips(BuildContext context, Drink drink) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoChip(
            label: '${drink.abv.toStringAsFixed(1)}%',
            icon: Icons.percent,
          ),
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
