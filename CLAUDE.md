# Claude AI Instructions

Instructions for Claude AI when working on the Cambridge Beer Festival app.

## Repository Overview

**Cambridge Beer Festival App** - A Flutter application for browsing drinks at the Cambridge Beer Festival.

### Key Information

- **Language**: Dart/Flutter
- **Flutter Version**: 3.38.3+
- **Dart SDK**: >=3.2.0 <4.0.0
- **State Management**: Provider
- **Platforms**: Android, iOS, Web

## Essential Commands

```bash
# First-time setup
flutter pub get

# Verify code quality (run before and after changes)
flutter analyze --no-fatal-infos

# Run tests
flutter test

# Run the app locally
flutter run

# Build for web deployment
flutter build web --release --base-href "/cambridge-beer-festival-app/"
```

## Tool Management with Mise

This project uses [Mise](https://mise.jdx.dev) for managing development tools and task running.

### Important: Use ./bin/mise

**Always use `./bin/mise` (not plain `mise`)** when running mise commands in this repository.

### Environment-Specific Tools

Tools are split across two environments to optimize for different use cases:

**Base environment** (`mise.toml`):
- **Flutter 3.38.3** - Required in all environments (dev, CI, production)
- **Tasks** - Available in all environments

**Developer environment** (`mise.dev.toml`):
- **Claude Code** - Only needed for human developers
- **Node.js 21** - Only needed for human developers

### Setup Instructions

**For CI/Automated Environments:**
```bash
# Install only Flutter (base tools)
./bin/mise install
```

**For Developer Environments:**
```bash
# Install Flutter + Claude + Node (all tools)
MISE_ENV=dev ./bin/mise install

# Or set permanently in your shell rc file:
export MISE_ENV=dev
./bin/mise install
```

### Using Mise Tasks

```bash
# Run tests
./bin/mise run test

# Run with coverage
./bin/mise run coverage

# Analyze code
./bin/mise run analyze

# Run dev server
./bin/mise run dev
```

**Note:** CI workflows use Flutter directly (via `flutter-action`) and do not require mise.

## Directory Structure

```
lib/
├── main.dart          # Entry point, app setup, home navigation
├── models/            # Data classes (Drink, Product, Producer, Festival)
├── providers/         # State management (BeerProvider)
├── screens/           # Full-page UI components
├── services/          # API calls and storage
└── widgets/           # Reusable UI components

test/                  # Unit and widget tests
web/                   # Web-specific assets
cloudflare-worker/     # API proxy worker
```

## Code Style Checklist

When writing or modifying Dart code:

- [ ] Use single quotes: `'string'` not `"string"`
- [ ] Use `const` constructors where possible
- [ ] Use `final` for local variables
- [ ] Include `{super.key}` in widget constructors
- [ ] Sort `child`/`children` properties last in widgets
- [ ] Avoid `print()` - use `debugPrint()` if needed
- [ ] Add new files to barrel exports (e.g., `models.dart`)

## Working with Models

### JSON Parsing Pattern

API data types can vary. Always handle type variations:

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

### Core Models

- **Festival**: Beer festival event with API data URL
- **Producer**: Brewery/cidery with location and products list
- **Product**: Individual beverage with ABV, style, category
- **Drink**: Combines Product + Producer for display purposes

## Working with State (Provider)

The app uses `BeerProvider` for all state:

```dart
// Reading state (triggers rebuild on changes)
final provider = context.watch<BeerProvider>();
final drinks = provider.drinks;

// One-time access (no rebuild)
final provider = context.read<BeerProvider>();
provider.setCategory('beer');
```

### Key Provider Methods

- `initialize()` - Load festivals and set up storage
- `loadDrinks()` - Fetch drinks from current festival
- `setFestival(Festival)` - Change active festival
- `setCategory(String?)` - Filter by category
- `setSearchQuery(String)` - Filter by search text
- `toggleFavorite(Drink)` - Toggle favorite status
- `setRating(Drink, int)` - Set drink rating

## Testing Requirements

When adding features or fixing bugs:

1. Check if existing tests cover the area
2. Add tests for new functionality
3. Ensure all tests pass: `flutter test`

### Test File Location

Tests go in `test/` mirroring `lib/` structure:
- `lib/models/drink.dart` → `test/models_test.dart`

## API Details

**Base URL**: `https://cbf-data-proxy.richard-alcock.workers.dev`

**Endpoints**:
- `/{festivalId}/beer.json` - Beers
- `/{festivalId}/cider.json` - Ciders
- `/{festivalId}/perry.json` - Perry
- `/{festivalId}/mead.json` - Meads
- `/{festivalId}/wine.json` - Wines
- `/{festivalId}/international-beer.json` - International beers
- `/{festivalId}/low-no.json` - Low/no alcohol

**Response Format**: Array of Producer objects, each containing products

### API Documentation

Full API documentation and JSON schemas are available in `docs/api/`:

- **[docs/api/README.md](docs/api/README.md)** - Overview and quick reference
- **[docs/api/data-api-reference.md](docs/api/data-api-reference.md)** - Complete API reference
- **[docs/api/beer-list-schema.json](docs/api/beer-list-schema.json)** - JSON Schema for beverage data
- **[docs/api/festival-registry-schema.json](docs/api/festival-registry-schema.json)** - JSON Schema for festival config

These schemas define the expected API response structure and can be used for validation.

## Common Modifications

### Adding a Screen

1. Create `lib/screens/my_screen.dart`:
```dart
import 'package:flutter/material.dart';

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

2. Export in `lib/screens/screens.dart`:
```dart
export 'my_screen.dart';
```

### Adding Provider State

1. Add private field: `String? _myField;`
2. Add getter: `String? get myField => _myField;`
3. Add setter method:
```dart
void setMyField(String? value) {
  _myField = value;
  notifyListeners();
}
```

## Validation Workflow

After making changes:

1. `flutter analyze --no-fatal-infos` - Check for issues
2. `flutter test` - Run all tests
3. Review changes for const/final usage
4. Verify barrel exports are updated

## Do Not Change Without Request

- GitHub Actions workflows (`.github/workflows/`)
- Cloudflare Worker (`cloudflare-worker/`)
- Package versions in `pubspec.yaml`
- Analysis rules in `analysis_options.yaml`
