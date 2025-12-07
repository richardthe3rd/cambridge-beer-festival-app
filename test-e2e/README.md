# E2E Web Tests

End-to-end tests for the Cambridge Beer Festival web application using Playwright.

## Overview

These tests verify that the Flutter web build works correctly by:
1. Running the built web app using Node.js http-server
2. Using Playwright to interact with the app in a real browser
3. Verifying core functionality works as expected

### Flutter Web Testing Approach

**See [Testing Flutter Web Apps](../docs/TESTING_FLUTTER_WEB.md) for detailed documentation.**

Flutter web apps render UI to canvas, but they **DO** create DOM elements for accessibility (ARIA labels from `Semantics` widgets). This is a well-established testing approach that:
- ✅ Verifies correct screens are displayed via ARIA labels
- ✅ Ensures the app is accessible to screen readers
- ✅ Provides stable test selectors
- ✅ Tests actual user-facing behavior

### Flutter Web Testing Limitations

**IMPORTANT**: Flutter web apps don't use traditional DOM elements for UI rendering!

- ❌ Can't use standard DOM selectors for Flutter widgets (buttons, text, etc.)
- ❌ Can't directly interact with Flutter UI elements via Playwright
- ✅ Can verify page loads and Flutter canvas renders
- ✅ Can check network requests (API calls)
- ✅ **Can test via accessibility features (ARIA labels from Semantics widgets)**
- ✅ Can monitor console errors and performance
- ✅ Can use visual regression testing (screenshots)

For full interaction testing (clicking buttons, typing in forms), use Flutter's built-in integration tests (`flutter test integration_test/`) instead.

## Prerequisites

- Node.js 21+ (already configured in `mise.toml`)
- Built web app in `build/web/`

## Running Tests Locally

### 1. Build the web app

```bash
flutter build web --release --base-href "/"
```

### 2. Install dependencies

```bash
npm install
```

### 3. Install Playwright browsers (first time only)

```bash
npx playwright install chromium
```

### 4. Start the http-server

In one terminal:
```bash
npm run serve:web
```

This starts http-server on http://127.0.0.1:8080

### 5. Run the tests

In another terminal:
```bash
npm run test:e2e
```

Or run with UI mode for debugging:
```bash
npm run test:e2e:ui
```

Or run in headed mode to see the browser:
```bash
npm run test:e2e:headed
```

## CI/CD

The E2E tests run automatically in CI after the web build:

1. `test` - Run unit tests and linting
2. `build-web` - Build the web app
3. **`test-e2e-web`** - Run E2E tests on the web build
4. `deploy-web` - Deploy to production (main branch only)

## Test Structure

- `test-e2e/` - E2E test files (*.spec.ts)
- `playwright.config.ts` - Playwright configuration
- `package.json` - Node dependencies and scripts

## Writing New Tests

Create new test files in `test-e2e/` with the `.spec.ts` extension:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  test('should do something', async ({ page }) => {
    await page.goto('/');
    // Your test code here
  });
});
```

See [Playwright documentation](https://playwright.dev/docs/writing-tests) for more details.

## Current Tests

### app.spec.ts

**App Loading**
- Verifies the Flutter web app loads and renders canvas
- Checks page title
- Validates viewport meta tag
- Verifies Flutter host elements are present

**Error Detection**
- Monitors console for critical errors during initialization
- Filters out benign warnings (manifest, favicon, etc.)

**JavaScript Loading**
- Verifies main.dart.js loads successfully
- Confirms Flutter framework is loaded

**Accessibility**
- Counts ARIA roles from Semantics widgets
- Provides baseline for future accessibility testing

## Future Tests

Planned tests to add (within Playwright's capabilities for Flutter web):

**Browser Navigation Tests:**
- Browser back/forward button functionality ✅
- Page refresh handling ✅
- Deep linking support (direct URL navigation) ✅
- Browser history state management ✅

**Network/API Tests:**
- Verify API calls to festival data endpoints
- Check data loading and caching behavior
- Test offline/error handling

**Accessibility Tests:**
- Verify ARIA roles and labels (from Semantics widgets)
- Check keyboard navigation support
- Test screen reader compatibility

**Performance Tests:**
- Measure initial load time
- Check bundle size
- Monitor memory usage
- Time to interactive (TTI)
- First contentful paint (FCP)

**Visual Regression Tests:**
- Screenshot comparison for key screens
- Responsive design verification
- Theme/styling consistency
- Different viewport sizes

**Note**: For interactive UI testing (clicking buttons, entering text, navigating), use Flutter integration tests in `integration_test/` directory instead.

## Troubleshooting

### Server not starting
Make sure port 8080 is available:
```bash
lsof -i :8080
kill -9 <PID>
```

### Tests timing out
Increase timeout in `playwright.config.ts`:
```typescript
timeout: 60 * 1000, // 60 seconds
```

### Browser not found
Reinstall Playwright browsers:
```bash
npx playwright install --force chromium
```
