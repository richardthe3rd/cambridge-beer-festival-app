import { describe, it, expect } from "vitest";
// Inlined at build time by vite — workerd itself has no filesystem access.
import wranglerToml from "../wrangler.toml?raw";

/**
 * Regression guard for the 2026-06-13 → 2026-08-10 deploy outage.
 *
 * `wrangler.toml` carried a placeholder `database_id` of all zeroes for a D1
 * database that was never provisioned. Cloudflare validates bindings when the
 * script is uploaded, so every `wrangler deploy` failed with error 10181 and
 * took the whole worker — CORS proxy included — with it.
 *
 * Nothing caught it: the vitest pool and `wrangler dev` use simulated local
 * resources that ignore the id, and `wrangler deploy --dry-run` (CI's
 * `validate-worker` job) exits 0 with a dangling binding — verified against
 * wrangler 4.98.0. The only signal was the real deploy on `main`, after merge.
 *
 * So this test asserts the one thing that is checkable offline: a binding
 * declared in `wrangler.toml` must not reference a placeholder resource. A
 * binding is either real or absent — comment it out until it is provisioned.
 */

/** Config lines that wrangler actually reads (comments stripped). */
const activeLines = wranglerToml
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line.length > 0 && !line.startsWith("#"));

/**
 * A resource id that names nothing: empty, the nil UUID (any zeros-and-dashes
 * spelling), or unfilled `<...>` template text.
 *
 * Deliberately narrow. Matching anything merely zero-ish would reject real ids
 * — roughly 1 in 256 random UUIDs both start and end with `0` — and the failure
 * would land precisely on whoever is provisioning D1 for the first time, which
 * is the worst possible moment for a spurious error.
 */
export function isPlaceholderId(value) {
  return /^(?:[0-]*|<.*>)$/.test(value);
}

describe("wrangler.toml — deployability", () => {
  it("recognises placeholder ids without rejecting real ones", () => {
    // The nil UUID is the exact value that broke production.
    expect(isPlaceholderId("00000000-0000-0000-0000-000000000000")).toBe(true);
    expect(isPlaceholderId("")).toBe(true);
    expect(isPlaceholderId("0")).toBe(true);
    expect(isPlaceholderId("<paste the id from `wrangler d1 create`>")).toBe(
      true,
    );

    // Real ids, including the awkward ones that start and/or end with 0.
    expect(isPlaceholderId("0f9e8d7c-6b5a-4321-8f0e-1d2c3b4a5960")).toBe(false);
    expect(isPlaceholderId("0a000000-0000-0000-0000-000000000000")).toBe(false);
    expect(isPlaceholderId("00000000-0000-0000-0000-00000000000a")).toBe(false);
    expect(isPlaceholderId("xxxxxxxx-1234-5678-9abc-def012345678")).toBe(false);
  });

  it("declares no binding pointing at a placeholder resource id", () => {
    const ids = activeLines
      .filter((line) => /^(database_id|id|bucket_name)\s*=/.test(line))
      .map((line) => ({
        line,
        value:
          line
            .split("=")[1]
            ?.trim()
            .replace(/^["']|["']$/g, "") ?? "",
      }));

    const placeholders = ids.filter(({ value }) => isPlaceholderId(value));

    expect(
      placeholders.map(({ line }) => line),
      "A binding references a placeholder/unprovisioned resource. This fails " +
        "`wrangler deploy` with error 10181 and takes the entire worker down, " +
        "including the proxy. Provision the resource and paste the real id, or " +
        "comment the binding out until it exists.",
    ).toEqual([]);
  });

  it("keeps the D1 binding and the review API's degraded mode in sync", () => {
    // If someone provisions D1 and uncomments the binding, this test fails and
    // points them at the STORAGE_UNCONFIGURED tests in reviews.test.js, which
    // assert the no-storage behaviour that is no longer the deployed reality.
    const hasD1Binding = activeLines.some((line) =>
      line.startsWith("[[d1_databases]]"),
    );

    expect(
      hasD1Binding,
      "wrangler.toml now declares a D1 binding, so /v1alpha no longer returns " +
        "503 STORAGE_UNCONFIGURED in production. Update the 'no D1 binding' " +
        "tests in test/reviews.test.js and the README's D1 section, then flip " +
        "this expectation to true.",
    ).toBe(false);
  });
});
