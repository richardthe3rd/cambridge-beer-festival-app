# Integration Tests

Flutter integration tests for the Cambridge Beer Festival app.

## Overview

Integration tests run the full Flutter app and can interact with widgets, test navigation, and capture screenshots. Unlike unit tests, integration tests can test the app as a whole, including routing, state management, and UI interactions.

## Screenshots for PR Reviews

The `screenshots_test.dart` file captures screenshots of key app screens for visual PR reviews. This replaced the previous Playwright-based screenshot approach with a native Flutter solution using the `integration_test` package's built-in screenshot capabilities.

### Running Screenshot Tests Locally

```bash
# For web platform
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d chrome
```

Screenshots will be saved to the `screenshots/` directory.

### How It Works

1. The test launches the full Flutter app
2. Navigates to different screens using the widget tree
3. Waits for content to load
4. Captures screenshots using `IntegrationTestWidgetsFlutterBinding.takeScreenshot()`
5. The custom driver saves PNG files to the screenshots directory

### Benefits Over Playwright

- ✅ **Native Flutter**: Uses Flutter's testing framework, no external browser automation
- ✅ **Faster**: No need to build and serve the web app separately
- ✅ **Simpler CI**: Fewer dependencies and setup steps
- ✅ **Better integration**: Can access Flutter widget tree directly
- ✅ **Runs earlier**: Can run in parallel with web build, speeding up CI

### CI/CD

Screenshots are automatically captured in CI for pull requests:

1. Tests pass
2. **`capture-screenshots`** job runs (in parallel with web build)
3. Screenshots are uploaded to the `pr-screenshots` branch
4. Bot posts a comment on the PR with screenshot previews

See `.github/workflows/build-deploy.yml` for the full implementation.

## Adding More Integration Tests

Create new test files in this directory with the `_test.dart` suffix:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cambridge_beer_festival/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('my integration test', (WidgetTester tester) async {
    await tester.pumpWidget(const app.BeerFestivalApp());
    await tester.pumpAndSettle();
    
    // Your test code here
  });
}
```

See [Flutter integration testing documentation](https://docs.flutter.dev/testing/integration-tests) for more details.
