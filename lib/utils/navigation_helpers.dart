/// Navigation utilities for festival-scoped routing.
///
/// Provides helper functions to build festival-scoped URLs consistently
/// throughout the app. These will be used in Phase 1 when routes are updated.
///
/// All functions perform URL encoding where appropriate to handle special
/// characters safely.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds a festival-scoped URL path.
///
/// The [festivalId] and [path] must not be empty.
///
/// Example:
/// ```dart
/// buildFestivalPath('cbf2025', '/drinks') // Returns: '/cbf2025/drinks'
/// buildFestivalPath('cbf2025', '/brewery/123') // Returns: '/cbf2025/brewery/123'
/// ```
String buildFestivalPath(String festivalId, String path) {
  assert(festivalId.isNotEmpty, 'Festival ID cannot be empty');
  assert(path.isNotEmpty, 'Path cannot be empty');

  // Ensure path starts with /
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return '/$festivalId$cleanPath';
}

/// Builds a festival home URL.
///
/// Example:
/// ```dart
/// buildFestivalHome('cbf2025') // Returns: '/cbf2025'
/// ```
String buildFestivalHome(String festivalId) {
  assert(festivalId.isNotEmpty, 'Festival ID cannot be empty');
  return '/$festivalId';
}

/// Builds a drinks list URL for a festival.
///
/// The optional [category] parameter is URL-encoded to handle special characters.
///
/// Example:
/// ```dart
/// buildDrinksPath('cbf2025') // Returns: '/cbf2025/drinks'
/// buildDrinksPath('cbf2025', category: 'beer') // Returns: '/cbf2025/drinks?category=beer'
/// buildDrinksPath('cbf2025', category: 'cider & perry') // Returns: '/cbf2025/drinks?category=cider%20%26%20perry'
/// ```
String buildDrinksPath(String festivalId, {String? category}) {
  final base = buildFestivalPath(festivalId, '/drinks');
  if (category != null && category.isNotEmpty) {
    final encodedCategory = Uri.encodeQueryComponent(category);
    return '$base?category=$encodedCategory';
  }
  return base;
}

/// Builds a favorites URL for a festival.
///
/// Example:
/// ```dart
/// buildFavoritesPath('cbf2025') // Returns: '/cbf2025/favorites'
/// ```
String buildFavoritesPath(String festivalId) {
  return buildFestivalPath(festivalId, '/favorites');
}

/// Builds a festival info URL.
///
/// Example:
/// ```dart
/// buildFestivalInfoPath('cbf2025') // Returns: '/cbf2025/info'
/// ```
String buildFestivalInfoPath(String festivalId) {
  return buildFestivalPath(festivalId, '/info');
}

/// Builds a drink detail URL.
///
/// Both [category] and [drinkId] are URL-encoded to handle special characters
/// safely. Category is included in the path to aid SEO and App Links matching.
///
/// Example:
/// ```dart
/// buildDrinkDetailPath('cbf2025', 'beer', 'drink-123') // Returns: '/cbf2025/drink/beer/drink-123'
/// buildDrinkDetailPath('cbf2025', 'foreign beer', 'drink-456') // Returns: '/cbf2025/drink/foreign%20beer/drink-456'
/// ```
String buildDrinkDetailPath(
  String festivalId,
  String category,
  String drinkId,
) {
  assert(category.isNotEmpty, 'Category cannot be empty');
  assert(drinkId.isNotEmpty, 'Drink ID cannot be empty');
  final encodedCategory = Uri.encodeComponent(category);
  final encodedId = Uri.encodeComponent(drinkId);
  return buildFestivalPath(festivalId, '/drink/$encodedCategory/$encodedId');
}

/// Builds a brewery detail URL.
///
/// The [breweryId] is URL-encoded to handle special characters safely.
///
/// Example:
/// ```dart
/// buildBreweryPath('cbf2025', 'brewery-123') // Returns: '/cbf2025/brewery/brewery-123'
/// buildBreweryPath('cbf2025', 'oak & elm') // Returns: '/cbf2025/brewery/oak%20%26%20elm'
/// ```
String buildBreweryPath(String festivalId, String breweryId) {
  assert(breweryId.isNotEmpty, 'Brewery ID cannot be empty');
  final encodedId = Uri.encodeComponent(breweryId);
  return buildFestivalPath(festivalId, '/brewery/$encodedId');
}

/// Builds a style detail URL with lowercase canonical format.
///
/// The style name is converted to lowercase for canonical URLs.
/// This improves SEO and ensures consistent URL format.
///
/// Example:
/// ```dart
/// buildStylePath('cbf2025', 'IPA') // Returns: '/cbf2025/style/ipa'
/// buildStylePath('cbf2025', 'American IPA') // Returns: '/cbf2025/style/american%20ipa'
/// ```
String buildStylePath(String festivalId, String style) {
  assert(style.isNotEmpty, 'Style cannot be empty');
  // Convert to lowercase for canonical URLs
  final lowercaseStyle = style.toLowerCase();
  // URL-encode the style name to handle special characters
  final encodedStyle = Uri.encodeComponent(lowercaseStyle);
  return buildFestivalPath(festivalId, '/style/$encodedStyle');
}

/// Builds a category URL.
///
/// The [category] is URL-encoded to handle special characters safely.
///
/// Example:
/// ```dart
/// buildCategoryPath('cbf2025', 'beer') // Returns: '/cbf2025/category/beer'
/// buildCategoryPath('cbf2025', 'low/no alcohol') // Returns: '/cbf2025/category/low%2Fno%20alcohol'
/// ```
String buildCategoryPath(String festivalId, String category) {
  assert(category.isNotEmpty, 'Category cannot be empty');
  final encodedCategory = Uri.encodeComponent(category);
  return buildFestivalPath(festivalId, '/category/$encodedCategory');
}

/// Extracts festival ID from a festival-scoped path.
///
/// Returns the festival ID if the path follows the pattern `/{festivalId}/...`
/// with at least one path segment after the festival ID. Returns `null` for
/// non-festival-scoped paths.
///
/// A valid festival-scoped path must have at least 2 segments:
/// - First segment: festival ID
/// - Second+ segments: the actual route path
///
/// Example:
/// ```dart
/// extractFestivalId('/cbf2025/drinks') // Returns: 'cbf2025'
/// extractFestivalId('/cbf2025/brewery/123') // Returns: 'cbf2025'
/// extractFestivalId('/cbf2025') // Returns: 'cbf2025' (festival home is valid)
/// extractFestivalId('/drinks') // Returns: null (not festival-scoped)
/// extractFestivalId('/') // Returns: null
/// extractFestivalId('') // Returns: null
/// ```
String? extractFestivalId(String path) {
  if (path.isEmpty) return null;

  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  // Need at least 1 segment for festival ID
  // Single segment like '/cbf2025' is valid (festival home)
  // Multiple segments like '/cbf2025/drinks' is valid
  if (segments.isEmpty) return null;

  return segments.first;
}

/// Checks if a path is festival-scoped.
///
/// A path is considered festival-scoped if it has at least one segment
/// (the festival ID). This includes both festival home pages (`/cbf2025`)
/// and nested routes (`/cbf2025/drinks`).
///
/// Example:
/// ```dart
/// isFestivalPath('/cbf2025/drinks') // Returns: true
/// isFestivalPath('/cbf2025') // Returns: true
/// isFestivalPath('/drinks') // Returns: true (single segment treated as potential festival ID)
/// isFestivalPath('/') // Returns: false
/// isFestivalPath('') // Returns: false
/// ```
///
/// Note: This function cannot distinguish between a festival ID and a regular
/// route without additional context. Use with caution for validation.
bool isFestivalPath(String path) {
  return extractFestivalId(path) != null;
}

/// Checks if navigation can pop in the current context.
///
/// Safely handles contexts where GoRouter may not be available (e.g., in tests).
/// Returns `true` if the router can navigate back, `false` otherwise.
///
/// This is useful for determining whether to show a back button or a home button
/// in the app bar.
///
/// Example:
/// ```dart
/// final canPop = canPopNavigation(context);
/// leading: canPop ? null : IconButton(icon: Icon(Icons.home), ...)
/// ```
bool canPopNavigation(BuildContext context) {
  try {
    return GoRouter.of(context).canPop();
  } catch (e) {
    // GoRouter not available (e.g., in tests)
    return false;
  }
}

/// Navigates to a detail route by pushing it onto the current Navigator.
///
/// `push` nests the new route on top of the current Navigator on both
/// platforms, so the calling screen (and its state — e.g. scroll position)
/// is never disposed, just covered. On web this also produces a correct
/// browser URL because `GoRouter.optionURLReflectsImperativeAPIs` is enabled
/// in `router.dart` — without that flag, `push`ing a route that isn't nested
/// inside the enclosing `ShellRoute` used to leave the URL bar stuck at the
/// shell's route, which is why this used to fall back to `go` (and dispose
/// the calling screen) on web.
void navigateToRoute(BuildContext context, String path) {
  context.push(path);
}

/// Returns to the drinks list from any depth of detail navigation in a single
/// action.
///
/// Since #470 every drill-down (drink → style → brewery → similar drink → …)
/// pushes a new route, so the back button only steps one level at a time. This
/// collapses the whole detail stack at once:
///
/// It first pops the whole stack down to the base route. Popping never disposes
/// the base, so when the user drilled in from a list, that list underneath keeps
/// its scroll position (the reason [navigateToRoute] uses `push` — see #470). In
/// the common case the base is the drinks list (`/:festivalId`); if the user was
/// browsing My Festival (`/:festivalId/favorites`) the base is that list, and
/// returning there is acceptable — it's the list they were browsing.
///
/// If the base is *not* a list route — the detail screen was itself the stack
/// base because it was reached via a deep link, so there is no list underneath
/// even after popping — it navigates to the festival home ([buildFestivalHome]).
/// This is done via `router.go` rather than `context`, whose element may have
/// been unmounted by the pops above.
void returnToDrinksList(BuildContext context, String festivalId) {
  final router = GoRouter.of(context);
  while (router.canPop()) {
    router.pop();
  }
  if (!_isFestivalListLocation(router, festivalId)) {
    router.go(buildFestivalHome(festivalId));
  }
}

/// Whether the router's current location is one of the festival list routes
/// (the drinks list or My Festival), i.e. a valid place to stop collapsing the
/// stack. Query strings are ignored, so a filtered list (`/:id?category=beer`)
/// still counts.
bool _isFestivalListLocation(GoRouter router, String festivalId) {
  final path = router.routerDelegate.currentConfiguration.uri.path;
  return path == buildFestivalHome(festivalId) ||
      path == buildFavoritesPath(festivalId);
}

/// Decodes a percent-encoded URI component, returning the raw value if it
/// contains an illegal percent-encoding sequence.
///
/// [Uri.decodeComponent] throws an [ArgumentError] when a `%` is not followed
/// by two hex digits (e.g. a stray `%` in an old bookmark or shared link).
/// This wrapper catches that case so callers get a usable string instead of a
/// crash.
///
/// Example:
/// ```dart
/// safeDecodeComponent('IPA%20American')  // Returns: 'IPA American'
/// safeDecodeComponent('50%')             // Returns: '50%' (malformed — fallback)
/// safeDecodeComponent('normal')          // Returns: 'normal'
/// ```
String safeDecodeComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}
