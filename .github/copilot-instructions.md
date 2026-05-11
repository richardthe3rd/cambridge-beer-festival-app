# GitHub Copilot Instructions

Context and guidelines for GitHub Copilot working on the Cambridge Beer Festival app.

**For task execution, commands, and workflows: see [AGENTS.md](../AGENTS.md).**

## Project Overview

A **Flutter** app for browsing drinks (beers, ciders, meads, wines, etc.) at the Cambridge Beer Festival. Supports Android, iOS, and Web.

### Tech Stack

- **Framework**: Flutter (Dart SDK >=3.2.0 <4.0.0)
- **State Management**: Provider (`ChangeNotifier`)
- **Storage**: SharedPreferences for favorites, ratings, and tasting log
- **HTTP Client**: `http` package
- **UI**: Material Design 3, light/dark theme, seed color `0xFFD97706`

## Project Structure

```
lib/
├── main.dart              # App entry point and navigation
├── router.dart            # GoRouter configuration
├── app_theme.dart         # Theme definitions
├── domain/                # Business logic (pure Dart, no Flutter deps)
│   ├── models/            # DrinkSort, DrinkVisibilityFilter
│   ├── repositories/      # Repository interfaces + API implementations
│   └── services/          # DrinkFilterService, DrinkSortService
├── models/                # Data classes: Drink, Festival (Product/Producer defined in drink.dart)
├── providers/             # BeerProvider — orchestrates domain + manages UI state
├── screens/               # Full-page UI screens
├── services/              # Infrastructure: BeerApiService, StorageService, AnalyticsService, etc.
├── utils/                 # Helper classes (see below)
└── widgets/               # Reusable UI components (see below)
```

## Coding Conventions

### Dart Style

- **Single quotes** for strings (`'text'` not `"text"`)
- **`const` constructors** wherever possible
- **`final`** for local variables and fields
- **`camelCase`** for variables/functions, **`PascalCase`** for classes
- Widget constructors always include `{super.key}`
- Sort `child`/`children` properties last in widget trees
- No `print()` — use `debugPrint()`

### Flutter Patterns

- `context.read<T>()` for one-time reads, `context.watch<T>()` for reactive rebuilds
- Always `dispose()` controllers and resources
- Prefer `const` widgets for performance

### Naming Conventions

- Screens: `*_screen.dart` / `*Screen`
- Widgets: `*_card.dart`, `*_chip.dart`, etc.
- Services: `*_service.dart` / `*Service`
- Providers: `*_provider.dart` / `*Provider`
- Domain models: named after the concept (`drink_sort.dart`)

### Barrel Files

Each directory exports via a barrel file (`models.dart`, `services.dart`, `utils.dart`, etc.). Always update the barrel when adding a new file.

## Reusable Utilities (`lib/utils/`)

### Display & Formatting

- **`BeverageTypeHelper`** — format type names and get icons
  - `formatBeverageType('international-beer')` → `'International Beer'`
  - `getBeverageIcon('cider')` → `Icons.local_drink`

- **`CategoryColorHelper`** — theme-aware colors per beverage category
  - `getCategoryColor(context, drink.category)`

- **`ABVStrengthHelper`** — ABV strength labels and colors
  - `getABVColor(context, abv)` — Low <4%, Medium 4–7%, High ≥7%
  - `getABVStrengthLabel(abv)` → `'(Medium)'`

- **`StringFormattingHelper`**
  - `capitalizeFirst('cask')` → `'Cask'`

- **`StringComparisonHelper`** — normalised string matching for search

- **`StyleDescriptionHelper`** — human-readable style descriptions

### User Interaction

- **`UrlLauncherHelper`** — open URLs with SnackBar on error
  - `launchURL(context, url, errorMessage: '...')`

### UI

- **`NavigationHelpers`** — shared navigation utilities
- **`widget_builders.dart`** — common widget construction helpers

## Data Models (`lib/models/`)

- **`Festival`** — festival id, name, data URL
- **`Producer`** — brewery/cidery with location; defined in `drink.dart`
- **`Product`** — beverage (ABV, style, category, dispense); defined in `drink.dart`
- **`Drink`** — combines Product + Producer for display; includes favorites/ratings state

### JSON Parsing

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

Other fields with type variance: allergens (`int`/`bool`/`num`), year founded (`int`/`String`).

## Reusable Widgets (`lib/widgets/`)

- **`DrinkCard`** — list item for a drink (name, brewery, ABV, style, category, rating, favourite toggle)
- **`InfoChip`** — icon + label chip; `onTap` makes it interactive
  - `InfoChip(label: 'Cask', icon: Icons.liquor, onTap: ...)`
- **`StarRating`** — display or edit star rating
  - `StarRating(rating: drink.rating, isEditable: true, onRatingChanged: ...)`
- **`EntityDetailScreen`** — generic filtered-drink-list screen (used by BreweryScreen, StyleScreen)

## API

- **Base URL**: `https://data.cambeerfestival.app`
- **Pattern**: `/{festivalId}/{category}.json`
- **Categories**: `beer`, `cider`, `perry`, `mead`, `wine`, `international-beer`, `low-no`

Full reference: [`docs/code/api/`](../docs/code/api/)

## Important Patterns

### Accessibility

Every interactive element needs a `Semantics` wrapper with a `label`. See [`docs/code/accessibility.md`](../docs/code/accessibility.md) and [`AGENTS.md`](../AGENTS.md) for full requirements and examples.

### Error Handling

- Wrap API calls in try-catch; store error state in provider; show user-friendly messages with retry
- Guard navigation with provider initialisation checks

### Category Filtering

Categories are dynamic from API data — no hardcoded list needed; the UI renders whatever the API returns.

## Playwright / Flutter Web Testing

Flutter web apps don't use standard DOM elements:

- Can't use CSS selectors or standard locators for Flutter widgets
- Can test: page load, Flutter canvas render, network requests, console errors, screenshots
- For button/form interaction: use Flutter's `integration_test` package instead

Mise tasks for E2E: `MISE_ENV=dev ./bin/mise run test:e2e` (see AGENTS.md).

## Deployment

| Environment | URL | Trigger |
|---|---|---|
| Production | `cambeerfestival.app` | Version tag (e.g. `v2026.5.4`) |
| Staging | `staging.cambeerfestival.app` | Push to `main` |
| PR Preview | Unique URL per PR | PR open/update |

## Security

- HTTPS only for API endpoints
- No sensitive data in SharedPreferences (only favourites, ratings, tasting notes)
- Never commit API keys or secrets
- Use `url_launcher` for all external links
