# GitHub Copilot Instructions

This file provides context and guidelines for GitHub Copilot to generate better code suggestions for the Cambridge Beer Festival app.

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
└── widgets/               # Reusable UI components (DrinkCard, etc.)
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

### Barrel Files

Each directory contains a barrel file (e.g., `models.dart`, `services.dart`) that exports all files in that directory. When adding new files, update the corresponding barrel file.

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

## API

The app uses a Cloudflare Worker proxy to access Cambridge Beer Festival data:

- Base URL: `https://cbf-data-proxy.richard-alcock.workers.dev`
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

1. Get dependencies: `flutter pub get`
2. Run tests: `flutter test`
3. Analyze code: `flutter analyze --no-fatal-infos`
4. Start app: `flutter run` (or `mise run dev` with [mise](https://mise.jdx.dev/) dev environment manager)

### Making Code Changes

1. Review similar code to understand existing patterns
2. Make minimal, focused changes (follow single responsibility principle)
3. Run relevant tests: `flutter test test/path/to/test.dart`
4. Check linting: `flutter analyze`
5. Commit with descriptive message (one logical change per commit)

### Adding Dependencies

1. Evaluate if functionality can be implemented with existing dependencies
2. Check dependency size, maintenance status, and security on [pub.dev](https://pub.dev)
3. Add to `pubspec.yaml` with specific version constraint
4. Run `flutter pub get`
5. Import in code only where needed

### Before Submitting PR

1. Run all tests: `flutter test`
2. Run analyzer: `flutter analyze --no-fatal-infos`
3. Build web (if making web changes): `flutter build web --release --base-href "/cambridge-beer-festival-app/"`
4. Run E2E tests (if making web changes): See [E2E Testing](#e2e-testing) section

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
