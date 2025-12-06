import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for E2E web tests
 *
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './test-e2e',

  // Maximum time one test can run
  timeout: 30 * 1000,

  // Maximum time to wait for expect() assertions
  expect: {
    timeout: 10 * 1000,
  },

  // Test execution settings
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  // Reporter configuration - use multiple reporters in CI
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'on-failure' }]],

  // Shared settings for all projects
  use: {
    // Base URL for the app
    baseURL: 'http://127.0.0.1:8080',

    // Collect trace on failure for debugging
    trace: 'on-first-retry',

    // Take screenshots on failure
    screenshot: 'only-on-failure',

    // Record video on first retry (helps debug flaky tests)
    video: 'retain-on-failure',

    // Navigation timeout
    navigationTimeout: 15 * 1000,

    // Action timeout (clicks, fills, etc.)
    actionTimeout: 10 * 1000,
  },

  // Test projects for different browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // Uncomment to test on additional browsers
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],

  // Note: webServer is NOT used here because CI needs more control
  // over the http-server lifecycle. Instead:
  // 1. CI starts http-server in the background
  // 2. Tests run
  // 3. CI stops http-server
  //
  // For local development, start the server manually:
  // npm run serve:web
});
