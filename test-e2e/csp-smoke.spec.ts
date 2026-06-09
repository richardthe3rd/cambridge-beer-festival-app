import { test, expect, Page } from "@playwright/test";

/**
 * CSP smoke tests — run against a *deployed* URL where Cloudflare Pages
 * applies the web/_headers file.  The local http-server used by test-e2e-web
 * never applies those headers, so CSP regressions are invisible there.
 *
 * In CI these tests run in the smoke-test-preview job (BASE_URL points to the
 * Cloudflare Pages preview).  Locally you can run them against a preview with:
 *
 *   BASE_URL=https://my-branch.staging-cambeerfestival.pages.dev \
 *     npx playwright test test-e2e/csp-smoke.spec.ts
 */

interface CspViolation {
  blockedURI: string;
  violatedDirective: string;
}

async function waitForFlutterReady(page: Page): Promise<void> {
  const timeout = process.env.CI ? 60_000 : 30_000;
  await page.waitForLoadState("networkidle", { timeout });
  await page.waitForSelector("flt-glass-pane, [flt-renderer-host]", {
    timeout,
    state: "attached",
  });
  // Let Flutter finish post-load work (font fetches, Firebase init, etc.)
  await page.waitForTimeout(4_000);
}

test.describe("CSP smoke", () => {
  test("no CSP violations on initial load", async ({ page }) => {
    // Register the listener before navigation so no early violations are missed.
    await page.addInitScript(() => {
      (window as any).__cspViolations = [] as CspViolation[];
      document.addEventListener("securitypolicyviolation", (ev) => {
        (window as any).__cspViolations.push({
          blockedURI: (ev as SecurityPolicyViolationEvent).blockedURI,
          violatedDirective: (ev as SecurityPolicyViolationEvent)
            .violatedDirective,
        });
      });
    });

    await page.goto("/");
    await waitForFlutterReady(page);

    const violations: CspViolation[] = await page.evaluate(
      () => (window as any).__cspViolations ?? [],
    );

    const summary = violations
      .map((v) => `  ${v.violatedDirective}: ${v.blockedURI}`)
      .join("\n");

    expect(
      violations,
      violations.length > 0
        ? `CSP violations detected — update web/_headers:\n${summary}`
        : "",
    ).toHaveLength(0);
  });

  test("Flutter app renders without blank screen", async ({ page }) => {
    await page.goto("/");
    await waitForFlutterReady(page);

    await expect(page).toHaveTitle(/Cambridge Beer Festival/i);

    const flutterHost = page
      .locator("flt-glass-pane, [flt-renderer-host]")
      .first();
    await expect(flutterHost).toBeAttached({ timeout: 10_000 });
  });
});
