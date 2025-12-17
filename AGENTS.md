# AI Agent Instructions

This document provides instructions for AI coding agents (Claude, Copilot, etc.) working on the Cambridge Beer Festival app.

## Quick Reference

| Task | Command |
|------|---------|
| Install dependencies | `flutter pub get` or `./bin/mise run install` |
| Analyze code | `flutter analyze --no-fatal-infos` or `./bin/mise run analyze` |
| Run tests | `flutter test` or `./bin/mise run test` |
| Run app | `flutter run` or `./bin/mise run dev` |
| Build web | `flutter build web --release --base-href "/cambridge-beer-festival-app/"` |

**Note**: Use `./bin/mise` commands when available. The mise tool bundles Flutter and ensures correct versions.

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
