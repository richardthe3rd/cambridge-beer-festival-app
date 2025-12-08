#!/usr/bin/env node
import { chromium } from '@playwright/test';
import { parseArgs } from 'node:util';
import { readFileSync } from 'node:fs';

// Parse command-line arguments
const { values } = parseArgs({
  options: {
    config: {
      type: 'string',
      short: 'c',
      default: 'screenshots.config.json'
    },
    baseUrl: {
      type: 'string',
      short: 'b',
      default: 'http://localhost:8080'
    },
    outputDir: {
      type: 'string',
      short: 'o',
      default: 'screenshots'
    },
    wait: {
      type: 'string',
      short: 'w',
      default: '30000'
    },
    help: {
      type: 'boolean',
      short: 'h'
    }
  }
});

if (values.help) {
  console.log(`
Usage: node scripts/screenshot-batch.mjs [options]

Options:
  -c, --config <path>       Config file with URLs (default: screenshots.config.json)
  -b, --baseUrl <url>       Base URL (default: http://localhost:8080)
  -o, --outputDir <dir>     Output directory (default: screenshots)
  -w, --wait <ms>           Wait time for Flutter init (default: 30000)
  -h, --help                Show this help message

Config file format (JSON):
[
  { "path": "/", "name": "home" },
  { "path": "/brewery/123", "name": "brewery-detail" },
  { "path": "/drink/456", "name": "drink-detail" }
]

Examples:
  node scripts/screenshot-batch.mjs
  node scripts/screenshot-batch.mjs -c my-urls.json -b http://localhost:3000
`);
  process.exit(0);
}

async function screenshotBatch(config) {
  const { baseUrl, outputDir, wait: maxWaitTime } = config;

  console.log('Starting batch screenshot capture...');
  console.log(`Base URL: ${baseUrl}`);
  console.log(`Output directory: ${outputDir}`);
  console.log('\n');

  // Launch browser once
  console.log('Launching browser...');
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  const results = [];
  let flutterInitialized = false;

  // Listen to console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text(),
      location: msg.location()
    });
  });

  // Listen to page errors
  page.on('pageerror', error => {
    consoleMessages.push({
      type: 'pageerror',
      text: error.message,
      stack: error.stack
    });
  });

  for (const [index, urlConfig] of config.urls.entries()) {
    const url = `${baseUrl}${urlConfig.path}`;
    const screenshotPath = `${outputDir}/${urlConfig.name}.png`;

    console.log(`\n[${index + 1}/${config.urls.length}] ${urlConfig.name}`);
    console.log(`  URL: ${url}`);

    // Clear console messages for this URL
    consoleMessages.length = 0;

    try {
      // Navigate to URL
      await page.goto(url, {
        waitUntil: 'networkidle',
        timeout: 60000
      });

      // Wait for Flutter to initialize (only needed on first page)
      if (!flutterInitialized) {
        console.log('  Waiting for Flutter to initialize...');
        const startTime = Date.now();

        while (!flutterInitialized && (Date.now() - startTime) < maxWaitTime) {
          // Check for Flutter initialization messages
          const hasAppStart = consoleMessages.some(msg =>
            msg.text.includes('Starting application from main method') ||
            msg.text.includes('Using MaterialApp configuration')
          );

          if (hasAppStart) {
            flutterInitialized = true;
            console.log('  ✓ Flutter initialized!');
            break;
          }

          // Check for Flutter content in DOM
          const hasFlutterContent = await page.evaluate(() => {
            return document.body &&
                   document.body.children.length > 0 &&
                   document.querySelector('flt-glass-pane, flutter-view, [flt-renderer]') !== null;
          });

          if (hasFlutterContent) {
            flutterInitialized = true;
            console.log('  ✓ Flutter content detected!');
            break;
          }

          await page.waitForTimeout(500);
        }

        if (!flutterInitialized) {
          console.log('  ⚠ Flutter may not have fully initialized');
        }

        // Extra wait for initial render
        await page.waitForTimeout(2000);
      } else {
        // For subsequent pages, just wait for content to update
        await page.waitForTimeout(2000);
      }

      // Get page title
      const title = await page.title();
      console.log(`  Title: ${title}`);

      // Take screenshot
      await page.screenshot({
        path: screenshotPath,
        fullPage: true
      });
      console.log(`  ✓ Screenshot saved: ${screenshotPath}`);

      // Count errors/warnings
      const errors = consoleMessages.filter(m => m.type === 'error' || m.type === 'pageerror');
      const warnings = consoleMessages.filter(m => m.type === 'warning');

      console.log(`  Console: ${errors.length} errors, ${warnings.length} warnings`);

      results.push({
        name: urlConfig.name,
        url,
        success: true,
        title,
        errors: errors.length,
        warnings: warnings.length
      });

    } catch (error) {
      console.error(`  ✗ Error: ${error.message}`);
      results.push({
        name: urlConfig.name,
        url,
        success: false,
        error: error.message
      });
    }
  }

  await browser.close();

  // Print summary
  console.log('\n\n=== SUMMARY ===');
  console.log(`Total pages: ${results.length}`);
  console.log(`Successful: ${results.filter(r => r.success).length}`);
  console.log(`Failed: ${results.filter(r => !r.success).length}`);

  console.log('\n=== RESULTS ===');
  results.forEach((result, idx) => {
    const status = result.success ? '✓' : '✗';
    console.log(`${status} ${result.name}`);
    if (result.success) {
      console.log(`    ${result.url}`);
      console.log(`    Errors: ${result.errors}, Warnings: ${result.warnings}`);
    } else {
      console.log(`    Error: ${result.error}`);
    }
  });

  // Exit with error if any failed
  const hasErrors = results.some(r => !r.success || r.errors > 0);
  process.exit(hasErrors ? 1 : 0);
}

// Load config file
try {
  const configData = readFileSync(values.config, 'utf8');
  const urls = JSON.parse(configData);

  const config = {
    baseUrl: values.baseUrl,
    outputDir: values.outputDir,
    wait: parseInt(values.wait),
    urls
  };

  screenshotBatch(config);
} catch (error) {
  console.error(`Error loading config file: ${error.message}`);
  console.error(`\nMake sure ${values.config} exists and contains valid JSON.`);
  console.error('\nExample config file:');
  console.error(`[
  { "path": "/", "name": "home" },
  { "path": "/favorites", "name": "favorites" }
]`);
  process.exit(1);
}
