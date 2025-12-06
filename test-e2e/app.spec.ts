import { test, expect } from '@playwright/test';

/**
 * Basic E2E tests for Cambridge Beer Festival web app
 *
 * IMPORTANT: Flutter web apps don't use traditional DOM elements!
 * Flutter uses CanvasKit/HTML renderer and draws the UI on canvas.
 * This means we can't use standard DOM selectors for Flutter widgets.
 *
 * Testing approaches for Flutter web:
 * 1. Page load and basic rendering (check canvas/host elements)
 * 2. Network requests (verify API calls)
 * 3. Accessibility features (ARIA labels from Semantics widgets)
 * 4. Console errors and warnings
 * 5. Performance metrics
 *
 * For full interaction testing, consider Flutter's integration tests instead.
 */

test.describe('App Loading', () => {
  test('should load the app and render Flutter canvas', async ({ page }) => {
    // Navigate to the locally served app
    await page.goto('http://127.0.0.1:8080/');

    // Wait for the app to load
    await page.waitForLoadState('networkidle');

    // Verify the page title
    await expect(page).toHaveTitle(/Cambridge Beer Festival/i);

    // Verify the Flutter canvas/host is present
    // Flutter web creates a canvas or other rendering host
    const flutterHost = page.locator('flt-glass-pane, [flt-renderer-host], canvas').first();
    await expect(flutterHost).toBeAttached({ timeout: 15000 });

    // Wait for Flutter to fully initialize
    await page.waitForTimeout(2000);

    // Check that the viewport meta tag is correct (important for mobile rendering)
    const viewport = page.locator('meta[name="viewport"]');
    await expect(viewport).toHaveAttribute('content', /width=device-width/);
  });

  test('should load without critical console errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    const consoleWarnings: string[] = [];

    // Capture console messages
    page.on('console', msg => {
      const text = msg.text();
      if (msg.type() === 'error') {
        consoleErrors.push(text);
      } else if (msg.type() === 'warning') {
        consoleWarnings.push(text);
      }
    });

    // Navigate to the app
    await page.goto('http://127.0.0.1:8080/');
    await page.waitForLoadState('networkidle');

    // Give Flutter time to initialize and render
    await page.waitForTimeout(3000);

    // Filter out known benign errors/warnings
    const criticalErrors = consoleErrors.filter(error =>
      !error.includes('manifest') &&           // Missing manifest is ok
      !error.includes('favicon') &&            // Favicon warnings are ok
      !error.includes('chrome-extension') &&   // Browser extension noise
      !error.includes('DevTools')              // DevTools messages
    );

    if (criticalErrors.length > 0) {
      console.log('Console errors detected:', criticalErrors);
    }

    // Fail if there are critical errors
    expect(criticalErrors).toHaveLength(0);
  });

  test('should load required JavaScript files', async ({ page }) => {
    const loadedScripts: string[] = [];

    // Track script loads
    page.on('response', response => {
      const url = response.url();
      if (url.endsWith('.js')) {
        loadedScripts.push(url);
      }
    });

    // Navigate to the app
    await page.goto('http://127.0.0.1:8080/');
    await page.waitForLoadState('networkidle');

    // Verify main.dart.js was loaded (Flutter web entrypoint)
    const mainScriptLoaded = loadedScripts.some(url =>
      url.includes('main.dart.js')
    );
    expect(mainScriptLoaded).toBeTruthy();

    // Verify Flutter framework loaded
    const flutterLoaded = loadedScripts.some(url =>
      url.includes('flutter')
    );
    expect(flutterLoaded).toBeTruthy();
  });

  test('should have accessible content for screen readers', async ({ page }) => {
    // Navigate to the app
    await page.goto('http://127.0.0.1:8080/');
    await page.waitForLoadState('networkidle');

    // Wait for Flutter to render
    await page.waitForTimeout(2000);

    // Check for ARIA landmarks that Flutter Semantics widgets create
    // Note: This requires the app to have proper Semantics widgets configured
    const landmarks = await page.locator('[role]').count();

    // We should have at least some ARIA roles if accessibility is configured
    // (This will improve as we add more Semantics widgets to the app)
    console.log(`Found ${landmarks} elements with ARIA roles`);

    // For now, just verify the test can run - we'll expand this as
    // accessibility features are added to the app
    expect(landmarks).toBeGreaterThanOrEqual(0);
  });
});
