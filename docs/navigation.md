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
- `/cbf2025/style/IPA` - Style detail
- `/cbf2025/category/beer` - Category page

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
final styleUrl = buildStylePath('cbf2025', 'IPA');
```

### Parsing URLs

```dart
// Extract festival ID from path
final festivalId = extractFestivalId('/cbf2025/drinks'); // 'cbf2025'

// Check if path is festival-scoped
if (isFestivalPath(path)) {
  // Handle festival-scoped navigation
}
```

## Testing

All navigation helpers have 100% test coverage in `test/utils/navigation_helpers_test.dart`.
