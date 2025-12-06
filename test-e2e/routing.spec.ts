import { test, expect, Page } from '@playwright/test';

/**
 * E2E tests for go_router navigation on web
 *
 * These tests verify routing behavior by checking:
 * 1. URLs update correctly when navigating
 * 2. No console errors occur during navigation
 * 3. Browser history (back/forward) works
 * 4. Page refreshes preserve the current route
 * 5. ARIA labels (from Semantics widgets) confirm correct screens are displayed
 * 
 * Note: Flutter web renders UI to canvas, but it DOES create DOM elements for
 * accessibility (ARIA labels). We can use these to verify routing worked correctly.
 */

/**
 * Helper: Wait for page to be ready
 * Waits for network idle and a short delay for Flutter initialization
 */
async function waitForPageReady(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle');
  // Small delay to let Flutter finish initialization
  await page.waitForTimeout(1000);
}

test.describe('URL Routing - Basic Routes', () => {
  test('should navigate to root path without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should navigate to favorites route without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/favorites');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should navigate to about route without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL is correct
    expect(page.url()).toBe('http://127.0.0.1:8080/about');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('Deep Linking - Parameterized Routes', () => {
  test('should handle deep link to drink route', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Navigate to a parameterized route
    const drinkId = 'test-drink-123';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the drink ID (routing worked)
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('should handle deep link to brewery route', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    const breweryId = 'test-brewery-456';
    await page.goto(`http://127.0.0.1:8080/brewery/${breweryId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the brewery ID
    expect(page.url()).toContain(`/brewery/${breweryId}`);

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
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

    // Test with URL encoding
    const style = 'American IPA';
    await page.goto(`http://127.0.0.1:8080/style/${encodeURIComponent(style)}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify URL contains the encoded style
    expect(page.url()).toContain('/style/American');

    // Verify no critical console errors
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
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
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Navigate to a deep link
    const drinkId = 'test-drink-789';
    await page.goto(`http://127.0.0.1:8080/drink/${drinkId}`, { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Refresh the page
    await page.reload({ waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Verify we're still on the same route
    expect(page.url()).toContain(`/drink/${drinkId}`);

    // Verify no critical console errors after refresh
    const criticalErrors = consoleErrors.filter(e => 
      !e.includes('manifest') && !e.includes('favicon') && !e.includes('404')
    );
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('Accessibility - Verify Routing via ARIA Labels', () => {
  test('should show drinks tab ARIA label on root path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Flutter creates DOM elements for accessibility (Semantics widgets)
    // Check for the drinks tab ARIA label to confirm routing worked
    const drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should show favorites tab ARIA label on favorites path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/favorites', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // Check for favorites tab ARIA label
    const favoritesTabLabel = page.locator('[aria-label*="Favorites tab"]');
    await expect(favoritesTabLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should show about screen ARIA labels on about path', async ({ page }) => {
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);

    // About screen has unique buttons like "View source code on GitHub"
    const githubLabel = page.locator('[aria-label*="View source code on GitHub"]');
    await expect(githubLabel.first()).toBeAttached({ timeout: 5000 });
  });

  test('should update ARIA labels after browser back navigation', async ({ page }) => {
    // Start on drinks tab
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    
    let drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });

    // Navigate to about
    await page.goto('http://127.0.0.1:8080/about', { waitUntil: 'networkidle' });
    await waitForPageReady(page);
    
    const githubLabel = page.locator('[aria-label*="View source code on GitHub"]');
    await expect(githubLabel.first()).toBeAttached({ timeout: 5000 });

    // Go back - should show drinks tab again
    await page.goBack();
    await page.waitForLoadState('networkidle');
    await waitForPageReady(page);
    
    drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
    await expect(drinksTabLabel.first()).toBeAttached({ timeout: 5000 });
  });
});
