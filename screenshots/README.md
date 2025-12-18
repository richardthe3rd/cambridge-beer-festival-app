# Screenshots

This directory contains screenshots of the app's major screens, generated using Flutter's golden test framework with the `pumpWidget` approach.

## Overview

Screenshots are automatically generated from widget tests using the `pumpWidget` approach. Every PR automatically generates screenshots to help reviewers see visual changes at a glance.

## Screenshot Coverage

All screenshots are generated in both **light** and **dark** themes:

### Major Screens
- **DrinksScreen**: Main list view (phone, tablet, with search, empty state)
- **DrinkDetailScreen**: Individual drink details (phone, tablet)
- **BreweryScreen**: Brewery information and drinks (tablet)
- **AboutScreen**: App information (phone, tablet)
- **FestivalInfoScreen**: Festival details (phone, tablet)
- **StyleScreen**: Beer style information (existing)

## How It Works

### Local Development

#### Running Screenshot Tests
```bash
# Validate against existing goldens (regression check)
./bin/mise exec -- flutter test test/screenshots/

# Update golden files (when UI changes are intentional)
./bin/mise exec -- flutter test test/screenshots/ --update-goldens

# Copy screenshots to this directory
./scripts/copy_screenshots.sh
```

#### With Coverage
```bash
# Run all tests including screenshots with coverage
./bin/mise run coverage
```

### CI/CD Integration

#### Automatic Screenshot Generation (Pull Requests)
When you open a PR that modifies UI code:
1. Screenshot tests run automatically with `--update-goldens`
2. Fresh screenshots are generated for all major screens
3. Screenshots are committed to `pr-screenshot` branch in `pr-{number}/` folder
4. PR comment lists **only changed/new screenshots** with links to view them
5. If no visual changes detected, PR gets a ✅ comment

This helps reviewers quickly identify and review visual changes without needing to check out the branch locally.

## File Organization

```
test/screenshots/
├── goldens/                    # Golden files (source of truth)
│   ├── drinks_screen_phone_light.png
│   ├── drinks_screen_phone_dark.png
│   └── ...
├── drinks_screen_screenshot_test.dart
├── drink_detail_screen_screenshot_test.dart
└── ...

screenshots/                    # Convenience copies (local only)
├── drinks_screen_phone_light.png
├── drinks_screen_phone_dark.png
└── ...

pr-screenshot branch:          # Screenshots organized by PR
├── pr-123/
│   ├── drinks_screen_phone_light.png
│   └── ...
├── pr-124/
│   ├── about_screen_phone_light.png
│   └── ...
└── README.md
```

## Screen Sizes

- **Phone**: 428×926 (iPhone 14 Pro Max)
- **Tablet**: 820×1180 (iPad 11")

## Adding New Screenshot Tests

1. Create a new test file in `test/screenshots/`
2. Use the `screenshot_helper.dart` utilities
3. Use test fixtures from `test/fixtures/test_data.dart`
4. Run with `--update-goldens` to generate initial screenshots

Example:
```dart
import '../helpers/screenshot_helper.dart';
import '../fixtures/test_data.dart';

testWidgets('MyScreen - phone size', (WidgetTester tester) async {
  // Setup mock data
  when(mockApiService.fetchAllDrinks(any))
      .thenAnswer((_) async => allTestDrinks);
  await provider.loadDrinks();

  // Take screenshots in both themes
  await screenshotLightAndDark(
    tester: tester,
    screenWidget: const MyScreen(),
    provider: provider,
    screenName: 'my_screen',
    size: ScreenSizes.phone,
  );
});
```

## Coverage Benefits

Screenshot tests contribute to code coverage by executing the actual widget code. Running `flutter test --coverage` includes these tests in the coverage report.

## Troubleshooting

### Test Fails with Overflow Errors
Some screens may have layout overflow issues on certain sizes. Fix the layout bug in the source code (see [commit cb36b0c](https://github.com/richardthe3rd/cambridge-beer-festival-app/commit/cb36b0c) for an example).

### Platform Differences
Screenshots are generated in CI using Ubuntu runners with Flutter 3.38.3. Local screenshots may differ slightly due to platform-specific rendering. The CI-generated screenshots in `pr-screenshot` branch are the canonical reference.

## Best Practices

1. **Review generated screenshots**: Check the PR comment and review screenshots in `pr-screenshot` branch
2. **Use meaningful names**: Name screenshots clearly (e.g., `drinks_screen_search_light.png`)
3. **Test important states**: Cover loading, empty, error, and normal states
4. **Keep tests maintainable**: Use test fixtures and helper functions for consistency
