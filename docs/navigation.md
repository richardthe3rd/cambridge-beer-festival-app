# Navigation Utilities

This document describes the navigation helper utilities used throughout the app.

## Festival-Scoped URLs

All app URLs are scoped to a specific festival. This allows:
- Deep linking to specific festivals
- Viewing historical festival data
- Switching between multiple festivals

## URL Structure

```
/{festivalId}/{path}
```

Examples:
- `/cbf2025` - Festival home
- `/cbf2025/drinks` - Drinks list
- `/cbf2025/drink/123` - Drink detail
- `/cbf2025/brewery/456` - Brewery detail
- `/cbf2025/style/ipa` - Style detail (lowercase canonical)
- `/cbf2025/category/beer` - Category page

## URL Encoding

**All IDs and user-provided values are automatically URL-encoded** to handle special characters safely:

- Drink IDs, brewery IDs, category names: `Uri.encodeComponent()`
- Query parameters: `Uri.encodeQueryComponent()`
- This ensures URLs like `/cbf2025/brewery/Oak & Elm` become `/cbf2025/brewery/Oak%20%26%20Elm`

## Helper Functions

See `lib/utils/navigation_helpers.dart` for all helper functions.

### Building URLs

```dart
import 'package:cambridge_beer_festival/utils/utils.dart';

// Build festival home URL
final homeUrl = buildFestivalHome('cbf2025'); // '/cbf2025'

// Build drinks URL
final drinksUrl = buildDrinksPath('cbf2025'); // '/cbf2025/drinks'
final beerUrl = buildDrinksPath('cbf2025', category: 'beer'); // '/cbf2025/drinks?category=beer'

// Build detail URLs
final drinkUrl = buildDrinkDetailPath('cbf2025', drink.id);
final breweryUrl = buildBreweryPath('cbf2025', brewery.id);
final styleUrl = buildStylePath('cbf2025', 'IPA'); // Returns: '/cbf2025/style/ipa' (lowercase)
```

### Parsing URLs

```dart
// Extract festival ID from path
final festivalId = extractFestivalId('/cbf2025/drinks'); // 'cbf2025'
final festivalId2 = extractFestivalId('/cbf2025'); // 'cbf2025' (festival home)
final festivalId3 = extractFestivalId('/'); // null
final festivalId4 = extractFestivalId(''); // null

// Check if path is festival-scoped
if (isFestivalPath(path)) {
  // Handle festival-scoped navigation
}
```

**Important Notes:**

- `extractFestivalId()` returns the first path segment, but **cannot validate** if it's a real festival ID
- Single-segment paths like `/drinks` return `'drinks'` as the potential festival ID
- Actual validation against the festival registry happens in Phase 1 routing logic
- Empty paths and root path `/` return `null`

## Input Validation

All builder functions include assertions to prevent common errors:

```dart
// ❌ These will throw AssertionError in debug mode:
buildFestivalPath('', '/drinks');      // Empty festival ID
buildDrinkDetailPath('cbf2025', '');   // Empty drink ID
buildCategoryPath('cbf2025', '');      // Empty category

// ✅ These are handled gracefully:
buildDrinksPath('cbf2025', category: '');  // Returns '/cbf2025/drinks' (no query param)
```

## Testing

All navigation helpers have comprehensive test coverage in `test/utils/navigation_helpers_test.dart`:
- URL encoding edge cases (special characters, Unicode, etc.)
- Input validation (assertions)
- Edge cases (long strings, multiple slashes, etc.)
- All builder functions
- Path parsing and validation
