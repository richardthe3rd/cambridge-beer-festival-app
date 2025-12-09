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

interface Producer {
  id: string;
  name: string;
  location?: string;
  desc?: string;
  products?: Product[];
}

interface Product {
  id: string;
  name: string;
  abv?: string | number;
  style?: string;
  desc?: string;
}

// Mobile viewport (iPhone 14 Pro size)
const VIEWPORT = {
  width: 390,
  height: 844,
};

// Cambridge Beer Festival API
const API_BASE_URL = 'https://cbf-data-proxy.richard-alcock.workers.dev';
const FESTIVAL_ID = '2024-may'; // Default festival

/**
 * Fetch festival data to get real drink and brewery IDs
 */
async function fetchFestivalData(): Promise<{ drinkId: string; breweryId: string } | null> {
  try {
    console.log('🔍 Fetching festival data from API...');
    const response = await fetch(`${API_BASE_URL}/${FESTIVAL_ID}/beer.json`);

    if (!response.ok) {
      console.warn(`   ⚠️  API returned ${response.status}, will skip detail screens`);
      return null;
    }

    const data: Producer[] = await response.json();

    if (!data || data.length === 0) {
      console.warn('   ⚠️  No data returned from API, will skip detail screens');
      return null;
    }

    // Find first producer with products
    const producerWithProducts = data.find(p => p.products && p.products.length > 0);

    if (!producerWithProducts || !producerWithProducts.products) {
      console.warn('   ⚠️  No producers with products found, will skip detail screens');
      return null;
    }

    const firstProduct = producerWithProducts.products[0];
    const breweryName = producerWithProducts.name;

    // Use actual IDs from the API
    const drinkId = firstProduct.id;
    const breweryId = producerWithProducts.id;

    console.log(`   ✅ Found drink: "${firstProduct.name}" (ID: ${drinkId})`);
    console.log(`   📝 Found brewery: "${breweryName}" (ID: ${breweryId})`);

    return { drinkId, breweryId };
  } catch (error) {
    console.error('   ❌ Failed to fetch festival data:', error);
    return null;
  }
}

/**
 * Get screenshot configurations (with optional dynamic IDs)
 */
async function getScreenshotConfigs(): Promise<ScreenshotConfig[]> {
  const baseScreenshots: ScreenshotConfig[] = [
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
  ];

  // Try to get real IDs from API
  const festivalData = await fetchFestivalData();

  if (festivalData) {
    // Add detail screens with real IDs
    baseScreenshots.push(
      {
        name: '05-drink-detail',
        url: `/drink/${festivalData.drinkId}`,
        description: 'Drink Detail Screen',
        extraWait: 2000,
      },
      {
        name: '06-brewery-detail',
        url: `/brewery/${festivalData.breweryId}`,
        description: 'Brewery Detail Screen',
        extraWait: 2000,
      }
    );
  } else {
    console.log('   ℹ️  Skipping detail screens (no API data available)');
  }

  return baseScreenshots;
}

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
  console.log(`   Viewport: ${VIEWPORT.width}x${VIEWPORT.height}\n`);

  // Get screenshot configurations (includes API call for real IDs)
  const screenshots = await getScreenshotConfigs();

  console.log(`   Total screenshots: ${screenshots.length}\n`);

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
    for (const config of screenshots) {
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

export { captureAllScreenshots, getScreenshotConfigs };
