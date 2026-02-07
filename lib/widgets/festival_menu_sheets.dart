import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// Shows the festival browser/selector as a modal bottom sheet
void showFestivalBrowser(BuildContext context) {
  final provider = context.read<BeerProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => FestivalSelectorSheet(provider: provider),
  );
}

/// Shows the settings modal with theme selector
void showSettingsSheet(BuildContext context) {
  final provider = context.read<BeerProvider>();
  showModalBottomSheet(
    context: context,
    builder: (context) => SettingsSheet(provider: provider),
  );
}

/// Festival selector sheet for browsing all festivals
class FestivalSelectorSheet extends StatelessWidget {
  final BeerProvider provider;

  const FestivalSelectorSheet({required this.provider, super.key});

  String _getStatusLabel(FestivalStatus status) {
    switch (status) {
      case FestivalStatus.live:
        return 'currently live';
      case FestivalStatus.upcoming:
        return 'coming soon';
      case FestivalStatus.mostRecent:
        return 'most recent';
      case FestivalStatus.past:
        return 'past event';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use dynamically loaded festivals (sorted)
    final festivals = provider.sortedFestivals;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.festival, size: 28),
              const SizedBox(width: 12),
              Text('Browse Festivals', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a festival to browse its drinks',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isFestivalsLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (provider.festivalsError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load festivals',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.festivalsError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              label: 'Retry loading festivals',
                              hint: 'Double tap to reload festival list',
                              button: true,
                              child: FilledButton.icon(
                                onPressed: () => provider.loadFestivals(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (festivals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.festival_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No festivals available',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              label: 'Refresh festivals',
                              hint: 'Double tap to reload festival list',
                              button: true,
                              child: FilledButton.icon(
                                onPressed: () => provider.loadFestivals(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...festivals.map((festival) {
                      final status = Festival.getStatusInContext(festival, festivals);
                      final statusLabel = _getStatusLabel(status);
                      final isSelected = festival.id == provider.currentFestival.id;
                      final festivalLabel = isSelected
                          ? '${festival.name}, currently selected, $statusLabel'
                          : '${festival.name}, $statusLabel';

                      return Semantics(
                        label: festivalLabel,
                        selected: isSelected,
                        button: true,
                        hint: 'Double tap to select this festival',
                        child: FestivalCard(
                          festival: festival,
                          sortedFestivals: festivals,
                          isSelected: isSelected,
                          onTap: () {
                            final router = GoRouter.maybeOf(context);
                            provider.setFestival(festival);
                            Navigator.pop(context);
                            router?.go('/${festival.id}');
                          },
                          onInfoTap: () {
                            Navigator.pop(context);
                            context.go(buildFestivalInfoPath(festival.id));
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Enhanced festival card with more information
class FestivalCard extends StatelessWidget {
  final Festival festival;
  final List<Festival> sortedFestivals;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const FestivalCard({
    required this.festival,
    required this.sortedFestivals,
    required this.isSelected,
    required this.onTap,
    required this.onInfoTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = Festival.getStatusInContext(festival, sortedFestivals);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusBadge(status),
                            Expanded(
                              child: Text(
                                festival.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (festival.formattedDates.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                festival.formattedDates,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (festival.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  festival.location!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (isSelected)
                        ExcludeSemantics(
                          child: Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        )
                      else
                        ExcludeSemantics(
                          child: Icon(
                            Icons.radio_button_unchecked,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Festival information',
                        hint: 'Double tap to view festival details',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: onInfoTap,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Festival info',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (festival.availableBeverageTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: festival.availableBeverageTypes
                      .take(5) // Show max 5 types
                      .map((type) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              BeverageTypeHelper.formatBeverageType(type),
                              style: theme.textTheme.labelSmall,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FestivalStatus status) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        Color backgroundColor;
        String label;

        switch (status) {
          case FestivalStatus.live:
            backgroundColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
            label = 'LIVE';
          case FestivalStatus.upcoming:
            backgroundColor = isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2);
            label = 'COMING SOON';
          case FestivalStatus.mostRecent:
            backgroundColor = isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00);
            label = 'MOST RECENT';
          case FestivalStatus.past:
            backgroundColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
            label = 'PAST';
        }

        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

/// Settings bottom sheet with theme selector
class SettingsSheet extends StatelessWidget {
  final BeerProvider provider;

  const SettingsSheet({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = provider.themeMode;

    String themeLabel;
    IconData themeIcon;

    switch (themeMode) {
      case ThemeMode.light:
        themeLabel = 'Light';
        themeIcon = Icons.light_mode;
      case ThemeMode.dark:
        themeLabel = 'Dark';
        themeIcon = Icons.dark_mode;
      case ThemeMode.system:
        themeLabel = 'System';
        themeIcon = Icons.brightness_auto;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Settings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Semantics(
            label: 'Change theme, currently $themeLabel mode',
            hint: 'Double tap to change theme',
            button: true,
            child: Card(
              child: ListTile(
                leading: Icon(themeIcon),
                title: const Text('Theme'),
                subtitle: Text('$themeLabel mode'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeSelector(context, provider);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ThemeSelectorSheet(provider: provider),
    );
  }
}

/// Theme selector bottom sheet
class ThemeSelectorSheet extends StatelessWidget {
  final BeerProvider provider;

  const ThemeSelectorSheet({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Theme', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          RadioGroup<ThemeMode>(
            groupValue: provider.themeMode,
            onChanged: (value) {
              if (value != null) {
                provider.setThemeMode(value);
                Navigator.pop(context);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.system),
                  title: const Text('System'),
                  subtitle: const Text('Follow device settings'),
                  trailing: const Icon(Icons.brightness_auto),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.system);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.light),
                  title: const Text('Light'),
                  subtitle: const Text('Always use light theme'),
                  trailing: const Icon(Icons.light_mode),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.light);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.dark),
                  title: const Text('Dark'),
                  subtitle: const Text('Always use dark theme'),
                  trailing: const Icon(Icons.dark_mode),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.dark);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
