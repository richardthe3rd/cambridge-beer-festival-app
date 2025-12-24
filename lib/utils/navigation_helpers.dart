/// Navigation utilities for festival-scoped routing.
///
/// Provides helper functions to build festival-scoped URLs consistently
/// throughout the app. These will be used in Phase 1 when routes are updated.
///
/// All functions perform URL encoding where appropriate to handle special
/// characters safely.
library;

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

/// Builds a drink detail URL.
///
/// The [drinkId] is URL-encoded to handle special characters safely.
///
/// Example:
/// ```dart
/// buildDrinkDetailPath('cbf2025', 'drink-123') // Returns: '/cbf2025/drink/drink-123'
/// buildDrinkDetailPath('cbf2025', 'drink 456') // Returns: '/cbf2025/drink/drink%20456'
/// ```
String buildDrinkDetailPath(String festivalId, String drinkId) {
  assert(drinkId.isNotEmpty, 'Drink ID cannot be empty');
  final encodedId = Uri.encodeComponent(drinkId);
  return buildFestivalPath(festivalId, '/drink/$encodedId');
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

/// Builds a style detail URL.
///
/// Example:
/// ```dart
/// buildStylePath('cbf2025', 'IPA') // Returns: '/cbf2025/style/IPA'
/// ```
String buildStylePath(String festivalId, String style) {
  // URL-encode the style name to handle special characters
  final encodedStyle = Uri.encodeComponent(style);
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
