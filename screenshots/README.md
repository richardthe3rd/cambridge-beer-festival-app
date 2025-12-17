# Screenshots

This directory contains screenshots of the app's major screens, generated using Flutter's golden test framework with the `pumpWidget` approach.

## Overview

Screenshots are automatically generated from widget tests and serve two purposes:

1. **Documentation**: Visual reference of how the app looks
2. **Regression Detection**: Automated detection of unintended UI changes

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

#### Automatic Validation (Pull Requests)
When you open a PR that changes UI code:
1. Screenshot tests run automatically
2. Tests **fail** if screenshots don't match goldens (regression detected)
3. PR comment shows which screenshots changed (if any)

#### Updating Goldens (Manual Workflow)
When UI changes are intentional:
1. Go to **Actions → Screenshot Tests**
2. Click **Run workflow**
3. Select your branch
4. Set **Update golden files** to `true`
5. Run the workflow
6. Updated screenshots are committed to `pr-screenshot` branch in a folder named `pr-{number}/`

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

### Golden Mismatch
If tests fail with "golden file mismatch":
- For **intentional changes**: Update goldens with `--update-goldens`
- For **unintentional changes**: Review and fix the UI regression

### Platform Differences
Golden tests can have slight rendering differences across platforms. Run tests in CI or use consistent environments.

## Best Practices

1. **Always validate before merging**: Run screenshot tests before submitting PR
2. **Update goldens intentionally**: Don't blindly update - review the changes
3. **Keep goldens in source control**: Commit golden files to track visual history
4. **Use meaningful names**: Name screenshots clearly (e.g., `drinks_screen_search_light.png`)
5. **Test important states**: Cover loading, empty, error, and normal states
