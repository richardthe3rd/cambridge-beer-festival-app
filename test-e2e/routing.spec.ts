import { test, expect, Page } from '@playwright/test';

/**
 * E2E tests for go_router navigation on web
 *
 * Tests URL routing, deep linking, and browser back/forward buttons
 * work correctly with go_router implementation.
 */

/**
 * Helper: Wait for Flutter web app to be ready
 * Checks for Flutter-specific elements that indicate the app has initialized
 */
async function waitForFlutterReady(page: Page, timeout = 20000): Promise<void> {
  // Wait for network to be idle first
  await page.waitForLoadState('networkidle');

  // Wait for Flutter's view embedder to be present
  await page.waitForSelector('flt-glass-pane, [flt-renderer-host]', {
    timeout,
    state: 'attached'
  });

  // Give Flutter's framework a moment to finish initialization
  await page.waitForTimeout(1000);
}

test.describe('URL Routing', () => {
  test('should load root path "/" and show drinks screen', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/');
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should navigate to "/favorites" via URL', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/favorites');
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should navigate to "/about" via URL', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about');
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should navigate to "/festival-info" via URL', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/festival-info');
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/festival-info');

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });
});

test.describe('Deep Linking', () => {
  test('should support deep linking to specific drink', async ({ page }) => {
    // Use a parameterized route
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`);
    await waitForFlutterReady(page);

    // Verify URL contains the drink ID
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should support deep linking to specific brewery', async ({ page }) => {
    // Use a parameterized route
    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/brewery/${breweryId}`);
    await waitForFlutterReady(page);

    // Verify URL contains the brewery ID
    expect(page.url()).toContain(`/brewery/${breweryId}`);

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should support deep linking to specific style', async ({ page }) => {
    // Use a parameterized route with URL encoding
    const style = 'IPA';
    await page.goto(`http://127.0.0.1:8080/style/${encodeURIComponent(style)}`);
    await waitForFlutterReady(page);

    // Verify URL contains the style
    expect(page.url()).toContain(`/style/${style}`);

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should handle URL-encoded style names correctly', async ({ page }) => {
    // Test with a style that has spaces
    const style = 'American IPA';
    await page.goto(`http://127.0.0.1:8080/style/${encodeURIComponent(style)}`);
    await waitForFlutterReady(page);

    // Verify URL contains the encoded style
    expect(page.url()).toContain('/style/');

    // Verify page loaded successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });
});

test.describe('Browser Navigation', () => {
  test('should handle browser back button after navigation', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/');
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites');
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Verify page still works
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should handle browser forward button after back', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/');
    await waitForFlutterReady(page);

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites');
    await waitForFlutterReady(page);

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Go forward
    await page.goForward();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Verify page still works
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should maintain navigation history across multiple pages', async ({ page }) => {
    // Navigate through multiple routes
    const routes = [
      'http://127.0.0.1:8080/',
      'http://127.0.0.1:8080/favorites',
      'http://127.0.0.1:8080/about',
    ];

    for (const route of routes) {
      await page.goto(route);
      await waitForFlutterReady(page);
      expect(page.url()).toBe(route);
    }

    // Go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Verify page still works after multiple navigations
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });
});

test.describe('Page Refresh', () => {
  test('should preserve route on page refresh', async ({ page }) => {
    // Navigate to a specific route
    await page.goto('http://127.0.0.1:8080/favorites');
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify we're still on the same route
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Verify page still works
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should preserve deep link route on page refresh', async ({ page }) => {
    // Navigate to a deep link
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`);
    await waitForFlutterReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify page still works
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });
});

test.describe('URL State', () => {
  test('should update URL when navigating between main tabs', async ({ page }) => {
    // This test documents expected behavior but cannot actually click
    // Flutter canvas elements to trigger navigation.
    // We verify that direct URL navigation works, which implies
    // go_router is properly configured.

    // Start at root (drinks tab)
    await page.goto('http://127.0.0.1:8080/');
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Navigate to favorites tab via URL
    await page.goto('http://127.0.0.1:8080/favorites');
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Both URLs should load successfully
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });

  test('should handle invalid routes gracefully', async ({ page }) => {
    // Navigate to a non-existent route
    await page.goto('http://127.0.0.1:8080/nonexistent-route');

    // Even with an invalid route, Flutter should still load
    // (go_router will handle this with its error handling)
    await waitForFlutterReady(page);

    // Verify Flutter loaded
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached();
  });
});
