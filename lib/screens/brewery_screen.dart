import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

/// Screen showing a brewery and its drinks
class BreweryScreen extends StatelessWidget {
  final String breweryId;

  const BreweryScreen({super.key, required this.breweryId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BeerProvider>();

    return EntityDetailScreen(
      title: _getBreweryName(context),
      notFoundTitle: 'Brewery Not Found',
      notFoundMessage: 'This brewery could not be found.',
      expandedHeight: 280,
      filterDrinks: (allDrinks) =>
          allDrinks.where((d) => d.producer.id == breweryId).toList(),
      buildHeader: (context, drinks) {
        final producer = drinks.first.producer;
        return _buildHeader(context, producer, drinks.length);
      },
      logAnalytics: (drinks) async {
        final producer = drinks.first.producer;
        unawaited(provider.analyticsService.logBreweryViewed(producer.name));
      },
    );
  }

  String _getBreweryName(BuildContext context) {
    final provider = context.read<BeerProvider>();
    final breweryDrinks =
        provider.allDrinks.where((d) => d.producer.id == breweryId).toList();
    if (breweryDrinks.isEmpty) {
      return 'Brewery';
    }
    return breweryDrinks.first.producer.name;
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
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
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
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
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
                color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
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
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                        child: SelectableText(
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
                        Expanded(
                          child: SelectableText(
                            producer.location,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
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
                        SelectableText(
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
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
}
