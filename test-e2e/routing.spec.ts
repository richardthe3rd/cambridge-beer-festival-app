import { test, expect, Page } from '@playwright/test';

/**
 * E2E tests for go_router navigation on web
 *
 * IMPORTANT: Flutter web apps render to canvas, so we can't inspect UI content.
 * These tests verify that:
 * 1. Different routes load without errors
 * 2. Browser history works (back/forward)
 * 3. Page refreshes preserve routes
 * 4. No console errors occur during navigation
 *
 * We cannot verify which screen is displayed because Flutter renders to canvas.
 * For actual UI verification, use Flutter integration tests instead.
 */

/**
 * Helper: Wait for Flutter web app to be ready
 * Checks for Flutter-specific elements that indicate the app has initialized
 */
async function waitForFlutterReady(page: Page, timeout = 20000): Promise<void> {
  // Wait for network to be idle first
  await page.waitForLoadState('networkidle');

  // Wait for Flutter's view embedder to be present
  // This is more reliable than arbitrary timeouts
  await page.waitForSelector('flt-glass-pane, [flt-renderer-host]', {
    timeout,
    state: 'attached'
  });

  // Give Flutter's framework a moment to finish initialization
  // Using a short wait here is acceptable as we've already confirmed the view exists
  await page.waitForTimeout(1000);
}

test.describe('URL Routing - Basic Routes', () => {
  test('should load root path "/" without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should load "/favorites" route without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should load "/about" route without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('Deep Linking - Parameterized Routes', () => {
  test('should handle deep link to drink without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Use a parameterized route - the drink may not exist, but routing should work
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL contains the drink ID (routing worked)
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify no critical console errors during route handling
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should handle deep link to brewery without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/brewery/${breweryId}`, { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL contains the brewery ID (routing worked)
    expect(page.url()).toContain(`/brewery/${breweryId}`);

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should handle URL-encoded style names', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Test with a style that has spaces - verify URL encoding works
    const style = 'American IPA';
    await page.goto(`http://127.0.0.1:8080/style/${encodeURIComponent(style)}`, { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify URL contains the encoded style (routing worked)
    expect(page.url()).toContain('/style/American');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('Browser Navigation', () => {
  test('should handle browser back button', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Go back - this tests browser history integration
    await page.goBack();
    await page.waitForLoadState('networkidle');
    
    // Verify we're back at root (routing maintains history)
    expect(page.url()).toBe('http://127.0.0.1:8080/');
  });

  test('should handle browser forward button', async ({ page }) => {
    // Start at root
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Go forward - this tests browser history integration
    await page.goForward();
    await page.waitForLoadState('networkidle');
    
    // Verify we're back at favorites (routing maintains history)
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');
  });

  test('should maintain history across multiple navigations', async ({ page }) => {
    // Navigate through multiple routes
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Go back twice
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toBe('http://127.0.0.1:8080/');
  });
});

test.describe('Page Refresh', () => {
  test('should preserve route on page refresh', async ({ page }) => {
    // Navigate to favorites
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify we're still on the same route
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');
  });

  test('should preserve deep link route on page refresh', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Navigate to a deep link
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify no critical console errors after refresh
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon')
    );
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('Accessibility - Screen Verification', () => {
  test('should show drinks tab ARIA labels on root path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Check for the drinks tab ARIA label (confirms we're on drinks screen)
    const drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should show favorites tab ARIA labels on favorites path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Check for the favorites tab ARIA label (confirms we're on favorites screen)
    const favoritesTabLabel = page.locator('[aria-label*="Favorites tab"]');
    await expect(favoritesTabLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should show about screen ARIA labels on about path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);

    // Check for about screen specific ARIA labels (confirms we're on about screen)
    // About screen has unique buttons like "View source code on GitHub"
    const githubLabel = page.locator('[aria-label*="View source code on GitHub"]');
    await expect(githubLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should maintain ARIA labels after browser back/forward', async ({ page }) => {
    // Start on drinks tab
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    
    let drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });

    // Navigate to about
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForFlutterReady(page);
    
    const githubLabel = page.locator('[aria-label*="View source code on GitHub"]');
    await expect(githubLabel.first()).toBeAttached({ timeout: 5000 });

    // Go back - should be on drinks tab again
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForFlutterReady(page);
    
    drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });
  });
});
