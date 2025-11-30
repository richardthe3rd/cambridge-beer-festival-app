import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

/// Screen showing detailed festival information
class FestivalInfoScreen extends StatelessWidget {
  final Festival festival;

  const FestivalInfoScreen({super.key, required this.festival});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Festival Info'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildOverview(context),
            if (festival.location != null || festival.address != null)
              _buildLocation(context),
            if (festival.hours != null && festival.hours!.isNotEmpty)
              _buildHours(context),
            if (festival.description != null) _buildDescription(context),
            _buildActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                Text(
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
            Text(
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

  Widget _buildOverview(BuildContext context) {
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

  Widget _buildLocation(BuildContext context) {
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
                        onPressed: () => _openMaps(context),
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

  Widget _buildHours(BuildContext context) {
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

  Widget _buildDescription(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            festival.description!,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
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
                onPressed: () => _openWebsite(context),
                icon: const Icon(Icons.language),
                label: const Text('Visit Festival Website'),
              ),
            ),
        ],
      ),
    );
  }

  void _openMaps(BuildContext context) async {
    if (festival.latitude == null || festival.longitude == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${festival.latitude},${festival.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening maps')),
        );
      }
    }
  }

  void _openWebsite(BuildContext context) async {
    if (festival.websiteUrl == null) return;

    final url = Uri.parse(festival.websiteUrl!);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open website')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening website')),
        );
      }
    }
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
