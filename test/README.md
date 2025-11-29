# Test Setup

## Mocks

Mock files (e.g., `services_test.mocks.dart`) are **generated** files and are NOT committed to source control (listed in `.gitignore`). This follows the same pattern as other generated files like `*.g.dart` and `*.freezed.dart`.

### Local Development

Before running tests locally, generate mocks with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### CI/CD

The CI pipeline automatically generates mocks before running tests, so no additional setup is needed.

### Adding New Mocks

If you add new `@GenerateMocks` annotations:

1. Regenerate mocks: `dart run build_runner build --delete-conflicting-outputs`
2. Run tests to verify: `flutter test`
3. Commit only the test file with annotations (not the generated `.mocks.dart` file)

## Running Tests

```bash
# Generate mocks first (if not already done)
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test
```
