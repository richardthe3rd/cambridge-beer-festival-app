import { applyD1Migrations, env } from "cloudflare:test";

// Apply the reviews schema to the per-test simulated D1 before any test runs.
// `TEST_MIGRATIONS` is provided by vitest.config.js via readD1Migrations().
await applyD1Migrations(env.RATINGS_DB, env.TEST_MIGRATIONS);
