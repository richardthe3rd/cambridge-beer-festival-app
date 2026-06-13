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
          bindings: { TEST_MIGRATIONS: migrations },
        },
      }),
    ],
    test: {
      setupFiles: ["./test/apply-migrations.js"],
    },
  };
});
