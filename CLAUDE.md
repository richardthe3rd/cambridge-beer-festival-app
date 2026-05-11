@AGENTS.md

# Claude AI Instructions

Instructions for Claude AI when working on the Cambridge Beer Festival app.

## Repository Overview

**Cambridge Beer Festival App** — A Flutter application for browsing drinks at the Cambridge Beer Festival.

### Key Information

- **Language**: Dart/Flutter
- **Flutter Version**: 3.38.3
- **Dart SDK**: >=3.2.0 <4.0.0
- **State Management**: Provider
- **Platforms**: Android, iOS, Web

## Directory Structure

```
lib/
├── main.dart          # Entry point, app setup, home navigation
├── router.dart        # GoRouter configuration
├── app_theme.dart     # Theme definitions
├── domain/            # Business logic (pure Dart, no Flutter deps)
│   ├── models/        # Domain models (DrinkSort, DrinkVisibilityFilter)
│   ├── repositories/  # Repository interfaces and implementations
│   └── services/      # DrinkFilterService, DrinkSortService
├── models/            # Data classes (Drink, Festival; Product/Producer in drink.dart)
├── providers/         # State management (BeerProvider)
├── screens/           # Full-page UI components
├── services/          # Infrastructure services (API calls, storage, analytics)
└── widgets/           # Reusable UI components

test/                  # Unit and widget tests
├── domain/            # Domain service tests
└── ...
web/                   # Web-specific assets
cloudflare-worker/     # API proxy worker
```

## Architecture

The app uses a **layered architecture**:

### Domain Layer (`lib/domain/`)

Pure business logic — no Flutter dependencies, fully unit-testable without mocks.

- **`DrinkFilterService`** — filtering (category, style, favourites, availability, search)
- **`DrinkSortService`** — sorting strategies (name, ABV, brewery, style)
- **`DrinkSort`** enum — defined in `lib/domain/models/drink_sort.dart`
- Repository interfaces — `DrinkRepository`, `FestivalRepository`

See [`docs/code/domain-architecture.md`](docs/code/domain-architecture.md).

### State Management Layer (`lib/providers/`)

**`BeerProvider`** orchestrates domain services and manages application state: loads data, delegates filtering/sorting, manages UI state, persists preferences, notifies listeners.

> Named `BeerProvider` for historical reasons but manages all drink types.

### Infrastructure Layer (`lib/services/`)

- **`BeerApiService`** — HTTP API calls
- **`FestivalService`** — Festival metadata API
- **`StorageService`** (`storage_service.dart`) — SharedPreferences; contains `FavoritesService`, `RatingsService`, `FestivalStorageService`
- **`TastingLogService`** — tasting log persistence
- **`EnvironmentService`** — environment/config detection
- **`AnalyticsService`** — Firebase Analytics/Crashlytics

### Data Layer (`lib/models/`)

- **`Drink`** — composite of Product + Producer
- **`Product`** — individual beverage (ABV, style, category, dispense)
- **`Producer`** — brewery/cidery
- **`Festival`** — festival metadata

## Code Style Checklist

When writing or modifying Dart code:

- [ ] Use single quotes: `'string'` not `"string"`
- [ ] Use `const` constructors where possible
- [ ] Use `final` for local variables
- [ ] Include `{super.key}` in widget constructors
- [ ] Sort `child`/`children` properties last in widgets
- [ ] Avoid `print()` — use `debugPrint()` if needed
- [ ] Add new files to barrel exports (e.g., `models.dart`)
- [ ] **Add `Semantics` widgets for interactive elements**
- [ ] **Provide meaningful labels for screen readers**
- [ ] **Test with large text settings** (ensure no overflow at 200% scale)

## Accessibility Requirements

**CRITICAL**: Accessibility is NOT optional.

> 📖 **Full implementation details: [`docs/code/accessibility.md`](docs/code/accessibility.md)**

### Standards

- **WCAG 2.1 Level AA**, **ADA**, **Section 508**

### Required Semantics for Interactive Elements

Every interactive element **must** have a `Semantics` widget with a `label`. `hint` and `value` as appropriate.

```dart
// ❌ BAD
IconButton(icon: Icon(Icons.favorite), onPressed: () => toggleFavorite())

// ✅ GOOD
Semantics(
  label: isFavourite ? 'Remove from favourites' : 'Add to favourites',
  button: true,
  hint: 'Double tap to toggle',
  child: IconButton(
    icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
    onPressed: () => toggleFavorite(),
  ),
)
```

### Common Patterns

```dart
// Filter chips
Semantics(
  label: 'Filter by $styleName',
  value: isSelected ? 'Selected' : 'Not selected',
  button: true,
  child: FilterChip(...),
)

// Drink cards
Semantics(
  label: '${drink.name}, ${drink.abv}% ABV, by ${drink.breweryName}',
  hint: 'Double tap for details',
  button: true,
  child: InkWell(onTap: () => navigateToDetail(drink), child: DrinkCard(drink: drink)),
)

// Star ratings
Semantics(
  label: 'Rate this drink',
  value: '$rating out of 5 stars',
  hint: 'Tap a star to rate from 1 to 5',
  child: Row(children: starWidgets),
)
```

### Files That Need Accessibility

**High Priority:**
- `lib/widgets/drink_card.dart` — drink cards, favourite buttons
- `lib/screens/drinks_screen.dart` — filter buttons, search, sort controls
- `lib/screens/festival_info_screen.dart` — map and website buttons
- `lib/main.dart` — bottom navigation bar
- `lib/widgets/star_rating.dart` — star rating widgets

### Automated Accessibility Testing

All new interactive elements must have semantic tests:

```dart
testWidgets('button has correct semantic label', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: MyButton())));
  final semantics = tester.widget<Semantics>(find.byType(Semantics).first);
  expect(semantics.properties.label, 'Add to favourites');
  expect(semantics.properties.button, isTrue);
});
```

## Working with Models

### JSON Parsing Pattern

API field types vary — always handle all variants:

```dart
// ABV can be String, int, or double
final abvValue = json['abv'];
double parsedAbv;
if (abvValue is num) {
  parsedAbv = abvValue.toDouble();
} else if (abvValue is String) {
  parsedAbv = double.tryParse(abvValue) ?? 0.0;
} else {
  parsedAbv = 0.0;
}
```

## Working with State (Provider)

```dart
// Reactive (triggers rebuild)
final provider = context.watch<BeerProvider>();

// One-time read
final provider = context.read<BeerProvider>();
provider.setCategory('beer');
```

### Key Provider Methods

- `initialize()` — load festivals and set up storage
- `loadDrinks()` — fetch drinks from current festival
- `setFestival(Festival)` — change active festival
- `setCategory(String?)` — filter by category
- `setSearchQuery(String)` — filter by search text
- `toggleFavorite(Drink)` — toggle favourite status
- `setRating(Drink, int)` — set drink rating

## Common Modifications

### Adding a Screen

1. Create `lib/screens/my_screen.dart`
2. Export from `lib/screens/screens.dart`
3. Add route in `lib/router.dart`

```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

### Adding Provider State

```dart
String? _myField;
String? get myField => _myField;

void setMyField(String? value) {
  _myField = value;
  notifyListeners();
}
```

### Adding a New Sort Option

1. Add enum value to `DrinkSort` in `lib/domain/models/drink_sort.dart`
2. Add case to `DrinkSortService` in `lib/domain/services/drink_sort_service.dart`
3. Add option to sort dropdown in `drinks_screen.dart`

## API Details

**Base URL**: `https://data.cambeerfestival.app`

**Endpoints**: `/{festivalId}/{category}.json`
- Categories: `beer`, `cider`, `perry`, `mead`, `wine`, `international-beer`, `low-no`

**Response Format**: Array of Producer objects, each containing products.

Full reference: [`docs/code/api/`](docs/code/api/)

## Release Process

CalVer (`YYYY.M.patch`). See [`docs/processes/release.md`](docs/processes/release.md).

```bash
# 1. Bump version in pubspec.yaml
#    version: 2026.5.2+20260509  (build number = YYYYMMDD)
git add pubspec.yaml && git commit -m "chore: bump version to 2026.5.2"
git push origin main

# 2. Tag to trigger deployment
git tag v2026.5.2 && git push origin v2026.5.2
```

## Do Not Change Without Request

- GitHub Actions workflows (`.github/workflows/`)
- Cloudflare Worker (`cloudflare-worker/`)
- Package versions in `pubspec.yaml`
- Analysis rules in `analysis_options.yaml`
