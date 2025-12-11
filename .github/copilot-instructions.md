# GitHub Copilot Instructions

This file provides context and guidelines for GitHub Copilot to generate better code suggestions for the Cambridge Beer Festival app.

## Project Overview

This is a **Flutter** application for browsing drinks (beers, ciders, meads, wines, etc.) at the Cambridge Beer Festival. The app supports Android, iOS, and Web platforms.

### Tech Stack

- **Framework**: Flutter (3.24.5+)
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
- The app uses `SelectionArea` to enable text selection throughout the app

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

# Build for web
flutter build web --release --base-href "/cambridge-beer-festival-app/"

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
