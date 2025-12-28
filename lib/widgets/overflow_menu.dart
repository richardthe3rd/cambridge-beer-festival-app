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
  return Semantics(
    label: 'Menu',
    hint: 'Double tap to open menu',
    button: true,
    child: PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Menu',
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'festivals',
          child: Row(
            children: [
              Icon(Icons.festival),
              SizedBox(width: 12),
              Text('Browse Festivals'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 12),
              Text('About'),
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
      context.go('/about');
  }
}
