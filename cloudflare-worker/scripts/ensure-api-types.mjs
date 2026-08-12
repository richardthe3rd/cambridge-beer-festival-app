#!/usr/bin/env node
/**
 * npm `pretypecheck` guard: make sure src/api-types.ts exists before tsc runs.
 *
 * reviews.ts imports ./src/api-types, which is generated from the proto
 * contract (proto -> docs/code/api/openapi/openapi.yaml -> src/api-types.ts)
 * and gitignored. On a fresh checkout nothing has produced it yet, so
 * `npm run typecheck` used to fail with a bare "Cannot find module
 * './src/api-types'" that looks like a broken checkout (#545).
 *
 * This script runs the mise task that generates it. That task now depends on
 * proto:generate, so the whole chain bootstraps from the proto sources.
 *
 * Generation needs `buf`, which is a dev-env tool fetched from GitHub
 * releases; if that is unavailable (offline, or the sandbox 403 documented in
 * mise.dev.toml) we exit non-zero with the command to run by hand rather than
 * letting tsc report a confusing module-resolution error.
 */

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const workerDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = resolve(workerDir, "..");
const apiTypes = resolve(workerDir, "src/api-types.ts");
const task = "proto:clients:types";

if (existsSync(apiTypes)) process.exit(0);

// proto:* tasks live in mise.dev.toml, so the `dev` env has to be selected.
// On Claude Code Web .miserc.toml already selects it (plus claude-code-web);
// setting MISE_ENV there would override that file and drop the Node pin, so
// only set it when nothing has selected an env already.
const selectDevEnv =
  !process.env.MISE_ENV && process.env.CLAUDE_CODE_REMOTE !== "true";
const env = { ...process.env };
if (selectDevEnv) env.MISE_ENV = "dev";

console.log(`api-types.ts missing — running \`mise run ${task}\`...`);
const result = spawnSync("./bin/mise", ["run", task], {
  cwd: repoRoot,
  env,
  stdio: "inherit",
});

if (result.status !== 0 || !existsSync(apiTypes)) {
  // Built from the boolean above, never by interpolating an environment
  // value into the message — that reads to CodeQL as clear-text logging of
  // the process environment.
  const prefix = selectDevEnv ? "MISE_ENV=dev " : "";
  console.error(
    `\nCould not generate cloudflare-worker/src/api-types.ts.\n` +
      `Generate it from the proto contract by running, from the repo root:\n` +
      `  ${prefix}./bin/mise run ${task}\n` +
      `That needs \`buf\` (see mise.dev.toml for the install caveats).\n`,
  );
  process.exit(1);
}
