import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

/// Screen showing a brewery and its drinks
class BreweryScreen extends StatefulWidget {
  final String breweryId;

  const BreweryScreen({super.key, required this.breweryId});

  @override
  State<BreweryScreen> createState() => _BreweryScreenState();
}

class _BreweryScreenState extends State<BreweryScreen> {
  @override
  void initState() {
    super.initState();
    // Log brewery viewed event after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BeerProvider>();
      final breweryDrinks = provider.allDrinks
          .where((d) => d.producer.id == widget.breweryId)
          .toList();
      if (breweryDrinks.isNotEmpty) {
        final producer = breweryDrinks.first.producer;
        unawaited(provider.analyticsService.logBreweryViewed(producer.name));
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

    // Find all drinks from this brewery
    final breweryDrinks = provider.allDrinks
        .where((d) => d.producer.id == widget.breweryId)
        .toList();

    if (breweryDrinks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brewery Not Found')),
        body: const Center(child: Text('This brewery could not be found.')),
      );
    }

    final producer = breweryDrinks.first.producer;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 244,
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
            title: Text(producer.name),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: _buildHeader(context, producer, breweryDrinks.length),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drinks (${breweryDrinks.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final drink = breweryDrinks[index];
                return DrinkCard(
                  drink: drink,
                  onTap: () => context.go('/drink/${drink.id}'),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
              childCount: breweryDrinks.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Producer producer, int drinkCount) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final initials = _getInitials(producer.name);
    
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
      ),
      child: Stack(
        children: [
          // Large decorative letter pattern
          Positioned(
            right: -40,
            top: -20,
            child: Opacity(
              opacity: 0.08,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 180,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  letterSpacing: -8,
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            left: 20,
            bottom: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: 50,
            bottom: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary.withOpacity(0.08),
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        producer.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (producer.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        producer.location,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                if (producer.yearFounded != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Est. ${producer.yearFounded}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Stats card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_drink,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$drinkCount drinks at this festival',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Extract initials from brewery name (max 2 letters)
  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    
    if (words.length == 1) {
      // Single word: take first 2 letters
      final word = words[0];
      if (word.length < 2) return word.toUpperCase();
      return word.substring(0, 2).toUpperCase();
    } else {
      // Multiple words: take first letter of first two words
      // Safe because we filtered empty words above
      final first = words[0].isNotEmpty ? words[0][0] : '';
      final second = (words.length > 1 && words[1].isNotEmpty) ? words[1][0] : '';
      final initials = first + second;
      return initials.isNotEmpty ? initials.toUpperCase() : '?';
    }
  }

  /// Safely check if we can pop (handles tests without GoRouter)
  bool _canPop(BuildContext context) {
    try {
      return context.canPop();
    } catch (e) {
      // GoRouter not available (e.g., in tests), assume we can't pop
      return true; // Return true to hide the home button in tests
    }
  }
}
