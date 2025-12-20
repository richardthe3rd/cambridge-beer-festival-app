# AI Agent Instructions

This document provides instructions for AI coding agents (Claude, Copilot, etc.) working on the Cambridge Beer Festival app.

## ⚡ Quick Start - ALWAYS USE MISE

**CRITICAL**: This project uses `mise` for task management. Always use mise commands, not raw `flutter` commands.

### First Thing to Do in Every Session

```bash
# Discover available tasks
./bin/mise tasks ls

# For developer tasks (building, serving):
MISE_ENV=dev ./bin/mise tasks ls
```

## 📋 Quick Reference

| Task | Command | Notes |
|------|---------|-------|
| **Discover tasks** | `./bin/mise tasks ls` | Run this first! |
| Install dependencies | `./bin/mise run install` | Required after checkout |
| Generate code (mocks) | `./bin/mise run generate` | After model changes |
| Analyze code | `./bin/mise run analyze` | **Must pass before commit** |
| Run tests | `./bin/mise run test` | All unit/widget tests |
| Run tests with coverage | `./bin/mise run coverage` | Includes code generation |
| Run dev server | `MISE_ENV=dev ./bin/mise run dev` | Requires dev environment |
| Build for web (local) | `MISE_ENV=dev ./bin/mise run build:web` | For e2e testing |
| Build for production | `MISE_ENV=dev ./bin/mise run build:web:prod` | Production deployment |
| Serve release build | `MISE_ENV=dev ./bin/mise run serve:release` | Test production build |

**Why mise?**
- Ensures correct Flutter version (3.38.3)
- Consistent with CI/CD pipeline
- Bundles all required tools
- Prevents version conflicts

### Two Mise Environments

This project has two mise configurations:

1. **Base (`mise.toml`)**: Core tools and tasks - use `./bin/mise`
   - Available: install, generate, test, coverage, analyze

2. **Developer (`mise.dev.toml`)**: Additional dev tools - use `MISE_ENV=dev ./bin/mise`
   - Additional tasks: dev, build:web, build:web:prod, serve:release, playwright-setup
   - Additional tools: Firebase CLI, Playwright

**Rule**: If building or running the app → use `MISE_ENV=dev`

## 🔍 Task Discovery Guide

### How to Find Available Tasks

```bash
# List all base tasks (CI/testing tasks)
./bin/mise tasks ls

# List all developer tasks (includes build/serve)
MISE_ENV=dev ./bin/mise tasks ls

# Get help for a specific task
./bin/mise run <task-name> --help
```

### CI/CD Pipeline → Mise Task Mapping

The CI pipeline (`.github/workflows/build-deploy.yml`) runs these commands. Here's how to run them locally:

| CI Command | Mise Equivalent | When to Use |
|------------|-----------------|-------------|
| `flutter pub get` | `./bin/mise run install` | After checkout, pubspec changes |
| `dart run build_runner build --delete-conflicting-outputs` | `./bin/mise run generate` | After model changes, before tests |
| `flutter analyze --no-fatal-infos` | `./bin/mise run analyze` | Before committing |
| `flutter test --coverage` | `./bin/mise run coverage` | Testing with coverage |
| `flutter test` | `./bin/mise run test` | Quick test run |
| `flutter build web --release` | `MISE_ENV=dev ./bin/mise run build:web:prod` | Production builds |

**Always prefer mise commands** - they ensure environment consistency and correct tool versions.

## 🚫 Common Mistakes to Avoid

### ❌ Don't Do This
```bash
flutter pub get           # Bypasses version management
flutter test              # May use wrong Flutter version
flutter build web         # Missing mise environment setup
mise run build:web        # Missing MISE_ENV=dev (will fail)
```

### ✅ Do This Instead
```bash
./bin/mise run install         # Correct: uses ./bin/mise
./bin/mise run test            # Correct: proper environment
MISE_ENV=dev ./bin/mise run build:web  # Correct: has MISE_ENV
./bin/mise tasks ls            # Correct: discover first
```

## Testing Best Practices

### Running Tests

```bash
# Run all tests (can be slow)
./bin/mise run test

# Run specific test file
./bin/mise run test test/style_screen_test.dart

# Run tests with output to file for analysis
./bin/mise run test > /tmp/test_output.txt 2>&1
cat /tmp/test_output.txt | grep -E "(passed|failed)" | tail -10

# Run with timeout to prevent hanging
timeout 180 ./bin/mise run test
```

### Screenshot Testing

Use `pumpWidget` approach for generating UI screenshots:

```dart
testWidgets('screen with description - light theme', (WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(createTestWidget());
  await tester.pumpAndSettle();
  
  // Take screenshot
  await expectLater(
    find.byType(MyScreen),
    matchesGoldenFile('goldens/my_screen_light.png'),
  );
});

// Generate/update screenshots
flutter test --update-goldens test/my_screen_screenshot_test.dart
```

### Asset Loading in Tests

When testing code that loads assets (like JSON files):

```dart
testWidgets('loads asset data', (tester) async {
  // pumpWidget ensures asset bundle is available
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  
  final result = await MyHelper.loadData();
  expect(result, isNotNull);
});
```

**Don't** use `TestWidgetsFlutterBinding.ensureInitialized()` in plain `test()` - use `testWidgets()` instead.

## Project Context

This is a **Flutter mobile/web app** for browsing drinks at the Cambridge Beer Festival. Users can:
- Browse beers, ciders, meads, and wines
- Search and filter by category, name, brewery, or style
- Save favorites and rate drinks
- View brewery details

### Architecture

- **State Management**: Provider pattern with `ChangeNotifier`
- **Data Layer**: REST API via HTTP with JSON parsing
- **Persistence**: SharedPreferences for favorites/ratings
- **UI**: Material 3 with dark/light theme support

## Before Making Changes

1. **Understand the structure**: Review `lib/` directory organization
2. **Check existing patterns**: Look at similar code for conventions
3. **Run tests first**: Execute `flutter test` to establish baseline
4. **Analyze code**: Run `flutter analyze` to check for issues

## Code Style Requirements

### Dart/Flutter Conventions

```dart
// Use single quotes
final message = 'Hello, world!';

// Prefer const constructors
const EdgeInsets.all(16);

// Use final for local variables
final drinks = provider.drinks;

// Widget keys in constructors
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});  // ✓ Good
}

// Sort child properties last
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(...),
  child: Text('...'),  // child is last
)
```

### Linter Rules (from analysis_options.yaml)

- `prefer_const_constructors`: Use const when possible
- `prefer_const_declarations`: Declare const values as const
- `prefer_final_fields`: Use final for private fields
- `prefer_final_locals`: Use final for local variables
- `avoid_print`: Use debugPrint or proper logging
- `prefer_single_quotes`: Use single quotes for strings
- `sort_child_properties_last`: child/children should be last
- `use_key_in_widget_constructors`: Always include key parameter

## Making Changes

### Adding a New Screen

1. Create `lib/screens/new_screen.dart`
2. Export from `lib/screens/screens.dart`
3. Add navigation from existing screens

Example:
```dart
// lib/screens/new_screen.dart
import 'package:flutter/material.dart';

class NewScreen extends StatelessWidget {
  const NewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

### Adding a New Model

1. Create `lib/models/new_model.dart`
2. Include `fromJson` and `toJson` methods
3. Export from `lib/models/models.dart`
4. Add tests in `test/`

Example:
```dart
class NewModel {
  final String id;
  final String name;

  const NewModel({required this.id, required this.name});

  factory NewModel.fromJson(Map<String, dynamic> json) {
    return NewModel(
      id: json['id'].toString(),
      name: json['name'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

### Adding a New Service

1. Create `lib/services/new_service.dart`
2. Export from `lib/services/services.dart`
3. Inject dependencies, don't use singletons
4. Include `dispose()` method for cleanup

### Modifying Provider State

1. Add private field with underscore prefix
2. Add public getter
3. Add method to modify state
4. Call `notifyListeners()` after changes

## Testing Guidelines

### Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('ModelName', () {
    test('fromJson parses correctly', () {
      final json = {'id': '1', 'name': 'Test'};
      final model = ModelName.fromJson(json);
      
      expect(model.id, '1');
      expect(model.name, 'Test');
    });

    test('handles missing optional fields', () {
      // Test edge cases
    });
  });
}
```

### What to Test

- Model JSON parsing (all field types)
- Edge cases (null, missing, wrong type)
- Provider state changes
- Service API calls (with mocks)

## API Integration

### Festival Data Structure

```json
{
  "festivals": [
    {
      "id": "cbf2025",
      "name": "Cambridge Beer Festival 2025",
      "dataBaseUrl": "https://..."
    }
  ],
  "defaultFestivalId": "cbf2025"
}
```

### Beverage Data Structure

```json
{
  "id": "brewery-123",
  "name": "Brewery Name",
  "location": "City",
  "products": [
    {
      "id": "beer-1",
      "name": "Beer Name",
      "category": "beer",
      "style": "IPA",
      "abv": "5.5",
      "dispense": "cask"
    }
  ]
}
```

### API Documentation

Full API documentation and JSON schemas are in `docs/api/`:

- **[docs/api/README.md](docs/api/README.md)** - Overview and quick reference
- **[docs/api/data-api-reference.md](docs/api/data-api-reference.md)** - Complete API reference
- **[docs/api/beer-list-schema.json](docs/api/beer-list-schema.json)** - JSON Schema for beverage data
- **[docs/api/festival-registry-schema.json](docs/api/festival-registry-schema.json)** - JSON Schema for festival config

### Validating festivals.json

The `web/data/festivals.json` file is validated in CI against the schema:

```bash
cd scripts && npm install && node validate-festivals.js
```

## Common Tasks

### Adding a New Drink Category Filter

1. Categories are dynamic from API data
2. No code changes needed for new categories
3. UI automatically shows all available categories

### Adding a New Sort Option

1. Add enum value to `DrinkSort` in `beer_provider.dart`
2. Add case to `_applyFiltersAndSort()` switch statement
3. Add option to sort dropdown in `drinks_screen.dart`

### Adding User Preferences

1. Create key constant for SharedPreferences
2. Add to appropriate service (FavoritesService, RatingsService, or new)
3. Load in `BeerProvider.initialize()`

## CI/CD Pipeline

The project uses GitHub Actions for:
1. **Build**: Analyze code, run tests, build web
2. **Deploy**: Deploy to Cloudflare Pages (main branch and PRs)
3. **Worker**: Deploy Cloudflare Worker when changed

## Do Not Modify

- `.github/workflows/` without explicit request
- `cloudflare-worker/` without explicit request
- `pubspec.yaml` versions without necessity
- License or contribution guidelines

## Helpful Tips

1. **Check barrel files**: When adding new files, update exports
2. **Run analyze often**: Catch issues early with `flutter analyze`
3. **Use const**: Mark widgets as const for performance
4. **Handle null**: API data may have missing fields
5. **Theme colors**: Use `Theme.of(context)` for consistent colors
