#!/usr/bin/env node
import { chromium } from '@playwright/test';
import { parseArgs } from 'node:util';

// Parse command-line arguments
const { values } = parseArgs({
  options: {
    url: {
      type: 'string',
      short: 'u',
      default: 'http://localhost:8080'
    },
    screenshot: {
      type: 'string',
      short: 's',
      default: 'screenshot.png'
    },
    timeout: {
      type: 'string',
      short: 't',
      default: '60000'
    },
    wait: {
      type: 'string',
      short: 'w',
      default: '5000'
    },
    help: {
      type: 'boolean',
      short: 'h'
    }
  }
});

if (values.help) {
  console.log(`
Usage: node scripts/check-page.mjs [options]

Options:
  -u, --url <url>           URL to check (default: http://localhost:8080)
  -s, --screenshot <path>   Screenshot output path (default: screenshot.png)
  -t, --timeout <ms>        Page load timeout in ms (default: 60000)
  -w, --wait <ms>           Wait time after load in ms (default: 5000)
  -h, --help                Show this help message

Examples:
  node scripts/check-page.mjs
  node scripts/check-page.mjs -u https://example.com
  node scripts/check-page.mjs -u http://localhost:8080/brewery/123 -s brewery.png
  node scripts/check-page.mjs --url https://tunnel.cambeerfestival.app --wait 10000
`);
  process.exit(0);
}

async function checkPage(url, options = {}) {
  const {
    screenshotPath = 'screenshot.png',
    timeout = 60000,
    waitTime = 5000
  } = options;

  console.log('Launching browser...');
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  const consoleMessages = [];
  const errors = [];
  const warnings = [];

  // Listen to all console messages
  page.on('console', msg => {
    const entry = {
      type: msg.type(),
      text: msg.text(),
      location: msg.location()
    };

    consoleMessages.push(entry);

    if (msg.type() === 'error') {
      errors.push(entry);
    } else if (msg.type() === 'warning') {
      warnings.push(entry);
    }
  });

  // Listen to page errors
  page.on('pageerror', error => {
    errors.push({
      type: 'pageerror',
      text: error.message,
      stack: error.stack
    });
  });

  console.log(`Navigating to ${url}...`);
  try {
    await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: parseInt(timeout)
    });

    // Wait for Flutter app to initialize by watching for key console messages
    console.log('Waiting for Flutter app to initialize...');
    let flutterInitialized = false;
    const startTime = Date.now();
    const maxWaitTime = parseInt(waitTime);

    while (!flutterInitialized && (Date.now() - startTime) < maxWaitTime) {
      // Check if we've seen Flutter initialization messages
      const hasAppStart = consoleMessages.some(msg =>
        msg.text.includes('Starting application from main method') ||
        msg.text.includes('Using MaterialApp configuration')
      );

      if (hasAppStart) {
        flutterInitialized = true;
        console.log('Flutter app initialized!');
        break;
      }

      // Also check if Flutter content has rendered in the DOM
      try {
        const hasFlutterContent = await page.evaluate(() => {
          const body = document.body;
          return body && body.children.length > 0 && body.querySelector('flt-glass-pane, flutter-view, [flt-renderer]');
        });

        if (hasFlutterContent) {
          flutterInitialized = true;
          console.log('Flutter content detected in DOM!');
          break;
        }
      } catch (e) {
        // Continue waiting
      }

      await page.waitForTimeout(500);
    }

    if (!flutterInitialized) {
      console.log(`Warning: Flutter app may not have fully initialized after ${maxWaitTime}ms`);
    }

    // Wait a bit more for rendering to complete
    console.log('Waiting for final render...');
    await page.waitForTimeout(2000);

    // Get page info
    const title = await page.title();
    console.log(`Page title: ${title}`);

    // Take screenshot
    console.log(`Taking screenshot: ${screenshotPath}`);
    await page.screenshot({ path: screenshotPath, fullPage: true });

  } catch (error) {
    console.error(`Error during navigation: ${error.message}`);
  }

  await browser.close();

  // Print summary
  console.log('\n=== Console Messages Summary ===');
  console.log(`URL: ${url}`);
  console.log(`Total messages: ${consoleMessages.length}`);
  console.log(`Errors: ${errors.length}`);
  console.log(`Warnings: ${warnings.length}`);

  if (errors.length > 0) {
    console.log('\n=== ERRORS ===');
    errors.forEach((err, idx) => {
      console.log(`\n${idx + 1}. [${err.type}] ${err.text}`);
      if (err.location) {
        console.log(`   Location: ${err.location.url}:${err.location.lineNumber}:${err.location.columnNumber}`);
      }
      if (err.stack) {
        console.log(`   Stack: ${err.stack}`);
      }
    });
  }

  if (warnings.length > 0) {
    console.log('\n=== WARNINGS ===');
    warnings.forEach((warn, idx) => {
      console.log(`\n${idx + 1}. ${warn.text}`);
      if (warn.location) {
        console.log(`   Location: ${warn.location.url}:${warn.location.lineNumber}:${warn.location.columnNumber}`);
      }
    });
  }

  if (consoleMessages.length > 0 && (errors.length > 0 || warnings.length > 0)) {
    console.log('\n=== ALL CONSOLE MESSAGES ===');
    consoleMessages.forEach((msg, idx) => {
      console.log(`${idx + 1}. [${msg.type}] ${msg.text}`);
    });
  }

  console.log(`\n✅ Check complete. Screenshot saved to: ${screenshotPath}`);

  return {
    total: consoleMessages.length,
    errors: errors.length,
    warnings: warnings.length,
    messages: consoleMessages
  };
}

// Run the check
checkPage(values.url, {
  screenshotPath: values.screenshot,
  timeout: values.timeout,
  waitTime: values.wait
})
  .then(result => {
    process.exit(result.errors > 0 ? 1 : 0);
  })
  .catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
