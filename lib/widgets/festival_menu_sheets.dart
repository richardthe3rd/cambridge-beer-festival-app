import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'festival_header.dart';
import 'sheet_handle.dart';

/// Shows the festival browser/selector as a modal bottom sheet
void showFestivalBrowser(BuildContext context) {
  // Capture current route before opening modal — GoRouterState must not be
  // accessed inside an onTap handler (gesture callbacks are not build phase).
  String? currentPath;
  try {
    currentPath = GoRouterState.of(context).uri.path;
  } catch (_) {
    // GoRouterState unavailable (e.g., in tests)
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => FestivalSelectorSheet(currentPath: currentPath),
  );
}

/// Shows the settings modal with theme selector
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => const SettingsSheet(),
  );
}

/// Festival selector sheet for browsing all festivals
class FestivalSelectorSheet extends StatelessWidget {
  final String? currentPath;

  const FestivalSelectorSheet({this.currentPath, super.key});

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
    // Unlike every other sheet in this file, two of this one's controls —
    // Retry and Refresh — deliberately do NOT pop the sheet, so their result
    // has to land while it is still open. A modal route is not rebuilt by its
    // opener, so this sheet must hold its own subscription for those buttons
    // to have any visible effect: without one, loadFestivals() would run and
    // nothing on screen would change.
    //
    // context.watch, not context.select: sortedFestivals
    // (Festival.sortByDate(_festivals), festival_controller.dart:55) builds a
    // fresh list on every call, so selecting on it would re-run this build on
    // every provider notification anyway — a selector would buy nothing. This
    // sheet's entire body is provider-derived (loading/error/empty states,
    // the festival list, which one is selected), so a whole-provider watch
    // costs the same as a selector here while being simpler to read.
    final provider = context.watch<BeerProvider>();
    final theme = Theme.of(context);
    // Use dynamically loaded festivals (sorted)
    final festivals = provider.sortedFestivals;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(handleKey: Key('festival_selector_drag_handle')),
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
                                onPressed: provider.loadFestivals,
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
                                onPressed: provider.loadFestivals,
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
                      final status = Festival.getStatusInContext(
                        festival,
                        festivals,
                      );
                      final statusLabel = _getStatusLabel(status);
                      final isSelected =
                          festival.id == provider.currentFestival.id;
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
                            // Preserve user's tab: if on favorites, stay on favorites.
                            // currentPath was captured before the modal opened to avoid
                            // calling GoRouterState.of() inside a gesture callback,
                            // which can cause a freeze during active widget rebuilds.
                            String targetPath = buildFestivalHome(festival.id);
                            if (currentPath?.endsWith('/favorites') == true) {
                              targetPath = buildFavoritesPath(festival.id);
                            }
                            final router = GoRouter.maybeOf(context);
                            provider.setFestival(festival);
                            Navigator.pop(context);
                            router?.go(targetPath);
                          },
                          onInfoTap: () {
                            final router = GoRouter.maybeOf(context);
                            Navigator.pop(context);
                            router?.push(buildFestivalInfoPath(festival.id));
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
                            FestivalStatusBadge(status: status),
                            const SizedBox(width: 8),
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
                  key: const Key('beverage_chips_wrap'),
                  spacing: 6,
                  runSpacing: 4,
                  children: festival.availableBeverageTypes
                      .take(5) // Show max 5 types
                      .map(
                        (type) => Container(
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
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings bottom sheet with theme selector
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = context.select<BeerProvider, ThemeMode>(
      (p) => p.themeMode,
    );

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
          const SheetHandle(handleKey: Key('settings_sheet_drag_handle')),
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
                  _showThemeSelector(context);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const ThemeSelectorSheet(),
    );
  }
}

/// Theme selector bottom sheet
class ThemeSelectorSheet extends StatelessWidget {
  const ThemeSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = context.select<BeerProvider, ThemeMode>(
      (p) => p.themeMode,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(handleKey: Key('theme_selector_sheet_drag_handle')),
          const SizedBox(height: 16),
          Text('Theme', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) {
                context.read<BeerProvider>().setThemeMode(value);
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
                    context.read<BeerProvider>().setThemeMode(ThemeMode.system);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.light),
                  title: const Text('Light'),
                  subtitle: const Text('Always use light theme'),
                  trailing: const Icon(Icons.light_mode),
                  onTap: () {
                    context.read<BeerProvider>().setThemeMode(ThemeMode.light);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.dark),
                  title: const Text('Dark'),
                  subtitle: const Text('Always use dark theme'),
                  trailing: const Icon(Icons.dark_mode),
                  onTap: () {
                    context.read<BeerProvider>().setThemeMode(ThemeMode.dark);
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
