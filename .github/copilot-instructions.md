# GitHub Copilot Instructions

This file provides context and guidelines for GitHub Copilot to generate better code suggestions for the Cambridge Beer Festival app.

## 🚀 Quick Start

**FIRST: See [../AGENTS.md](../AGENTS.md)** for complete mise task reference, command discovery, and CI/CD mappings.

## Project Overview

This is a **Flutter** application for browsing drinks (beers, ciders, meads, wines, etc.) at the Cambridge Beer Festival. The app supports Android, iOS, and Web platforms.

### Tech Stack

- **Framework**: Flutter (requires Dart SDK >=3.2.0 <4.0.0)
- **Language**: Dart (SDK >=3.2.0 <4.0.0)
- **State Management**: Provider (`provider` package)
- **Storage**: SharedPreferences for local favorites and ratings
- **HTTP Client**: `http` package for API calls
- **UI**: Material Design 3 with system theme support

## Project Structure

```
lib/
├── main.dart              # App entry point and navigation
├── models/                # Data models (Drink, Product, Producer, Festival)
├── providers/             # State management (BeerProvider)
├── screens/               # UI screens (DrinksScreen, DrinkDetailScreen, etc.)
├── services/              # API and storage services
├── utils/                 # Utility helpers (colors, formatting, URL launching)
└── widgets/               # Reusable UI components (DrinkCard, InfoChip, etc.)
```

## Coding Conventions

### Dart Style

- Use **single quotes** for strings (`'text'` not `"text"`)
- Prefer **const constructors** wherever possible
- Prefer **final** for local variables and fields
- Use **camelCase** for variable and function names
- Use **PascalCase** for class names
- Always use widget keys in constructors (`{super.key}`)
- Sort child properties last in widget trees

### Flutter Patterns

- Use `ChangeNotifier` with `Provider` for state management
- Prefer `const` widgets to improve performance
- Use `context.read<T>()` for one-time reads
- Use `context.watch<T>()` for reactive rebuilds
- Always dispose of resources (HTTP clients, controllers) in `dispose()`

### Naming Conventions

- **Screens**: `*_screen.dart` with `*Screen` class names
- **Widgets**: Descriptive names like `drink_card.dart`
- **Services**: `*_service.dart` with `*Service` class names
- **Providers**: `*_provider.dart` with `*Provider` class names
- **Models**: Named after the entity they represent
- **Utilities**: `*_helper.dart` with `*Helper` class names (static methods only)

### Barrel Files

Each directory contains a barrel file (e.g., `models.dart`, `services.dart`, `utils.dart`) that exports all files in that directory. When adding new files, update the corresponding barrel file.

## Reusable Utilities

The `lib/utils/` directory contains helper classes for common functionality:

### Display & Formatting

- **`BeverageTypeHelper`**: Format beverage type names and get icons
  - `formatBeverageType(String)` - Convert 'international-beer' to 'International Beer'
  - `getBeverageIcon(String)` - Get Material icon for beverage type

- **`CategoryColorHelper`**: Get theme-aware colors for beverage categories
  - `getCategoryColor(BuildContext, String)` - Returns color for beer, cider, perry, mead, wine, low-no

- **`ABVStrengthHelper`**: ABV strength classification and colors
  - `getABVColor(BuildContext, double)` - Color based on ABV (Low <4%, Medium 4-7%, High ≥7%)
  - `getABVStrengthLabel(double)` - Returns '(Low)', '(Medium)', or '(High)'

- **`StringFormattingHelper`**: String formatting utilities
  - `capitalizeFirst(String)` - Capitalize first letter ('cask' → 'Cask')

### User Interaction

- **`UrlLauncherHelper`**: Launch external URLs with error handling
  - `launchURL(BuildContext, String, {String errorMessage})` - Opens URL with SnackBar on error

### Usage Example

```dart
import '../utils/utils.dart';

// Format beverage types
final displayName = BeverageTypeHelper.formatBeverageType('international-beer'); // 'International Beer'
final icon = BeverageTypeHelper.getBeverageIcon('cider'); // Icons.local_drink

// Get category colors
final color = CategoryColorHelper.getCategoryColor(context, drink.category);

// ABV strength
final abvColor = ABVStrengthHelper.getABVColor(context, drink.abv);
final label = ABVStrengthHelper.getABVStrengthLabel(drink.abv); // '(Medium)'

// Launch URLs
await UrlLauncherHelper.launchURL(context, 'https://example.com', errorMessage: 'Could not open link');
```

## Data Models

- **Festival**: Represents a beer festival with id, name, and data URL
- **Producer**: Represents a brewery/cidery with location and products
- **Product**: Represents a beverage with ABV, style, category, dispense method, etc.
- **Drink**: Combines Product with Producer for display, includes favorites/ratings

### JSON Parsing

Be robust when parsing JSON from the API:
- ABV can be `String`, `int`, or `double`
- Allergens can be `int`, `bool`, or `num`
- Year founded can be `int` or `String`
- Handle null values gracefully with `?.` and `??`

## Reusable Widgets

The `lib/widgets/` directory contains reusable UI components:

### Core Widgets

- **`DrinkCard`**: Card displaying a drink in a list (name, brewery, ABV, style, category, rating)
  - Used in DrinksScreen, FavoritesScreen, and entity detail screens
  - Includes favorite toggle and tap navigation

- **`InfoChip`**: Small chip with icon and label for displaying metadata
  - Optional `onTap` callback for interactive chips
  - Used for styles, dispense methods, bars, etc.
  - Example: `InfoChip(label: 'Cask', icon: Icons.liquor)`

- **`StarRating`**: Star rating display and editor
  - `isEditable: true` for interactive rating
  - `onRatingChanged` callback for updates

- **`EntityDetailScreen`**: Generic detail screen pattern for filtered drink lists
  - Used by BreweryScreen and StyleScreen
  - Provides SliverAppBar with custom header and filtered drinks list
  - Handles loading, empty states, and analytics

### Usage Example

```dart
import '../widgets/widgets.dart';

// Display a drink card
DrinkCard(
  key: ValueKey(drink.id),
  drink: drink,
  onTap: () => context.go('/drink/${drink.id}'),
  onFavoriteTap: () => provider.toggleFavorite(drink),
)

// Display info chips
InfoChip(
  label: 'IPA',
  icon: Icons.local_drink,
  onTap: () => navigateToStyle('IPA'),
)

// Editable star rating
StarRating(
  rating: drink.rating,
  isEditable: true,
  starSize: 32,
  onRatingChanged: (rating) => provider.setRating(drink, rating),
)
```

## Testing

- Tests are in the `test/` directory
- Use `flutter_test` for widget and unit tests
- Use `mockito` for mocking services in tests
- Run tests with: `flutter test`

### Test Naming

- Test files: `*_test.dart`
- Test groups: Describe the class/feature being tested
- Individual tests: Describe the expected behavior

## Build Commands

**IMPORTANT**: Always use `./bin/mise` commands (not raw `flutter` commands) to ensure correct tool versions.

### Discover Available Tasks First

```bash
# List all available tasks
./bin/mise tasks ls

# List developer tasks (build, serve, etc.)
MISE_ENV=dev ./bin/mise tasks ls
```

### Common Commands

```bash
# Get dependencies
./bin/mise run install

# Generate code (mocks, build_runner)
./bin/mise run generate

# Analyze code
./bin/mise run analyze

# Run tests
./bin/mise run test

# Run tests with coverage
./bin/mise run coverage

# Run app (development) - requires dev environment
MISE_ENV=dev ./bin/mise run dev

# Build for web (local testing)
MISE_ENV=dev ./bin/mise run build:web

# Build for web (production deployment)
MISE_ENV=dev ./bin/mise run build:web:prod

# Serve release build locally
MISE_ENV=dev ./bin/mise run serve:release
```

### Why Use Mise?

- Ensures Flutter 3.38.3 (exact version used in CI)
- Prevents version conflicts
- Consistent with CI/CD pipeline
- Bundles required tools (Flutter, Node.js, etc.)

### Two Mise Environments

1. **Base (`mise.toml`)**: Use `./bin/mise` for core tasks (install, test, analyze)
2. **Developer (`mise.dev.toml`)**: Use `MISE_ENV=dev ./bin/mise` for dev tasks (dev, build, serve)

**Rule**: If building or running the app → use `MISE_ENV=dev`

### Raw Flutter Commands (Avoid These)

If you must use raw Flutter commands (not recommended):

```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Run app (development)
flutter run

# Build for web (GitHub Pages deployment)
flutter build web --release --base-href "/cambridge-beer-festival-app/"

# Build for web (local testing or root-path deployment)
flutter build web --release --base-href "/"

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

**Always prefer mise commands** - see AGENTS.md for complete guide.

## API

The app uses a Cloudflare Worker proxy to access Cambridge Beer Festival data:

- Base URL: `https://data.cambeerfestival.app`
- Endpoints: `/{festivalId}/{category}.json` (e.g., `/cbf2025/beer.json`)
- Categories: `beer`, `cider`, `perry`, `mead`, `wine`, `international-beer`, `low-no`

### API Documentation

Full API documentation is available in the `docs/api/` directory:

- **[docs/api/README.md](../docs/api/README.md)** - Overview and quick reference
- **[docs/api/data-api-reference.md](../docs/api/data-api-reference.md)** - Complete API reference
- **[docs/api/beer-list-schema.json](../docs/api/beer-list-schema.json)** - JSON Schema for beverage data
- **[docs/api/festival-registry-schema.json](../docs/api/festival-registry-schema.json)** - JSON Schema for festival configuration

### JSON Schemas

The repository includes JSON schemas that define the expected structure of API responses:

1. **Beer List Schema** (`beer-list-schema.json`): Validates beverage data with producers and products
2. **Festival Registry Schema** (`festival-registry-schema.json`): Validates festival configuration

These schemas can be used for:
- Validating test fixtures
- Understanding the expected API structure
- CI validation of festival configuration changes

## Important Patterns

### Error Handling

- Wrap API calls in try-catch blocks
- Store error messages in provider state
- Display user-friendly error messages in UI
- Provide retry functionality for failed operations

### Favorites & Ratings

- Persisted in SharedPreferences
- Scoped by festival ID
- Updated via Provider methods

### Category Filtering

Available categories come from the API data:
- beer, cider, perry, mead, wine, real cider, foreign beer

## UI Guidelines

- Use Material 3 design system
- Support both light and dark themes
- Use amber/copper color scheme (seed: `0xFFD97706`)
- Include proper loading and error states
- Use icons from Material Icons library

## E2E Testing

The project uses Playwright for end-to-end testing of the Flutter web build.

### Running E2E Tests

```bash
# Build the web app first (use base-href "/" for local E2E testing)
flutter build web --release --base-href "/"

# Install dependencies (first time)
npm install
npx playwright install chromium  # Only needed once per machine

# Start the http-server (in one terminal)
npm run serve:web

# Run tests (in another terminal)
npm run test:e2e

# Run with UI mode for debugging
npm run test:e2e:ui
```

### TypeScript/Playwright Conventions

- Use **single quotes** for strings (same as Dart)
- Use **async/await** for asynchronous operations
- Use `test.describe()` for grouping related tests
- Use `expect()` from `@playwright/test` for assertions
- Always wait for Flutter to be ready before interacting with the app
- Use helper function `waitForFlutterReady(page)` in tests

### Flutter Web Testing Limitations

**IMPORTANT**: Flutter web apps don't use traditional DOM elements!

- ❌ Can't use standard DOM selectors for Flutter widgets
- ❌ Can't directly interact with Flutter UI elements via Playwright
- ✅ Can verify page loads and Flutter canvas renders
- ✅ Can check network requests (API calls)
- ✅ Can test via accessibility features (ARIA labels from Semantics)
- ✅ Can monitor console errors and performance
- ✅ Can use visual regression testing (screenshots)

For full interaction testing (clicking buttons, typing in forms), use Flutter's built-in integration tests with the `integration_test` package instead. See [Flutter integration testing documentation](https://docs.flutter.dev/testing/integration-tests) for more details.

### E2E Test Structure

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  test('should do something', async ({ page }) => {
    await page.goto('/');
    // Your test code here
  });
});
```

## Common Workflows

### Starting Development

1. Discover available tasks: `./bin/mise tasks ls`
2. Get dependencies: `./bin/mise run install`
3. Generate code: `./bin/mise run generate`
4. Run tests: `./bin/mise run test`
5. Analyze code: `./bin/mise run analyze`
6. Start app: `MISE_ENV=dev ./bin/mise run dev`

### Making Code Changes

1. Review similar code to understand existing patterns
2. Make minimal, focused changes (follow single responsibility principle)
3. Generate code if needed: `./bin/mise run generate`
4. Run tests: `./bin/mise run test`
5. Check linting: `./bin/mise run analyze`
6. Commit with descriptive message (one logical change per commit)

### Adding Dependencies

1. Evaluate if functionality can be implemented with existing dependencies
2. Check dependency size, maintenance status, and security on [pub.dev](https://pub.dev)
3. Add to `pubspec.yaml` with specific version constraint
4. Run `./bin/mise run install`
5. Import in code only where needed

### Before Submitting PR

1. Generate code: `./bin/mise run generate`
2. Run all tests: `./bin/mise run test`
3. Run analyzer: `./bin/mise run analyze`
4. Build web (if making web changes): `MISE_ENV=dev ./bin/mise run build:web:prod`
5. Run E2E tests (if making web changes): See [E2E Testing](#e2e-testing) section

## Security Considerations

- **API URLs**: Use HTTPS only for production endpoints
- **User Input**: All user input is currently local (search, filters) - no server submission
- **Storage**: SharedPreferences used for favorites/ratings - contains no sensitive data
- **Dependencies**: Keep Flutter and package dependencies updated
- **API Keys**: Never commit API keys or secrets to the repository
- **External Links**: Use `url_launcher` package for safe external link handling

## Deployment

The app has three deployment environments:

1. **Production** (`cambeerfestival.app`)
   - Deployed on version tags (e.g., `v2025.12.0`)
   - Cloudflare Pages, branch `release`
   - Workflow: `.github/workflows/release-web.yml`

2. **Staging** (`staging.cambeerfestival.app`)
   - Deployed automatically on push to `main`
   - Cloudflare Pages, branch `main`
   - Workflow: `.github/workflows/build-deploy.yml`

3. **PR Previews**
   - Unique URL per pull request
   - Preview URL posted as comment on PR
   - Workflow: `.github/workflows/build-deploy.yml`

### Deployment Workflow

- Push to `main` → Staging deployment
- Create tag → Production deployment
- Open PR → Preview deployment

## Documentation

Full documentation is available in the `docs/` directory:

- [Development Guide](../docs/DEVELOPMENT.md) - Implementation details
- [Testing Flutter Web](../docs/TESTING_FLUTTER_WEB.md) - E2E testing approach
- [CI/CD](../docs/CICD.md) - Complete workflow documentation
- [URL Routing](../docs/URL_ROUTING.md) - Path-based routing
- [Cloudflare Pages Setup](../docs/CLOUDFLARE_PAGES_SETUP.md) - Deployment setup
- [Accessibility](../docs/ACCESSIBILITY.md) - Accessibility features and testing
