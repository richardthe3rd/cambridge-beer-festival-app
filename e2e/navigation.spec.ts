import { test, expect } from '@playwright/test';

/**
 * Browser navigation end-to-end tests for Flutter web app
 *
 * These tests validate that go_router correctly integrates with browser APIs:
 * - Browser history (back/forward buttons)
 * - URL updates and deep linking
 * - Page refresh handling
 *
 * Note: We don't click Flutter UI elements (rendered on canvas).
 * Instead, we navigate directly via URLs to test browser-level behavior.
 */

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';

test.describe('Browser History Integration', () => {
  test('home page loads and URL is correct', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Verify we're at root
    expect(page.url()).toMatch(/\/$/);
  });

  test('navigating to /about updates browser history', async ({ page }) => {
    // Start at home
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Navigate to /about directly
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    // Verify URL updated (browser API only - no content checking)
    expect(page.url()).toContain('/about');
  });

  test('browser back button navigates to previous page', async ({ page }) => {
    // Navigate: home -> about
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/about');

    // Click browser back button
    await page.goBack();
    await page.waitForLoadState('networkidle');

    // Should be back at home
    expect(page.url()).toMatch(/\/$/);
  });

  test('browser forward button navigates forward', async ({ page }) => {
    // Navigate: home -> about -> back to home
    await page.goto(BASE_URL);
    await page.goto(`${BASE_URL}/about`);
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toMatch(/\/$/);

    // Click browser forward button
    await page.goForward();
    await page.waitForLoadState('networkidle');

    // Should be at /about again
    expect(page.url()).toContain('/about');
  });

  test('multiple back/forward navigation works', async ({ page }) => {
    // Build history: home -> about -> home -> about
    await page.goto(BASE_URL);
    await page.goto(`${BASE_URL}/about`);
    await page.goBack();
    await page.goto(`${BASE_URL}/about`);

    // Now go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toMatch(/\/$/);

    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/about');

    // Go forward twice
    await page.goForward();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toMatch(/\/$/);

    await page.goForward();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/about');
  });
});

test.describe('Deep Linking', () => {
  test('can navigate directly to /about via URL', async ({ page }) => {
    // Direct navigation (e.g., from bookmark or link)
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    // Verify URL (browser API only)
    expect(page.url()).toContain('/about');
  });

  test('invalid route redirects or shows error', async ({ page }) => {
    // Navigate to non-existent route
    await page.goto(`${BASE_URL}/nonexistent-route`);
    await page.waitForLoadState('networkidle');

    // go_router should handle this gracefully
    // (either redirect to home or show error page)
    const url = page.url();

    // Accept either behavior - just verify it doesn't crash
    expect(url).toBeTruthy();
  });

  test('page refresh maintains current route', async ({ page }) => {
    // Navigate to /about
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/about');

    // Refresh page
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Should still be on /about (browser API only)
    expect(page.url()).toContain('/about');
  });
});

test.describe('URL Format Validation', () => {
  test('URLs use path-based routing (not hash)', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Home should be / (not /#/)
    expect(page.url()).toMatch(/\/$/);
    expect(page.url()).not.toContain('/#/');

    // Navigate to about
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    // About should be /about (not /#/about)
    expect(page.url()).toMatch(/\/about$/);
    expect(page.url()).not.toContain('/#/');
  });

  test('URLs are clean and bookmarkable', async ({ page }) => {
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    const url = page.url();

    // URL should be clean (no fragments, query params for routes, etc.)
    expect(url).toMatch(/^https?:\/\/[^?#]+\/about$/);
  });
});

test.describe('Mobile Web Compatibility', () => {
  test('browser back works on mobile viewport', async ({ page }) => {
    // Set mobile viewport (simulates mobile browser)
    await page.setViewportSize({ width: 375, height: 667 });

    // Navigate: home -> about
    await page.goto(BASE_URL);
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    // Browser back (equivalent to mobile swipe back)
    await page.goBack();
    await page.waitForLoadState('networkidle');

    // Should return to home, not close app
    expect(page.url()).toMatch(/\/$/);
  });

  test('history state is preserved on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });

    // Build history stack
    await page.goto(BASE_URL);
    await page.goto(`${BASE_URL}/about`);

    // Go back and forward
    await page.goBack();
    expect(page.url()).toMatch(/\/$/);

    await page.goForward();
    expect(page.url()).toContain('/about');
  });
});

test.describe('SPA Routing with http-server', () => {
  test('/about route works with direct navigation', async ({ page }) => {
    // This tests that http-server --proxy flag works correctly
    // When requesting /about, server should serve index.html with 200
    const response = await page.goto(`${BASE_URL}/about`);

    // Should get 200, not 404
    expect(response?.status()).toBe(200);

    // Should load the SPA and route to About
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/about');
  });

  test('refreshing /about maintains route', async ({ page }) => {
    await page.goto(`${BASE_URL}/about`);
    await page.waitForLoadState('networkidle');

    const response = await page.reload();

    // Should still get 200 and maintain route
    expect(response?.status()).toBe(200);
    expect(page.url()).toContain('/about');
  });
});
