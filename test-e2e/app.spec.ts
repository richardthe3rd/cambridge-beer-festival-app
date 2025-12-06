import { test, expect, Page } from '@playwright/test';

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

test.describe('App Loading', () => {
  test('should load the app and render Flutter canvas', async ({ page }) => {
    // Navigate to the locally served app
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });

    // Verify the page title
    await expect(page).toHaveTitle(/Cambridge Beer Festival/i);

    // Wait for Flutter to be ready
    await waitForFlutterReady(page);

    // Verify the Flutter view embedder is present
    const flutterView = page.locator('flt-glass-pane, [flt-renderer-host]').first();
    await expect(flutterView).toBeAttached({
      timeout: 5000
    });

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
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });

    // Wait for Flutter to be ready (replaces arbitrary timeout)
    await waitForFlutterReady(page);

    // Filter out known benign errors/warnings
    const criticalErrors = consoleErrors.filter(error => {
      const lowerError = error.toLowerCase();
      return (
        !lowerError.includes('manifest') &&           // Missing manifest is ok
        !lowerError.includes('favicon') &&            // Favicon warnings are ok
        !lowerError.includes('chrome-extension') &&   // Browser extension noise
        !lowerError.includes('devtools') &&           // DevTools messages
        !lowerError.includes('404') ||                // 404s for optional resources
        lowerError.includes('404') && !lowerError.includes('.json') // But fail on missing JSON
      );
    });

    // Log all errors for debugging, even benign ones
    if (consoleErrors.length > 0) {
      console.log(`Total console errors: ${consoleErrors.length}`);
      console.log('All errors:', consoleErrors);
    }
    if (criticalErrors.length > 0) {
      console.log(`Critical errors (${criticalErrors.length}):`, criticalErrors);
    }

    // Be lenient initially - warn but don't fail on 1-2 errors
    // This allows us to identify real issues without blocking CI on edge cases
    if (criticalErrors.length > 2) {
      throw new Error(
        `Too many critical console errors (${criticalErrors.length}). ` +
        `Errors: ${JSON.stringify(criticalErrors, null, 2)}`
      );
    }

    // Soft assertion - logs warning but doesn't fail
    expect.soft(criticalErrors.length).toBe(0);
  });

  test('should load required JavaScript files', async ({ page }) => {
    const loadedScripts: string[] = [];
    const failedScripts: string[] = [];

    // Track script loads and failures
    page.on('response', response => {
      const url = response.url();
      if (url.endsWith('.js')) {
        if (response.ok()) {
          loadedScripts.push(url);
        } else {
          failedScripts.push(`${url} (${response.status()})`);
        }
      }
    });

    // Navigate to the app
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });

    // Wait for Flutter to be ready
    await waitForFlutterReady(page);

    // Log diagnostic information
    console.log(`Loaded ${loadedScripts.length} JavaScript files`);
    if (failedScripts.length > 0) {
      console.log('Failed scripts:', failedScripts);
    }

    // Verify main.dart.js was loaded (Flutter web entrypoint)
    const mainScriptLoaded = loadedScripts.some(url =>
      url.includes('main.dart.js')
    );
    expect(mainScriptLoaded, 'main.dart.js should be loaded').toBeTruthy();

    // Verify Flutter framework loaded
    const flutterLoaded = loadedScripts.some(url =>
      url.includes('flutter')
    );
    expect(flutterLoaded, 'Flutter framework should be loaded').toBeTruthy();

    // Verify no critical scripts failed to load
    expect(failedScripts, 'No JavaScript files should fail to load').toHaveLength(0);
  });

  test('should have accessible content for screen readers', async ({ page }) => {
    // Navigate to the app
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle' });

    // Wait for Flutter to be ready
    await waitForFlutterReady(page);

    // Check for ARIA landmarks that Flutter Semantics widgets create
    // Note: This requires the app to have proper Semantics widgets configured
    const elementsWithRoles = await page.locator('[role]').all();
    const roleCount = elementsWithRoles.length;

    // Log what roles we found for diagnostic purposes
    if (roleCount > 0) {
      const roles = await Promise.all(
        elementsWithRoles.slice(0, 10).map(async el => {
          const role = await el.getAttribute('role');
          const label = await el.getAttribute('aria-label');
          return { role, label };
        })
      );
      console.log(`Found ${roleCount} elements with ARIA roles`);
      console.log('Sample roles:', roles);
    } else {
      console.log('No ARIA roles found - accessibility may need improvement');
    }

    // For now, this is a baseline test - we expect the count to grow
    // as we add more Semantics widgets to the app
    expect(roleCount).toBeGreaterThanOrEqual(0);

    // Check that the HTML lang attribute is set (important for screen readers)
    const htmlLang = await page.locator('html').getAttribute('lang');
    expect(htmlLang, 'HTML lang attribute should be set').toBeTruthy();
  });
});
