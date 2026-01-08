/// Common widget builders for reducing duplication across screens.
///
/// This file contains reusable widget builders that are used across multiple
/// screens to maintain consistency and reduce code duplication.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'navigation_helpers.dart';

/// Builds a loading scaffold with standard appearance.
///
/// Used when data is being fetched to show a consistent loading state
/// across all screens.
///
/// Example:
/// ```dart
/// if (provider.isLoading) {
///   return buildLoadingScaffold();
/// }
/// ```
Widget buildLoadingScaffold() {
  return Scaffold(
    appBar: AppBar(title: const Text('Loading...')),
    body: const Center(child: CircularProgressIndicator()),
  );
}

/// Builds a home button for the AppBar leading position.
///
/// Shows a home button instead of the back button when navigation cannot pop.
/// This ensures users can always navigate back to the festival home.
///
/// The [festivalId] is used to navigate to the correct festival home page.
///
/// Example:
/// ```dart
/// AppBar(
///   leading: buildHomeLeadingButton(context, festivalId),
/// )
/// ```
Widget? buildHomeLeadingButton(BuildContext context, String festivalId) {
  if (canPopNavigation(context)) {
    return null; // Use default back button
  }

  return Semantics(
    label: 'Go to home screen',
    hint: 'Double tap to return to drinks list',
    button: true,
    child: IconButton(
      icon: const Icon(Icons.home),
      onPressed: () => context.go(buildFestivalHome(festivalId)),
      tooltip: 'Home',
    ),
  );
}

/// Builds a breadcrumb-style title for the AppBar.
///
/// Shows a primary title with the festival name as a subtitle for context.
/// This provides consistent navigation breadcrumbs across detail screens.
///
/// The [title] is the main heading (e.g., brewery name, style name, drink name).
/// The [festivalName] appears as a smaller subtitle below the title.
///
/// Example:
/// ```dart
/// AppBar(
///   title: buildBreadcrumbTitle(
///     context,
///     title: 'IPA',
///     festivalName: 'Cambridge Beer Festival 2025',
///   ),
/// )
/// ```
Widget buildBreadcrumbTitle(
  BuildContext context, {
  required String title,
  required String festivalName,
}) {
  final theme = Theme.of(context);

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: theme.textTheme.titleLarge,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        festivalName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}
