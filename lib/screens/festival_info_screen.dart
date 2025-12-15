import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// Screen showing detailed festival information
class FestivalInfoScreen extends StatelessWidget {
  const FestivalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final festival = context.watch<BeerProvider>().currentFestival;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Festival Info'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, festival),
            _buildOverview(context, festival),
            if (festival.location != null || festival.address != null)
              _buildLocation(context, festival),
            if (festival.hours != null && festival.hours!.isNotEmpty)
              _buildHours(context, festival),
            if (festival.description != null) _buildDescription(context, festival),
            _buildActions(context, festival),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            festival.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          if (festival.formattedDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                SelectableText(
                  festival.formattedDates,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
          if (festival.hashtag != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              festival.hashtag!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (festival.isActive) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: festival.availableBeverageTypes.map((type) {
              return Chip(
                label: Text(_formatBeverageType(type)),
                avatar: Icon(_getBeverageIcon(type), size: 18),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(festival.location ?? 'Location TBA'),
              subtitle: festival.address != null ? Text(festival.address!) : null,
              trailing: festival.latitude != null && festival.longitude != null
                  ? Semantics(
                      label: 'Open location in maps',
                      hint: 'Double tap to view festival location on map',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _openMaps(context, festival),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHours(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Festival Hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: festival.hours!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: theme.textTheme.bodyMedium),
                        Text(entry.value, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, Festival festival) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            festival.description!,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Festival festival) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (festival.websiteUrl != null)
            Semantics(
              label: 'Visit festival website',
              hint: 'Double tap to open festival website in browser',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () => _openWebsite(context, festival),
                icon: const Icon(Icons.language),
                label: const Text('Visit Festival Website'),
              ),
            ),
          if (festival.websiteUrl != null) const SizedBox(height: 12),
          Semantics(
            label: 'View app source code on GitHub',
            hint: 'Double tap to open GitHub repository in browser',
            button: true,
            child: OutlinedButton.icon(
              onPressed: () => _openGitHub(context),
              icon: const Icon(Icons.code),
              label: const Text('View App on GitHub'),
            ),
          ),
        ],
      ),
    );
  }

  void _openMaps(BuildContext context, Festival festival) async {
    if (festival.latitude == null || festival.longitude == null) return;

    final url = 'https://www.google.com/maps/search/?api=1&query=${festival.latitude},${festival.longitude}';
    await UrlLauncherHelper.launchURL(
      context,
      url,
      errorMessage: 'Could not open maps',
    );
  }

  void _openWebsite(BuildContext context, Festival festival) async {
    if (festival.websiteUrl == null) return;

    await UrlLauncherHelper.launchURL(
      context,
      festival.websiteUrl!,
      errorMessage: 'Could not open website',
    );
  }

  void _openGitHub(BuildContext context) async {
    await UrlLauncherHelper.launchURL(
      context,
      kGithubUrl,
      errorMessage: 'Could not open GitHub',
    );
  }

  String _formatBeverageType(String type) {
    return type
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  IconData _getBeverageIcon(String type) {
    switch (type) {
      case 'beer':
        return Icons.sports_bar;
      case 'international-beer':
        return Icons.public;
      case 'cider':
        return Icons.local_drink;
      case 'perry':
        return Icons.eco;
      case 'mead':
        return Icons.emoji_nature;
      case 'wine':
        return Icons.wine_bar;
      case 'low-no':
        return Icons.no_drinks;
      default:
        return Icons.local_drink;
    }
  }
}
