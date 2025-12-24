/// Navigation utilities for festival-scoped routing.
///
/// Provides helper functions to build festival-scoped URLs consistently
/// throughout the app. These will be used in Phase 1 when routes are updated.
library;

/// Builds a festival-scoped URL path.
///
/// Example:
/// ```dart
/// buildFestivalPath('cbf2025', '/drinks') // Returns: '/cbf2025/drinks'
/// buildFestivalPath('cbf2025', '/brewery/123') // Returns: '/cbf2025/brewery/123'
/// ```
String buildFestivalPath(String festivalId, String path) {
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
/// Example:
/// ```dart
/// buildDrinksPath('cbf2025') // Returns: '/cbf2025/drinks'
/// buildDrinksPath('cbf2025', category: 'beer') // Returns: '/cbf2025/drinks?category=beer'
/// ```
String buildDrinksPath(String festivalId, {String? category}) {
  final base = buildFestivalPath(festivalId, '/drinks');
  if (category != null) {
    return '$base?category=$category';
  }
  return base;
}

/// Builds a drink detail URL.
///
/// Example:
/// ```dart
/// buildDrinkDetailPath('cbf2025', 'drink-123') // Returns: '/cbf2025/drink/drink-123'
/// ```
String buildDrinkDetailPath(String festivalId, String drinkId) {
  return buildFestivalPath(festivalId, '/drink/$drinkId');
}

/// Builds a brewery detail URL.
///
/// Example:
/// ```dart
/// buildBreweryPath('cbf2025', 'brewery-123') // Returns: '/cbf2025/brewery/brewery-123'
/// ```
String buildBreweryPath(String festivalId, String breweryId) {
  return buildFestivalPath(festivalId, '/brewery/$breweryId');
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
/// Example:
/// ```dart
/// buildCategoryPath('cbf2025', 'beer') // Returns: '/cbf2025/category/beer'
/// ```
String buildCategoryPath(String festivalId, String category) {
  return buildFestivalPath(festivalId, '/category/$category');
}

/// Extracts festival ID from a festival-scoped path.
///
/// Example:
/// ```dart
/// extractFestivalId('/cbf2025/drinks') // Returns: 'cbf2025'
/// extractFestivalId('/invalid') // Returns: null
/// ```
String? extractFestivalId(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isNotEmpty ? segments.first : null;
}

/// Checks if a path is festival-scoped.
///
/// Example:
/// ```dart
/// isFestivalPath('/cbf2025/drinks') // Returns: true
/// isFestivalPath('/drinks') // Returns: false
/// ```
bool isFestivalPath(String path) {
  return extractFestivalId(path) != null;
}
