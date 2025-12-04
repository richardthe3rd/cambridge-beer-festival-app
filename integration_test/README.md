# Integration Tests

Browser automation tests for the Cambridge Beer Festival app to ensure navigation and routing functionality works correctly.

## Running Integration Tests

### Web (Chrome)

```bash
# Run integration tests in Chrome
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/navigation_test.dart \
  -d web-server

# Or with Chrome headless
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/navigation_test.dart \
  -d chrome --headless
```

### Mobile

```bash
# Android
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/navigation_test.dart \
  -d android

# iOS
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/navigation_test.dart \
  -d ios
```

## What's Tested

### Browser Navigation Tests
- ✅ URL updates when navigating to About screen
- ✅ Can navigate back from About screen
- ✅ Can navigate to drink detail and back
- ✅ Bottom navigation preserves state
- ✅ Can navigate through multiple screens

### Search and Filter Navigation
- ✅ Search functionality works

## Test Coverage

These tests verify:
1. **URL Updates**: Routes change correctly when navigating
2. **Browser Back Button**: Works correctly with go_router
3. **Navigation State**: State is preserved when switching tabs
4. **Multi-Screen Navigation**: Can navigate through multiple screens and back

## Adding New Tests

To add new navigation tests:

1. Add a new `testWidgets()` block in `navigation_test.dart`
2. Follow the pattern: `app.main()` → `pumpAndSettle()` → interact → verify
3. Use `find.byIcon()`, `find.byType()`, or `find.text()` to locate widgets
4. Use `tester.tap()` to interact, followed by `pumpAndSettle()`

Example:
```dart
testWidgets('My new navigation test', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Your test logic here
  final myWidget = find.byIcon(Icons.my_icon);
  await tester.tap(myWidget);
  await tester.pumpAndSettle();

  // Verify expected outcome
  expect(find.text('Expected Text'), findsOneWidget);
});
```

## Debugging Failed Tests

If tests fail:

1. **Increase wait times**: Add more `pumpAndSettle()` calls with delays
2. **Check widget existence**: Use `if (widget.evaluate().isNotEmpty)`
3. **Run with verbose output**: Add `--verbose` flag
4. **Check screenshots**: Tests can capture screenshots on failure

## CI Integration

These tests are run in CI on every PR to ensure navigation doesn't break.
See `.github/workflows/test.yml` for CI configuration.
