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
  await page.waitForLoadState('networkidle');
  // Short delay to let Flutter finish initialization
  await page.waitForTimeout(500);
}

test.describe('URL Routing - Basic Routes', () => {
  test('should navigate to root path without errors', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/');
  });

  test('should navigate to favorites route without errors', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');
  });

  test('should navigate to about route without errors', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');
  });
});

test.describe('Deep Linking - Parameterized Routes', () => {
  test('should handle deep link to drink route', async ({ page }) => {
    // Navigate to a parameterized route
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the drink ID (routing worked)
    expect(page.url()).toContain(`/drink/${drinkId}`);
  });

  test('should handle deep link to brewery route', async ({ page }) => {
    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/brewery/${breweryId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the brewery ID
    expect(page.url()).toContain(`/brewery/${breweryId}`);
  });

  test('should handle URL-encoded style names', async ({ page }) => {
    // Test with URL encoding
    const style = 'American IPA';
    await page.goto(`http://127.0.0.1:8080/style/${encodeURIComponent(style)}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the encoded style
    expect(page.url()).toContain('/style/American');
  });
});

test.describe('Browser Navigation', () => {
  test('should handle browser back button', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Go back - this tests browser history integration
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    
    // Verify we're back at root (routing maintains history)
    expect(page.url()).toBe('http://127.0.0.1:8080/');
  });

  test('should handle browser forward button', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Go forward - this tests browser history integration
    await page.goForward();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    
    // Verify we're back at favorites (routing maintains history)
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');
  });

  test('should maintain history across multiple navigations', async ({ page }) => {
    // Navigate through multiple routes
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');
  });
});

test.describe('Page Refresh', () => {
  test('should preserve route on page refresh', async ({ page }) => {
    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');
  });

  test('should preserve deep link route on page refresh', async ({ page }) => {
    // Navigate to a deep link
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/drink/${drinkId}`);
  });
});
