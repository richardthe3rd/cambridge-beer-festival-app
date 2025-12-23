# Deep Linking Testing Strategy

## Overview

This document outlines the testing strategy for festival-scoped deep linking, including unit tests, widget tests, integration tests, and end-to-end (E2E) tests.

## Testing Pyramid

```
           /\
          /  \     E2E Tests (Playwright)
         /____\    - Full user flows
        /      \   - Deep link scenarios
       /        \
      /  INTEG.  \ Integration Tests (Flutter)
     /____________\- Route navigation
    /              \- Provider interactions
   /    WIDGET     \
  /________________\ Widget Tests (Flutter)
 /                  \- BreadcrumbBar
/      UNIT          \- CategoryScreen
/____________________\- Navigation helpers

```

## Phase 1: Unit Tests

### 1.1 Navigation Helpers Tests

**File:** `test/utils/navigation_helpers_test.dart` (NEW)

**Purpose:** Test URL building functions

**Tests:**
```dart
group('Navigation Helpers', () {
  test('buildFestivalUrl returns correct path', () {
    expect(buildFestivalUrl('cbf2025'), '/cbf2025');
  });

  test('buildDrinkUrl returns correct path', () {
    expect(
      buildDrinkUrl('cbf2025', 'drink123'),
      '/cbf2025/drink/drink123',
    );
  });

  test('buildProducerUrl returns correct path', () {
    expect(
      buildProducerUrl('cbf2025', 'brew456'),
      '/cbf2025/producer/brew456',
    );
  });

  test('buildStyleUrl encodes special characters', () {
    expect(
      buildStyleUrl('cbf2025', 'India Pale Ale'),
      '/cbf2025/style/India%20Pale%20Ale',
    );
  });

  test('buildCategoryUrl encodes special characters', () {
    expect(
      buildCategoryUrl('cbf2025', 'low-no'),
      '/cbf2025/category/low-no',
    );
  });

  test('buildFestivalInfoUrl returns correct path', () {
    expect(
      buildFestivalInfoUrl('cbf2025'),
      '/cbf2025/info',
    );
  });

  test('buildFavoritesUrl returns correct path', () {
    expect(
      buildFavoritesUrl('cbf2025'),
      '/cbf2025/favorites',
    );
  });

  test('buildAboutUrl returns global path', () {
    expect(buildAboutUrl(), '/about');
  });
});
```

**Edge cases to test:**
- Empty strings
- Special characters (spaces, slashes, unicode)
- Very long IDs
- Null safety

---

## Phase 2: Widget Tests

### 2.1 BreadcrumbBar Widget Tests

**File:** `test/widgets/breadcrumb_bar_test.dart` (NEW)

**Purpose:** Test breadcrumb rendering and interaction

**Tests:**
```dart
group('BreadcrumbBar', () {
  testWidgets('displays all breadcrumb items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BreadcrumbBar(
          festivalId: 'cbf2025',
          items: [
            BreadcrumbItem(label: 'Festival', url: '/cbf2025'),
            BreadcrumbItem(label: 'Brewery', url: '/cbf2025/producer/1'),
            BreadcrumbItem(label: 'Drink', url: null),
          ],
        ),
      ),
    );

    expect(find.text('Festival'), findsOneWidget);
    expect(find.text('Brewery'), findsOneWidget);
    expect(find.text('Drink'), findsOneWidget);
  });

  testWidgets('displays separators between items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BreadcrumbBar(
          festivalId: 'cbf2025',
          items: [
            BreadcrumbItem(label: 'Festival', url: '/cbf2025'),
            BreadcrumbItem(label: 'Drink', url: null),
          ],
        ),
      ),
    );

    // Look for chevron or separator (›)
    expect(find.text('›'), findsOneWidget);
  });

  testWidgets('clickable items are interactive', (tester) async {
    // Test that items with URLs are tappable
    // Mock navigation and verify it's called
  });

  testWidgets('current page item is not clickable', (tester) async {
    // Test that item with null URL is not interactive
  });

  testWidgets('truncates long labels with ellipsis', (tester) async {
    // Test overflow behavior
  });

  testWidgets('has proper semantics for screen readers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BreadcrumbBar(
          festivalId: 'cbf2025',
          items: [
            BreadcrumbItem(label: 'Festival', url: '/cbf2025'),
            BreadcrumbItem(label: 'Drink', url: null),
          ],
        ),
      ),
    );

    // Verify semantic labels
    final semantics = tester.getSemantics(find.byType(BreadcrumbBar));
    // Check for proper ARIA labels
  });
});
```

---

### 2.2 CategoryScreen Widget Tests

**File:** `test/screens/category_screen_test.dart` (NEW)

**Purpose:** Test category screen rendering and behavior

**Tests:**
```dart
group('CategoryScreen', () {
  testWidgets('displays category name in header', (tester) async {
    // Setup mock provider with test data
    await tester.pumpWidget(/* ... */);
    expect(find.text('beer'), findsOneWidget);
  });

  testWidgets('displays filtered drinks for category', (tester) async {
    // Test that only drinks in the category are shown
  });

  testWidgets('shows empty state when no drinks', (tester) async {
    // Test empty category handling
  });

  testWidgets('displays breadcrumbs', (tester) async {
    // Verify breadcrumb bar is present
    expect(find.byType(BreadcrumbBar), findsOneWidget);
  });

  testWidgets('drink cards navigate to detail', (tester) async {
    // Test that tapping drink card navigates correctly
  });

  testWidgets('home button navigates to festival', (tester) async {
    // Test home button when can't pop
  });

  testWidgets('displays category statistics', (tester) async {
    // Test that stats (count, avg ABV) are shown
  });
});
```

---

### 2.3 Existing Screen Tests (Updates Needed)

**Files to update:**
- `test/screens/drinks_screen_test.dart` - Add festivalId parameter
- `test/screens/drink_detail_screen_test.dart` - Add festivalId parameter, test breadcrumbs
- `test/screens/brewery_screen_test.dart` - Add festivalId parameter, test breadcrumbs
- `test/screens/style_screen_test.dart` - Add festivalId parameter, test breadcrumbs

**Common test updates:**
```dart
// Before:
await tester.pumpWidget(
  MaterialApp(home: DrinkDetailScreen(drinkId: 'test123')),
);

// After:
await tester.pumpWidget(
  MaterialApp(home: DrinkDetailScreen(
    festivalId: 'cbf2025',
    drinkId: 'test123',
  )),
);
```

---

## Phase 3: Integration Tests

### 3.1 Router Navigation Tests

**File:** `test/router_test.dart` (NEW or UPDATE)

**Purpose:** Test routing logic and navigation flows

**Tests:**
```dart
group('Router', () {
  testWidgets('root / redirects to current festival', (tester) async {
    // Mock provider with current festival
    await tester.pumpWidget(/* app with router */);

    // Navigate to '/'
    // Verify redirect to '/cbf2025'
  });

  testWidgets('festival route loads DrinksScreen', (tester) async {
    // Navigate to '/cbf2025'
    // Verify DrinksScreen is displayed
  });

  testWidgets('drink detail route loads DrinkDetailScreen', (tester) async {
    // Navigate to '/cbf2025/drink/123'
    // Verify DrinkDetailScreen is displayed with correct drink
  });

  testWidgets('brewery route loads BreweryScreen', (tester) async {
    // Navigate to '/cbf2025/producer/456'
    // Verify BreweryScreen is displayed
  });

  testWidgets('style route loads StyleScreen', (tester) async {
    // Navigate to '/cbf2025/style/IPA'
    // Verify StyleScreen is displayed with correct style
  });

  testWidgets('category route loads CategoryScreen', (tester) async {
    // Navigate to '/cbf2025/category/beer'
    // Verify CategoryScreen is displayed
  });

  testWidgets('invalid festival redirects to default', (tester) async {
    // Navigate to '/invalid-festival'
    // Verify redirect to current festival
  });

  testWidgets('deep link with different festival switches context', (tester) async {
    // Navigate to '/cbf2024/drink/123' when provider is on cbf2025
    // Verify festival context switches
  });

  testWidgets('bottom nav preserves festival context', (tester) async {
    // Navigate to '/cbf2025/drink/123'
    // Tap Favorites in bottom nav
    // Verify navigation to '/cbf2025/favorites' (not different festival)
  });

  testWidgets('back button works correctly', (tester) async {
    // Navigate through multiple screens
    // Use back button
    // Verify correct navigation history
  });
});
```

---

### 3.2 Provider Integration Tests

**File:** `test/integration/provider_routing_integration_test.dart` (NEW)

**Purpose:** Test interaction between routing and provider state

**Tests:**
```dart
group('Provider + Routing Integration', () {
  testWidgets('URL festival matches provider festival', (tester) async {
    // Navigate to '/cbf2024'
    // Verify provider.currentFestival.id == 'cbf2024'
  });

  testWidgets('changing festival updates URL', (tester) async {
    // Start at '/cbf2025'
    // Change festival via provider
    // Verify URL updates to '/cbf2024'
  });

  testWidgets('favorites are festival-scoped', (tester) async {
    // Add favorite in cbf2025
    // Switch to cbf2024
    // Verify favorite doesn't appear (unless drink exists in both)
  });

  testWidgets('last selected festival persists', (tester) async {
    // Navigate to '/cbf2024'
    // Restart app (simulate)
    // Verify '/' redirects to '/cbf2024'
  });
});
```

---

## Phase 4: End-to-End Tests (Playwright)

### 4.1 Setup E2E Test Environment

**Prerequisites:**
- Flutter web build: `./bin/mise run build:web`
- Local server: `./bin/mise run serve:release`
- Playwright installed: `./bin/mise run playwright-setup`

**Test data:**
- Use cbf2025 test data (real or mocked)
- Known drink IDs, brewery IDs for stable tests

---

### 4.2 E2E Test Scenarios

**File:** `e2e/deep-linking.spec.ts` (NEW)

**Tests:**

```typescript
import { test, expect } from '@playwright/test';

const BASE_URL = 'http://localhost:8080/cambridge-beer-festival-app';
const FESTIVAL_ID = 'cbf2025';

test.describe('Deep Linking', () => {

  test('root redirects to current festival', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);

    // Wait for redirect
    await page.waitForURL(`${BASE_URL}/${FESTIVAL_ID}`);

    // Verify we're on drinks list
    await expect(page.locator('h1')).toContainText('Cambridge Beer Festival');
  });

  test('can navigate directly to drink detail', async ({ page }) => {
    // Replace DRINK_ID with real test data ID
    const DRINK_ID = 'test-drink-123';

    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/${DRINK_ID}`);

    // Verify drink detail page loaded
    await expect(page.locator('[data-testid="drink-detail"]')).toBeVisible();

    // Verify breadcrumbs
    await expect(page.locator('[data-testid="breadcrumbs"]')).toContainText('Cambridge Beer Festival');
  });

  test('can navigate directly to brewery detail', async ({ page }) => {
    const PRODUCER_ID = 'test-producer-456';

    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/producer/${PRODUCER_ID}`);

    // Verify brewery page loaded
    await expect(page.locator('[data-testid="brewery-detail"]')).toBeVisible();

    // Verify breadcrumbs
    await expect(page.locator('[data-testid="breadcrumbs"]')).toBeVisible();
  });

  test('can navigate directly to style page', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/style/IPA`);

    // Verify style page loaded
    await expect(page.locator('h1')).toContainText('IPA');

    // Verify drinks are filtered
    const drinkCards = page.locator('[data-testid="drink-card"]');
    expect(await drinkCards.count()).toBeGreaterThan(0);
  });

  test('can navigate directly to category page', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/category/beer`);

    // Verify category page loaded
    await expect(page.locator('h1')).toContainText('beer');
  });

  test('can navigate directly to festival info', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/info`);

    // Verify festival info page
    await expect(page.locator('[data-testid="festival-info"]')).toBeVisible();
  });

  test('breadcrumbs are clickable and work', async ({ page }) => {
    const DRINK_ID = 'test-drink-123';

    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/${DRINK_ID}`);

    // Click festival breadcrumb
    await page.locator('[data-testid="breadcrumb-festival"]').click();

    // Verify navigation to festival home
    await page.waitForURL(`${BASE_URL}/${FESTIVAL_ID}`);
    await expect(page.locator('[data-testid="drinks-list"]')).toBeVisible();
  });

  test('bottom nav preserves festival context', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/test-123`);

    // Click Favorites in bottom nav
    await page.locator('[data-testid="nav-favorites"]').click();

    // Verify URL includes festival ID
    await page.waitForURL(`${BASE_URL}/${FESTIVAL_ID}/favorites`);
  });

  test('sharing URL works correctly', async ({ page, context }) => {
    const DRINK_ID = 'test-drink-123';
    const drinkUrl = `${BASE_URL}/${FESTIVAL_ID}/drink/${DRINK_ID}`;

    // Navigate to drink
    await page.goto(drinkUrl);

    // Simulate copying URL
    const currentUrl = page.url();
    expect(currentUrl).toBe(drinkUrl);

    // Open in new tab (simulate sharing)
    const newPage = await context.newPage();
    await newPage.goto(currentUrl);

    // Verify page loads correctly
    await expect(newPage.locator('[data-testid="drink-detail"]')).toBeVisible();
  });

  test('URL updates when navigating between screens', async ({ page }) => {
    // Start at festival home
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}`);

    // Click first drink
    await page.locator('[data-testid="drink-card"]').first().click();

    // Verify URL changed to drink detail
    await expect(page).toHaveURL(new RegExp(`${FESTIVAL_ID}/drink/.*`));

    // Click brewery link
    await page.locator('[data-testid="brewery-link"]').click();

    // Verify URL changed to brewery
    await expect(page).toHaveURL(new RegExp(`${FESTIVAL_ID}/producer/.*`));
  });

  test('handles invalid festival gracefully', async ({ page }) => {
    await page.goto(`${BASE_URL}/invalid-festival/drink/test`);

    // Should redirect to valid festival or show error
    // Verify we don't get a white screen or crash
    await expect(page.locator('body')).toBeVisible();
  });

  test('handles missing drink gracefully', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/nonexistent`);

    // Should show "drink not found" or similar
    await expect(page.locator('text=/not found/i')).toBeVisible();
  });
});
```

---

### 4.3 Screenshot Comparison Tests

**File:** `e2e/screenshots.spec.ts` (UPDATE)

**Update existing screenshot tests to use new URLs:**

```typescript
test.describe('Screenshots', () => {
  test('festival home', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}`);
    await page.screenshot({ path: 'screenshots/home.png' });
  });

  test('drink detail', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/test-123`);
    await page.screenshot({ path: 'screenshots/drink-detail.png' });
  });

  // ... more screenshot tests
});
```

---

## Phase 5: Test Data Management

### 5.1 Test Data Strategy

**Challenge:** E2E tests need stable, predictable data

**Solutions:**

**Option A: Mock API (Recommended for E2E)**
- Create mock API server for tests
- Serve static JSON with known IDs
- Guaranteed stable test data

**Option B: Test Database**
- Seed test database with known data
- Reset between test runs
- More realistic but harder to maintain

**Option C: Use Real Data with Known IDs**
- Document specific drink/brewery IDs from real data
- Tests break if data changes
- Easiest but fragile

**Recommendation:** Option A for E2E, real data for manual testing

---

### 5.2 Test Data Structure

**File:** `test/fixtures/test_data.dart` (NEW)

```dart
class TestData {
  static const festivalId = 'cbf2025';
  static const drinkId = 'test-drink-123';
  static const producerId = 'test-producer-456';
  static const styleName = 'IPA';
  static const categoryName = 'beer';

  static Festival get testFestival => Festival(
    id: festivalId,
    name: 'Test Festival 2025',
    // ... other fields
  );

  static Drink get testDrink => Drink(
    id: drinkId,
    name: 'Test IPA',
    style: styleName,
    category: categoryName,
    // ... other fields
  );

  static Producer get testBrewery => Producer(
    id: breweryId,
    name: 'Test Brewery',
    // ... other fields
  );
}
```

---

## Phase 6: Continuous Integration

### 6.1 GitHub Actions Workflow Updates

**File:** `.github/workflows/test.yml` (UPDATE)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2

      # Build web app
      - run: flutter pub get
      - run: flutter build web --release --base-href "/cambridge-beer-festival-app/"

      # Setup Node.js for http-server and Playwright
      - uses: actions/setup-node@v3
        with:
          node-version: '21'

      # Install dependencies
      - run: npm install -g http-server
      - run: npx playwright install --with-deps

      # Start server in background
      - run: http-server build/web -p 8080 --proxy http://localhost:8080? &
      - run: sleep 5  # Wait for server to start

      # Run E2E tests
      - run: npx playwright test

      # Upload test results
      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

---

## Phase 7: Performance Testing

### 7.1 Route Performance Tests

**File:** `e2e/performance.spec.ts` (NEW)

**Tests:**
```typescript
test.describe('Performance', () => {
  test('deep link loads within 2 seconds', async ({ page }) => {
    const startTime = Date.now();

    await page.goto(`${BASE_URL}/${FESTIVAL_ID}/drink/test-123`);
    await page.waitForLoadState('domcontentloaded');

    const loadTime = Date.now() - startTime;
    expect(loadTime).toBeLessThan(2000);
  });

  test('navigation between screens is smooth', async ({ page }) => {
    await page.goto(`${BASE_URL}/${FESTIVAL_ID}`);

    // Measure navigation time
    const startTime = Date.now();
    await page.locator('[data-testid="drink-card"]').first().click();
    await page.waitForURL(/drink/);
    const navTime = Date.now() - startTime;

    expect(navTime).toBeLessThan(500);
  });
});
```

---

## Testing Checklist

### Unit Tests
- [ ] Navigation helper functions
- [ ] URL encoding/decoding
- [ ] Edge cases (null, empty, special chars)

### Widget Tests
- [ ] BreadcrumbBar rendering
- [ ] BreadcrumbBar interaction
- [ ] BreadcrumbBar semantics
- [ ] CategoryScreen display
- [ ] CategoryScreen filtering
- [ ] Updated existing screen tests

### Integration Tests
- [ ] Router navigation flows
- [ ] Root redirect behavior
- [ ] Invalid festival handling
- [ ] Provider + routing interaction
- [ ] Festival switching

### E2E Tests
- [ ] Deep link to all routes
- [ ] Breadcrumb navigation
- [ ] Bottom nav festival context
- [ ] URL sharing
- [ ] Navigation flow
- [ ] Error handling
- [ ] Screenshot comparisons

### Manual Testing
- [ ] Test on mobile browsers
- [ ] Test on desktop browsers
- [ ] Test with screen readers
- [ ] Test with large text
- [ ] Test copy/paste URLs
- [ ] Test browser back/forward
- [ ] Test refresh on each route

## Test Coverage Goals

- **Unit tests:** 100% of navigation helpers
- **Widget tests:** 80%+ of new widgets
- **Integration tests:** All major navigation flows
- **E2E tests:** All deep link routes + critical paths
- **Overall:** 80%+ code coverage

## Running Tests

```bash
# Unit + Widget tests
flutter test

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# E2E tests (requires local server)
./bin/mise run build:web
./bin/mise run serve:release &
npx playwright test

# CI (all tests)
flutter test && npx playwright test
```

## Test Maintenance

### When to Update Tests

1. **Adding new route:** Add integration + E2E tests
2. **Changing URL structure:** Update all affected tests
3. **New navigation pattern:** Add widget tests
4. **UI changes:** Update screenshot tests
5. **Breaking changes:** Update fixtures and mocks

### Test Review Checklist

- [ ] Tests are deterministic (no flaky tests)
- [ ] Tests use test data fixtures
- [ ] Tests have clear descriptions
- [ ] Tests are fast (unit < 1s, E2E < 10s)
- [ ] Tests clean up after themselves
- [ ] Tests cover happy path + edge cases

## Conclusion

This comprehensive testing strategy ensures:
- ✅ Deep linking works correctly
- ✅ Regressions are caught early
- ✅ Code quality is maintained
- ✅ User experience is validated
- ✅ CI/CD pipeline is robust
