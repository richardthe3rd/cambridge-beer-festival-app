# Test Setup

## Generating Mocks

Before running tests, generate mock files using:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This will generate `services_test.mocks.dart` required for timeout tests.

## Running Tests

```bash
flutter test
```
