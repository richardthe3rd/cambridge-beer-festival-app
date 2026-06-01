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
