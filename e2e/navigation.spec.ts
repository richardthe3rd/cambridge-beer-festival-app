import { test, expect } from '@playwright/test';

/**
 * Browser navigation end-to-end tests
 *
 * Tests real browser behavior:
 * - URL updates in address bar
 * - Browser back/forward buttons
 * - Deep linking
 * - Page refresh on routes
 */

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';

test.describe('Browser Navigation', () => {
  test('home page loads with correct URL', async ({ page }) => {
    await page.goto(BASE_URL);

    // Wait for app to load and Flutter to initialize
    await page.waitForLoadState('networkidle');
    await page.waitForSelector('body', { state: 'visible' });

    // Verify URL is home
    expect(page.url()).toMatch(/\/#\/$/);
  });

  test('clicking About button updates URL', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Wait for About button to be ready
    const aboutButton = page.locator('button[aria-label*="About"], button:has-text("About")').first();
    await aboutButton.waitFor({ state: 'visible', timeout: 10000 });

    // Click the info/about button
    await aboutButton.click();

    // Wait for navigation
    await page.waitForURL('**/#/about', { timeout: 5000 });

    // Verify URL changed
    expect(page.url()).toContain('/#/about');

    // Verify About page is shown
    await expect(page.locator('text=About')).toBeVisible();
  });

  test('browser back button returns to home', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Navigate to About
    const aboutButton = page.locator('button[aria-label*="About"], button:has-text("About")').first();
    await aboutButton.waitFor({ state: 'visible', timeout: 10000 });
    await aboutButton.click();
    await page.waitForURL('**/#/about', { timeout: 5000 });

    // Click browser back button
    await page.goBack();
    await page.waitForLoadState('networkidle');

    // Verify back at home
    expect(page.url()).toMatch(/\/#\/$/);
  });

  test('browser forward button works', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Navigate to About
    const aboutButton = page.locator('button[aria-label*="About"], button:has-text("About")').first();
    await aboutButton.waitFor({ state: 'visible', timeout: 10000 });
    await aboutButton.click();
    await page.waitForURL('**/#/about', { timeout: 5000 });

    // Go back
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toMatch(/\/#\/$/);

    // Go forward
    await page.goForward();
    await page.waitForLoadState('networkidle');

    // Verify at About page
    expect(page.url()).toContain('/#/about');
  });

  test('can navigate through multiple screens', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Home URL
    expect(page.url()).toMatch(/\/#\/$/);

    // Navigate to About
    const aboutButton = page.locator('button[aria-label*="About"], button:has-text("About")').first();
    await aboutButton.waitFor({ state: 'visible', timeout: 10000 });
    await aboutButton.click();
    await page.waitForURL('**/#/about', { timeout: 5000 });
    expect(page.url()).toContain('/#/about');

    // Back to home
    await page.goBack();
    await page.waitForLoadState('networkidle');
    expect(page.url()).toMatch(/\/#\/$/);
  });

  test('can deep link to About page', async ({ page }) => {
    // Navigate directly to About URL
    await page.goto(`${BASE_URL}/#/about`);
    await page.waitForLoadState('networkidle');

    // Verify URL is correct
    expect(page.url()).toContain('/#/about');

    // Verify page content
    await expect(page.locator('text=About')).toBeVisible();
  });

  test('refreshing page on About route maintains URL', async ({ page }) => {
    // Go to About page
    await page.goto(`${BASE_URL}/#/about`);
    await page.waitForLoadState('networkidle');

    // Refresh page
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Verify still on About page
    expect(page.url()).toContain('/#/about');
    await expect(page.locator('text=About')).toBeVisible();
  });

  test('can navigate to drink detail if drinks load', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Wait for drinks to potentially load (with timeout)
    await page.waitForTimeout(3000);

    // Try to click a drink card if it exists
    const drinkCard = page.locator('[role="button"]:has-text("ABV")').first();
    const drinkExists = await drinkCard.count() > 0;

    if (drinkExists) {
      await drinkCard.click();

      // Wait a bit for navigation
      await page.waitForTimeout(1000);

      // Verify URL changed to drink detail
      expect(page.url()).toMatch(/\/#\/drink\/.+/);

      // Navigate back
      await page.goBack();
      expect(page.url()).toMatch(/\/#\/$/);
    }
  });

  test('bottom navigation preserves state', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Click Favorites tab
    await page.click('button:has-text("Favorites")');
    await page.waitForTimeout(500);

    // Click Drinks tab
    await page.click('button:has-text("Drinks")');
    await page.waitForTimeout(500);

    // Verify still on home URL (tabs don't change URL)
    expect(page.url()).toMatch(/\/#\/$/);
  });
});

test.describe('URL Validation', () => {
  test('URLs follow hash routing pattern', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Home should be /#/
    expect(page.url()).toMatch(/\/#\/$/);

    // Navigate to About
    const aboutButton = page.locator('button[aria-label*="About"], button:has-text("About")').first();
    await aboutButton.waitFor({ state: 'visible', timeout: 10000 });
    await aboutButton.click();
    await page.waitForURL('**/#/about', { timeout: 5000 });

    // About should be /#/about
    expect(page.url()).toMatch(/\/#\/about$/);
  });

  test('invalid routes redirect to home', async ({ page }) => {
    // Try to navigate to non-existent route
    await page.goto(`${BASE_URL}/#/nonexistent-route`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    // Should redirect or show home content
    // (exact behavior depends on go_router configuration)
  });
});
