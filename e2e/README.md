# End-to-End Browser Tests

Playwright-based browser automation tests for the Cambridge Beer Festival app.

## Testing Philosophy

**Flutter web apps use canvas rendering**, so we focus on **browser-level behavior** rather than clicking UI elements:

- ✅ Test browser APIs (history, navigation, URLs)
- ✅ Navigate directly via URLs
- ✅ Validate go_router integration with browser
- ❌ Don't click canvas-rendered buttons

This approach is reliable, fast, and tests what actually matters: browser history integration.

## What's Tested

✅ **Browser History Integration:**
- Back button navigation (mobile swipe back)
- Forward button navigation
- Multiple back/forward sequences

✅ **Deep Linking:**
- Direct URL navigation (bookmarks, shared links)
- Page refresh maintains route
- Invalid route handling

✅ **URL Format:**
- Path-based URLs (`/about`, not `/#/about`)
- Clean, bookmarkable URLs

✅ **Mobile Web:**
- Browser back on mobile viewport
- History state preservation

✅ **SPA Routing:**
- http-server integration
- Direct route navigation (200 not 404)
- Refresh maintains route

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
# Option 1: Use Flutter dev server (development mode)
flutter run -d web-server --web-port=8080

# Option 2: Build and serve with http-server (production mode)
flutter build web --release
cd build/web
npx http-server -p 8080 -c-1 --proxy http://localhost:8080?

# Terminal 2: Run Playwright tests
cd e2e
BASE_URL=http://localhost:8080 npm test
```

**Note**: `http-server` with `--proxy` flag enables SPA routing (serves `index.html` for all routes), matching production Cloudflare Pages behavior.

### CI

```bash
# Run in CI mode (no retries, GitHub reporter)
CI=true BASE_URL=http://localhost:8080 npm test
```

CI uses `http-server` to serve the built release app with SPA routing support.

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

  // Verify browser URL (path-based routing)
  expect(page.url()).toContain('/new-route');
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

### Check URL changed (path-based routing)
```typescript
await page.waitForURL('**/about');
expect(page.url()).toContain('/about');
```

### Browser back button
```typescript
await page.goBack();
```

### Deep linking
```typescript
await page.goto('http://localhost:8080/drink/123');
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
