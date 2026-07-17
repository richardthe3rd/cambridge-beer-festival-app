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

/// Builds a persistent AppBar action that returns to the drinks list from any
/// depth of detail navigation in a single tap.
///
/// Unlike the leading back button (one step) or [buildHomeLeadingButton] (only
/// shown when the stack can't pop), this is always present on detail screens.
/// It uses the app icon — the festival's identity mark, echoing the drinks
/// screen's header — so tapping it to return "home" reads as a deliberate
/// affordance rather than an arbitrary glyph. Delegates to [returnToDrinksList].
///
/// Example:
/// ```dart
/// AppBar(
///   actions: [buildDrinksListAction(context, festivalId)],
/// )
/// ```
Widget buildDrinksListAction(BuildContext context, String festivalId) {
  return Semantics(
    label: 'Back to drinks list',
    hint: 'Double tap to return to the drinks list',
    button: true,
    child: IconButton(
      icon: Image.asset(
        'assets/app_icon.png',
        width: 24,
        height: 24,
        excludeFromSemantics: true,
      ),
      onPressed: () => returnToDrinksList(context, festivalId),
      tooltip: 'Drinks list',
    ),
  );
}
