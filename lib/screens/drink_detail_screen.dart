import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import 'brewery_screen.dart';

/// Screen showing detailed information about a drink
class DrinkDetailScreen extends StatefulWidget {
  final String drinkId;

  const DrinkDetailScreen({super.key, required this.drinkId});

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    // Log drink viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final drink = provider.getDrinkById(widget.drinkId);
      if (drink != null) {
        unawaited(_analyticsService.logDrinkViewed(drink));
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

    return Scaffold(
      appBar: AppBar(
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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, drink),
            _buildRatingSection(context, drink, provider),
            _buildInfoChips(context, drink),
            if (drink.notes != null) _buildDescription(context, drink),
            if (drink.allergenText != null) _buildAllergens(context, drink),
            _buildDetails(context, drink),
            _buildBrewerySection(context, drink, provider),
          ],
        ),
      ),
    );
  }

  void _shareDrink(BuildContext context, Drink drink, Festival festival) {
    // Use festival hashtag, or generate a hashtag-safe version from the ID
    final hashtag = festival.hashtag ?? '#${festival.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}';
    Share.share(drink.getShareMessage(hashtag));
    // Log share event (fire and forget)
    unawaited(_analyticsService.logDrinkShared(drink));
  }

  Widget _buildHeader(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
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
    );
  }

  Widget _buildInfoChips(BuildContext context, Drink drink) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('${drink.abv.toStringAsFixed(1)}%')),
          if (drink.style != null) Chip(label: Text(drink.style!)),
          Chip(label: Text(drink.dispense)),
          if (drink.bar != null) Chip(label: Text(drink.bar!)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(drink.notes!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
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
          Text(
            'Contains: ${drink.allergenText}',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, Drink drink) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DetailRow(label: 'Category', value: drink.category),
          _DetailRow(label: 'ABV', value: '${drink.abv.toStringAsFixed(1)}%'),
          _DetailRow(label: 'Dispense', value: drink.dispense),
          if (drink.style != null) _DetailRow(label: 'Style', value: drink.style!),
          if (drink.bar != null) _DetailRow(label: 'Bar', value: drink.bar!),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BreweryScreen(breweryId: drink.producer.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
