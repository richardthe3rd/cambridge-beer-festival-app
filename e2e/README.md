# End-to-End Browser Tests

Playwright-based browser automation tests for the Cambridge Beer Festival app.

## What's Tested

✅ **Real browser behavior:**
- URL bar updates when navigating
- Browser back/forward buttons work correctly
- Deep linking from URLs
- Page refresh maintains routes
- Multiple navigation flows

✅ **Cross-browser:**
- Desktop Chrome (Chromium)
- Mobile Chrome (Pixel 5)
- Optionally Firefox and Safari/WebKit

## Setup

```bash
cd e2e
npm install
npx playwright install
```

## Running Tests

### Local Development

```bash
# Run all tests (starts Flutter app automatically)
cd e2e
npm test

# Run with browser UI visible
npm run test:headed

# Debug mode with Playwright Inspector
npm run test:debug

# Interactive UI mode
npm run test:ui

# View test report
npm run report
```

### Manual Server

If you want to run the Flutter app separately:

```bash
# Terminal 1: Start Flutter web server
flutter run -d web-server --web-port=8080

# Terminal 2: Run Playwright tests
cd e2e
BASE_URL=http://localhost:8080 npm test
```

### CI

```bash
# Run in CI mode (no retries, GitHub reporter)
CI=true BASE_URL=http://localhost:8080 npm test
```

## Test Structure

```
e2e/
├── navigation.spec.ts     # Browser navigation tests
├── package.json           # Node dependencies
├── playwright.config.ts   # Playwright configuration
└── README.md             # This file
```

## Adding New Tests

```typescript
import { test, expect } from '@playwright/test';

test('my new test', async ({ page }) => {
  await page.goto('/');

  // Your test here
  await page.click('button:has-text("Click Me")');

  // Verify browser URL
  expect(page.url()).toContain('/#/new-route');
});
```

## Why Playwright?

- ✅ Tests **real browser behavior** (not just Flutter widgets)
- ✅ Can verify URL bar, browser buttons, deep links
- ✅ Modern, simple API
- ✅ Excellent debugging tools
- ✅ Cross-browser testing
- ✅ Built for web automation

## Common Patterns

### Check URL changed
```typescript
await page.waitForURL('**/#/about');
expect(page.url()).toContain('/#/about');
```

### Browser back button
```typescript
await page.goBack();
```

### Deep linking
```typescript
await page.goto('http://localhost:8080/#/drink/123');
```

### Wait for Flutter app
```typescript
await page.waitForLoadState('networkidle');
```

## Debugging

1. **Run in headed mode**: `npm run test:headed`
2. **Use debug mode**: `npm run test:debug`
3. **Check screenshots**: Screenshots saved on failure
4. **View trace**: Traces captured on retry

## CI Integration

Tests run automatically in CI:
- After unit tests pass
- Before deployment
- Must pass to merge PRs
- Run on Chromium and Mobile Chrome
