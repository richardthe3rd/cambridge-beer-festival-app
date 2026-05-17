import { test, expect, Page } from '@playwright/test';

/**
 * E2E tests for go_router navigation on web
 *
 * These tests verify routing behavior WITHOUT relying on UI inspection.
 * We test only what's reliably testable for Flutter web:
 * 1. URLs update correctly when navigating
 * 2. No console errors occur during navigation
 * 3. Browser history (back/forward) works
 * 4. Page refreshes preserve the current route
 *
 * Note: We do NOT attempt to verify which screen is displayed because
 * Flutter renders to canvas and ARIA labels may not be reliably available
 * during initial page load. Focus on routing mechanics, not screen content.
 */

/**
 * Helper: Wait for page to be ready
 * Waits for network idle and a short delay for Flutter initialization
 */
async function waitForPageReady(page: Page): Promise<void> {
  // Wait for network idle with extended timeout for CI
  await page.waitForLoadState('networkidle', { timeout: 30000 });
  // Wait for Flutter to initialize (longer in CI environments)
  await page.waitForTimeout(1500);
}

/**
 * Discover the default festival ID at runtime by following the root redirect.
 * This avoids hardcoding the festival ID so tests survive default festival changes.
 */
let defaultFestivalId: string;

test.beforeAll(async ({ browser }) => {
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  const [festivalId] = new URL(page.url()).pathname.split('/').filter(Boolean);
  defaultFestivalId = festivalId;
  await page.close();
});

test.describe('URL Routing - Basic Routes (Phase 1 - Festival-Scoped)', () => {
  test('should redirect root path to festival home', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Root should redirect to festival-scoped URL
    expect(page.url()).toContain(`/${defaultFestivalId}`);
  });

  test('should navigate to festival home without errors', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}`);
  });

  test('should navigate to festival-scoped favorites route', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);
  });

  test('should navigate to global about route (no festival scope)', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');
  });

  test('should navigate to festival info route', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/info`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/info`);
  });
});

test.describe('Deep Linking - Parameterized Routes (Phase 1 - Festival-Scoped)', () => {
  test('should handle deep link to drink route', async ({ page }) => {
    // Drink route format: /:festivalId/drink/:category/:id
    const category = 'beer';
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/drink/${category}/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains category and drink ID (routing worked)
    expect(page.url()).toContain(`/${defaultFestivalId}/drink/${category}/${drinkId}`);
  });

  test('should handle deep link to brewery route', async ({ page }) => {
    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/brewery/${breweryId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the brewery ID
    expect(page.url()).toContain(`/${defaultFestivalId}/brewery/${breweryId}`);
  });

  test('should handle URL-encoded style names with lowercase canonical format', async ({ page }) => {
    // Test with lowercase canonical URL (app generates lowercase URLs)
    const style = 'american ipa';
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/style/${encodeURIComponent(style)}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the encoded style in lowercase (canonical format)
    expect(page.url()).toContain(`/${defaultFestivalId}/style/american`);
  });

  test('should redirect invalid festival ID to default festival', async ({ page }) => {
    // Navigate with invalid festival ID
    await page.goto('http://127.0.0.1:8080/invalid-fest', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Should redirect to default festival
    expect(page.url()).toContain(`/${defaultFestivalId}`);
    expect(page.url()).not.toContain('invalid-fest');
  });

  test('should preserve query parameters when redirecting invalid festival', async ({ page }) => {
    // Navigate with invalid festival ID and query params
    await page.goto('http://127.0.0.1:8080/invalid-fest?search=IPA&category=beer', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Should redirect to default festival and preserve query params
    expect(page.url()).toContain(`/${defaultFestivalId}`);
    expect(page.url()).toContain('search=IPA');
    expect(page.url()).toContain('category=beer');
  });
});

test.describe('Browser Navigation (Phase 1 - Festival-Scoped)', () => {
  test('should handle browser back button', async ({ page }) => {
    // Start at festival home
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}`);

    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);

    // Go back - this tests browser history integration
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);

    // Verify we're back at festival home (routing maintains history)
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}`);
  });

  test('should handle browser forward button', async ({ page }) => {
    // Start at festival home
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}`);

    // Go forward - this tests browser history integration
    await page.goForward();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);

    // Verify we're back at favorites (routing maintains history)
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);
  });

  test('should maintain history across multiple navigations', async ({ page }) => {
    // Navigate through multiple routes
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);

    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}`);
  });
});

test.describe('Page Refresh (Phase 1 - Festival-Scoped)', () => {
  test('should preserve festival-scoped route on page refresh', async ({ page }) => {
    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toBe(`http://127.0.0.1:8080/${defaultFestivalId}/favorites`);
  });

  test('should preserve deep link route on page refresh', async ({ page }) => {
    // Drink route format: /:festivalId/drink/:category/:id
    const category = 'beer';
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}/drink/${category}/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/${defaultFestivalId}/drink/${category}/${drinkId}`);
  });

  test('should preserve query parameters on page refresh', async ({ page }) => {
    // Navigate with query parameters
    await page.goto(`http://127.0.0.1:8080/${defaultFestivalId}?search=IPA&category=beer`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify query parameters are still present
    expect(page.url()).toContain('search=IPA');
    expect(page.url()).toContain('category=beer');
  });
});
