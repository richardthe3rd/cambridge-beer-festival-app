import {
  cloudflareTest,
  readD1Migrations,
} from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  // Read the SQL migrations once at config time. They are exposed to tests as
  // the TEST_MIGRATIONS binding and applied to the simulated D1 in a setup file
  // (see test/apply-migrations.js), so no real database is needed.
  const migrations = await readD1Migrations("./migrations");

  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          // The RATINGS_DB binding is declared here rather than in
          // wrangler.toml: production has no D1 database provisioned yet, and a
          // binding pointing at a non-existent database fails `wrangler deploy`
          // outright. Declaring the simulated D1 here keeps the review-API
          // tests running against a real (local) database while the deployed
          // worker runs without the binding.
          d1Databases: ["RATINGS_DB"],
          bindings: { TEST_MIGRATIONS: migrations },
        },
      }),
    ],
    test: {
      setupFiles: ["./test/apply-migrations.js"],
    },
  };
});
