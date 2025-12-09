import { chromium, Page, Browser } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';

/**
 * Screenshot capture script for CI
 *
 * Captures screenshots of main app screens for visual PR reviews.
 * NOT a test - this is a script that runs in CI to generate screenshots.
 *
 * Usage:
 *   npx tsx test-e2e/screenshots.ts <output-dir>
 */

interface ScreenshotConfig {
  name: string;
  url: string;
  description: string;
  /** Wait extra time for content to load (in ms) */
  extraWait?: number;
}

// Mobile viewport (iPhone 14 Pro size)
const VIEWPORT = {
  width: 390,
  height: 844,
};

// Screens to capture
const SCREENSHOTS: ScreenshotConfig[] = [
  {
    name: '01-drinks-list',
    url: '/',
    description: 'Drinks List (Home)',
    extraWait: 2000, // Wait for API data to load
  },
  {
    name: '02-favorites',
    url: '/favorites',
    description: 'Favorites',
    extraWait: 1000,
  },
  {
    name: '03-producers',
    url: '/producers',
    description: 'Producers List',
    extraWait: 2000,
  },
  {
    name: '04-festival-info',
    url: '/about',
    description: 'Festival Info',
    extraWait: 1000,
  },
  {
    name: '05-drink-detail',
    url: '/drink/example', // Will show "not found" or sample if available
    description: 'Drink Detail Screen',
    extraWait: 1500,
  },
  {
    name: '06-brewery-detail',
    url: '/brewery/example', // Will show "not found" or sample if available
    description: 'Brewery Detail Screen',
    extraWait: 1500,
  },
];

/**
 * Wait for Flutter app to be ready
 */
async function waitForFlutterReady(page: Page, timeout = 20000): Promise<void> {
  await page.waitForLoadState('networkidle');

  // Wait for Flutter's view embedder
  await page.waitForSelector('flt-glass-pane, [flt-renderer-host]', {
    timeout,
    state: 'attached',
  });

  // Short delay for framework initialization
  await page.waitForTimeout(1000);
}

/**
 * Capture a single screenshot
 */
async function captureScreenshot(
  page: Page,
  config: ScreenshotConfig,
  outputDir: string,
  baseUrl: string
): Promise<void> {
  const fullUrl = `${baseUrl}${config.url}`;
  console.log(`📸 Capturing: ${config.description}`);
  console.log(`   URL: ${fullUrl}`);

  try {
    // Navigate to the page
    await page.goto(fullUrl, { waitUntil: 'networkidle', timeout: 30000 });

    // Wait for Flutter to be ready
    await waitForFlutterReady(page);

    // Extra wait if configured (for API data, animations, etc.)
    if (config.extraWait) {
      console.log(`   Waiting ${config.extraWait}ms for content...`);
      await page.waitForTimeout(config.extraWait);
    }

    // Take screenshot
    const screenshotPath = path.join(outputDir, `${config.name}.png`);
    await page.screenshot({
      path: screenshotPath,
      fullPage: false, // Only visible viewport
    });

    console.log(`   ✅ Saved: ${screenshotPath}`);
  } catch (error) {
    console.error(`   ❌ Failed to capture ${config.name}:`, error);
    // Don't throw - continue with other screenshots
  }
}

/**
 * Main screenshot capture function
 */
async function captureAllScreenshots(
  outputDir: string,
  baseUrl: string = 'http://127.0.0.1:8080'
): Promise<void> {
  console.log('🚀 Starting screenshot capture');
  console.log(`   Output directory: ${outputDir}`);
  console.log(`   Base URL: ${baseUrl}`);
  console.log(`   Viewport: ${VIEWPORT.width}x${VIEWPORT.height}`);
  console.log(`   Total screenshots: ${SCREENSHOTS.length}\n`);

  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Launch browser
  const browser: Browser = await chromium.launch({
    headless: true,
  });

  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 2, // Retina display for crisp screenshots
  });

  const page = await context.newPage();

  try {
    // Capture all screenshots sequentially
    for (const config of SCREENSHOTS) {
      await captureScreenshot(page, config, outputDir, baseUrl);
    }

    console.log('\n✨ All screenshots captured successfully!');
  } catch (error) {
    console.error('\n❌ Screenshot capture failed:', error);
    throw error;
  } finally {
    await browser.close();
  }
}

// CLI execution
if (require.main === module) {
  const outputDir = process.argv[2];
  const baseUrl = process.argv[3] || 'http://127.0.0.1:8080';

  if (!outputDir) {
    console.error('Usage: npx tsx test-e2e/screenshots.ts <output-dir> [base-url]');
    process.exit(1);
  }

  captureAllScreenshots(outputDir, baseUrl)
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export { captureAllScreenshots, SCREENSHOTS };
