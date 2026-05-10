import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'festival_menu_sheets.dart';

/// Shared overflow menu for Drinks and Favorites screens
///
/// Provides consistent menu access to:
/// - Festival browser
/// - Settings
/// - About page
Widget buildOverflowMenu(BuildContext context) {
  final theme = Theme.of(context);
  final menuContentColor = theme.colorScheme.onSurface;

  return Semantics(
    label: 'Menu',
    hint: 'Double tap to open menu',
    button: true,
    child: PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Menu',
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'festivals',
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.festival, color: menuContentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Browse Festivals',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: menuContentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.settings, color: menuContentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Settings',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: menuContentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.info_outline, color: menuContentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'About',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: menuContentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _handleMenuSelection(BuildContext context, String value) {
  switch (value) {
    case 'festivals':
      showFestivalBrowser(context);
    case 'settings':
      showSettingsSheet(context);
    case 'about':
      context.push('/about');
  }
}
