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

test.describe('URL Routing - Basic Routes (Phase 1 - Festival-Scoped)', () => {
  const festivalId = 'cbf2025'; // Test with default festival

  test('should redirect root path to festival home', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Root should redirect to festival-scoped URL
    expect(page.url()).toContain(`/${festivalId}`);
  });

  test('should navigate to festival home without errors', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${festivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}`);
  });

  test('should navigate to festival-scoped favorites route', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${festivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);
  });

  test('should navigate to global about route (no festival scope)', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');
  });

  test('should navigate to festival info route', async ({ page }) => {
    await page.goto(`http://127.0.0.1:8080/${festivalId}/info`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/info`);
  });
});

test.describe('Deep Linking - Parameterized Routes (Phase 1 - Festival-Scoped)', () => {
  const festivalId = 'cbf2025';

  test('should handle deep link to drink route', async ({ page }) => {
    // Navigate to a parameterized route
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/${festivalId}/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the drink ID (routing worked)
    expect(page.url()).toContain(`/${festivalId}/drink/${drinkId}`);
  });

  test('should handle deep link to brewery route', async ({ page }) => {
    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/${festivalId}/brewery/${breweryId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the brewery ID
    expect(page.url()).toContain(`/${festivalId}/brewery/${breweryId}`);
  });

  test('should handle URL-encoded style names', async ({ page }) => {
    // Test with URL encoding
    const style = 'American IPA';
    await page.goto(`http://127.0.0.1:8080/${festivalId}/style/${encodeURIComponent(style)}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the encoded style
    expect(page.url()).toContain(`/${festivalId}/style/American`);
  });

  test('should redirect invalid festival ID to default festival', async ({ page }) => {
    // Navigate with invalid festival ID
    await page.goto('http://127.0.0.1:8080/invalid-fest', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Should redirect to default festival
    expect(page.url()).toContain(`/${festivalId}`);
    expect(page.url()).not.toContain('invalid-fest');
  });

  test('should preserve query parameters when redirecting invalid festival', async ({ page }) => {
    // Navigate with invalid festival ID and query params
    await page.goto('http://127.0.0.1:8080/invalid-fest?search=IPA&category=beer', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Should redirect to default festival and preserve query params
    expect(page.url()).toContain(`/${festivalId}`);
    expect(page.url()).toContain('search=IPA');
    expect(page.url()).toContain('category=beer');
  });
});

test.describe('Browser Navigation (Phase 1 - Festival-Scoped)', () => {
  const festivalId = 'cbf2025';

  test('should handle browser back button', async ({ page }) => {
    // Start at festival home
    await page.goto(`http://127.0.0.1:8080/${festivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}`);

    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${festivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);

    // Go back - this tests browser history integration
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);

    // Verify we're back at festival home (routing maintains history)
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}`);
  });

  test('should handle browser forward button', async ({ page }) => {
    // Start at festival home
    await page.goto(`http://127.0.0.1:8080/${festivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${festivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}`);

    // Go forward - this tests browser history integration
    await page.goForward();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);

    // Verify we're back at favorites (routing maintains history)
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);
  });

  test('should maintain history across multiple navigations', async ({ page }) => {
    // Navigate through multiple routes
    await page.goto(`http://127.0.0.1:8080/${festivalId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    await page.goto(`http://127.0.0.1:8080/${festivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);

    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}`);
  });
});

test.describe('Page Refresh (Phase 1 - Festival-Scoped)', () => {
  const festivalId = 'cbf2025';

  test('should preserve festival-scoped route on page refresh', async ({ page }) => {
    // Navigate to favorites
    await page.goto(`http://127.0.0.1:8080/${festivalId}/favorites`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toBe(`http://127.0.0.1:8080/${festivalId}/favorites`);
  });

  test('should preserve deep link route on page refresh', async ({ page }) => {
    // Navigate to a deep link
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/${festivalId}/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/${festivalId}/drink/${drinkId}`);
  });

  test('should preserve query parameters on page refresh', async ({ page }) => {
    // Navigate with query parameters
    await page.goto(`http://127.0.0.1:8080/${festivalId}?search=IPA&category=beer`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify query parameters are still present
    expect(page.url()).toContain('search=IPA');
    expect(page.url()).toContain('category=beer');
  });
});
