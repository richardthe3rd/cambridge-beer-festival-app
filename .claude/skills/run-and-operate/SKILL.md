---
name: run-and-operate
description: Run, build, serve, and deploy the Cambridge Beer Festival app. Load when asked to start the dev server, build for web/Android, run e2e tests locally, provision Cloudflare D1, update festival data, cut a release, or figure out "where does this land / what URL is this on / which workflow deploys X". Triggers — "run the app", "build for web", "start the dev server", "serve the release build", "build an APK/AAB", "run e2e tests", "provision D1", "the database_id is a placeholder", "update festivals.json", "cut a release", "tag a release", "what does release-pr.yml do", "why didn't CI run on the release PR", "where's the staging URL", "check the worker health endpoint", "what lands in build/web". Provides the run matrix, the deployment topology table, the release-train runbook with its traps, the D1 provisioning runbook, the festival-data-update flow, output locations, and honest limits on what an agent can check operationally (no dashboard access).
---

# Run and Operate

This skill covers **doing** things: running the app, building artifacts,
deploying them, and knowing where the results land. It assumes the toolchain
is already installed (see skill `build-and-env` if `./bin/mise` itself is
broken) and that you've already cleared change control for whatever you're
about to ship (see skill `change-control` for gates/policy — this skill does
not repeat them).

All commands below were verified against `mise.toml`, `mise.dev.toml`,
`mise-tasks/**`, and `.github/workflows/**` on 2026-07-02. Re-run the checks
in "Provenance and maintenance" before trusting a command that looks stale.

---

## 1. Run matrix

| Goal | Command | Notes |
|---|---|---|
| Dev server | `MISE_ENV=dev ./bin/mise run dev` | `flutter run -d web-server --web-port 8080 --pid-file flutter-dev.pid` (`mise-tasks/dev.sh`). Serves `http://localhost:8080`. **On Claude Code Web, omit `MISE_ENV=dev`** — `.miserc.toml` already selects `claude-code-web,dev` when `CLAUDE_CODE_REMOTE=true`; an explicit `MISE_ENV` overrides that file and drops the web env. |
| Local web build (for e2e) | `MISE_ENV=dev ./bin/mise run build:web` | `flutter build web --release --base-href "/"` (`mise-tasks/build/web.sh`). No dart-defines. Output: `build/web/`. |
| Production-shaped web build | `MISE_ENV=dev ./bin/mise run build:web:prod` | Runs `scripts/get_version_info.sh export` first, then `flutter build web --release --base-href "/"` with `--dart-define=GIT_TAG=...`, `GIT_COMMIT`, `GIT_BRANCH`, `BUILD_VERSION`, `BUILD_TIME` (`mise-tasks/build/web/prod.sh`). **Does NOT pass `--source-maps`** — CI's `build-web` job does, then strips the `.map` into a separate artifact. If you need a crash-decodable build locally, run the `flutter build web` command by hand with `--source-maps` added (see skill `diagnostics-and-tooling` for the full decode workflow) — do not expect `build:web:prod` to produce one. |
| Serve a release build locally | `MISE_ENV=dev ./bin/mise run serve:release` | `npx http-server build/web -p 8080 --proxy http://localhost:8080?` (`mise-tasks/serve/release.sh`). The `--proxy` flag is the SPA-fallback trick: any path http-server can't find as a static file gets re-requested through the proxy, which serves `index.html` — this is what makes deep links like `/cbf2026/drink/beer/123` work when refreshed against a static file server. Errors loudly if `build/web` doesn't exist yet — build first. |
| Android debug/release build (local) | `flutter build apk --release` / `flutter build appbundle --release` | **No mise task wraps this** (confirmed: `./bin/mise tasks ls` has no `build:android*` entry) — these are the one place AGENTS.md's "never run raw `flutter`" rule doesn't apply, because there is nothing to wrap. Debug-signed locally (no `android/key.properties`) unless you've set one up per `docs/tooling/android-release.md`. Outputs: `build/app/outputs/flutter-apk/app-release.apk`, `build/app/outputs/bundle/release/app-release.aab`. |
| e2e recipe (local, once per machine) | see below | |

### e2e recipe

```bash
# 1. One-time per machine: installs npm deps + Playwright chromium + system deps (may sudo-prompt)
MISE_ENV=dev ./bin/mise run setup:playwright

# 2. Build the app (plain build is fine — e2e doesn't need dart-defines)
MISE_ENV=dev ./bin/mise run build:web

# 3. Serve it (separate terminal, or background)
MISE_ENV=dev ./bin/mise run serve:release
# — or, matching CI exactly: npm run serve:web (binds 127.0.0.1, adds -c-1 no-cache)

# 4. Run the suite
MISE_ENV=dev ./bin/mise run test:e2e          # headless
MISE_ENV=dev ./bin/mise run test:e2e:headed   # visible browser
MISE_ENV=dev ./bin/mise run test:e2e:ui       # Playwright UI mode
```

On Claude Code Web, drop `MISE_ENV=dev` from all of the above (same auto-env
rule as the dev server).

`playwright.config.ts` (repo root) has **no `webServer` block on purpose** —
comment in the file explains CI needs manual control over the http-server
lifecycle (start in background, run tests, kill it). `baseURL` defaults to
`http://127.0.0.1:8080`, override with `BASE_URL` env var to point at a
deployed preview instead (this is how `smoke-test-preview` in CI runs
`csp-smoke.spec.ts` against a live Cloudflare Pages URL — that test is
**invisible** against a local server because `web/_headers` CSP rules are a
Cloudflare Pages feature, not something a plain static server applies).

Suites in `test-e2e/`: `app.spec.ts` (load smoke, console-error budget),
`routing.spec.ts` (URL mechanics, deep links, redirects), `csp-smoke.spec.ts`
(zero CSP violations — deployed-URL only, see above).

---

## 2. Deployment topology

| What | Where | Trigger | Workflow | Cloudflare project / branch |
|---|---|---|---|---|
| Staging web | `staging.cambeerfestival.app` | push to `main` (app/functions changed) | `ci.yml` job `deploy-web-preview` | `staging-cambeerfestival`, branch `main` |
| PR preview web | `<head-ref>.staging-cambeerfestival.pages.dev` + PR comment | pull_request (app/functions changed) | `ci.yml` job `deploy-web-preview` | `staging-cambeerfestival`, branch = PR head ref |
| Production web | `cambeerfestival.app` | `workflow_dispatch` (called by `release.yml` after a version tag) | `release-web.yml` | `cambeerfestival`, branch `release` |
| Android | Google Play Internal track | `workflow_dispatch` with `upload_to_play=true` (called by `release.yml`) | `release-android.yml` | package `ralcock.cbf`, min SDK 21, target SDK 34 |
| Worker (API proxy) | `data.cambeerfestival.app` | push to `main` touching `cloudflare-worker/**`, `data/festivals.json`, or `scripts/**` | `cloudflare-worker.yml` job `deploy-worker` | worker `cbf-data-proxy` (`cloudflare-worker/wrangler.toml`) |
| Pages Functions (social-crawler OG tags) | colocated with whichever Pages project served the request | same deploy as the web build it rides with | none separate — `functions/` ships inside `build/web` deploys | n/a |
| API docs (OpenAPI/Redoc) | GitHub Pages | push/PR touching `proto/**` | `api-docs.yml` | n/a (GitHub Pages, not Cloudflare) |

Both Cloudflare Pages projects are confirmed live in `docs/tooling/cloudflare-pages.md`
and match `ci.yml`/`release-web.yml` exactly (project names, branch names,
`--project-name=` flags). **`docs/processes/ci-cd.md` is stale** — it names a
`deploy-worker.yml` workflow (real name: `cloudflare-worker.yml`), a single
`main.cambeerfestival.pages.dev` staging URL, `cloudflare/pages-action@v1`, and
`wrangler-action@v3`. None of that matches the current workflow files
(`cloudflare/wrangler-action@v4`, two-project split above). Trust the workflow
YAML and `docs/tooling/cloudflare-pages.md`, not `docs/processes/ci-cd.md`.

One `CLOUDFLARE_API_TOKEN` GitHub secret covers Workers Scripts + Pages (+ D1)
Edit permissions for all of the above.

---

## 3. The release train runbook

Versioning is CalVer `YYYY.M.patch` (month with no leading zero). Build number
= `date * 100 + patch` (e.g. `2026.5.7` tagged on 2026-05-17 →
`2026051707`) — keeps Android `versionCode` unique even for two releases the
same day.

```
push to main (or daily 06:00 UTC cron, or manual dispatch)
        │
        ▼
release-pr.yml
  - computes next vYEAR.MONTH.PATCH from existing tags
  - git-cliff --unreleased → release-notes.md
  - prepends CHANGELOG.md, seds pubspec.yaml version
  - opens/force-updates PR  release/next → main,  titled "Release X.Y.Z"
        │
        │  (human reviews + merges release/next)
        ▼
release.yml   (fires on: pull_request closed, head_ref == release/next, merged == true)
  - reads version from pubspec.yaml (source of truth, not the PR title)
  - creates + pushes tag vX.Y.Z
  - creates GitHub Release from the top CHANGELOG.md slice
  - gh workflow run release-web.yml    -f version=vX.Y.Z
  - gh workflow run release-android.yml -f version=vX.Y.Z -f upload_to_play=true
        │
        ├──▶ release-web.yml: analyze → test → build web (5 dart-defines) →
        │     wrangler pages deploy --project-name=cambeerfestival --branch=release
        │
        └──▶ release-android.yml: matrix{apk, appbundle} release build →
              GitHub Release artifacts + checksums → Play Internal track
```

To cut a release manually:
```bash
# release-pr.yml already opened/updated release/next — just merge it in the UI,
# or dispatch it directly:
gh workflow run release-pr.yml

# Hotfix outside the normal flow: branch from the tag, not main
git checkout v2026.5.2
git checkout -b hotfix/fix-description
# fix, conventional-commit, PR into main; release-pr.yml picks it up next run
```

### Traps

1. **CI does not run on the release PR.** GitHub does not fire workflow
   triggers for PRs authored by `GITHUB_TOKEN`. This is accepted as safe
   because the only diff from `main` is `pubspec.yaml` (version bump) and
   `CHANGELOG.md` (generated text) — the actual app code already passed CI on
   `main` before `release-pr.yml` ran. Don't "fix" this by disabling branch
   protection or forcing a re-run; if you want CI on the release PR, that
   requires a real PAT in `secrets.RELEASE_TOKEN` passed to
   `create-pull-request`'s `token:` input — not currently configured.
2. **`release.yml` uses `workflow_dispatch`, not the tag-push event, to launch
   deploys** — because `GITHUB_TOKEN`-created tags/releases don't fire their
   own workflow triggers either. `gh workflow run ... -f version=...` sidesteps
   it. If you manually push a tag yourself (bypassing the release PR), the
   *web/android* deploy workflows will NOT auto-fire — you must dispatch them
   yourself with the version input (both accept `workflow_dispatch` with a
   `version` string).
3. **`pr-lint.yml` is skipped when `head_ref == 'release/next'`** — the release
   PR title ("Release X.Y.Z") is not conventional-commit-shaped and isn't
   meant to be.
4. **`release-pr.yml` ignores pushes that only touch `pubspec.yaml` or
   `CHANGELOG.md`** (anti-race with itself). A lone version-bump-only push
   (e.g. a manual dependency version edit) won't refresh the release PR until
   the next daily cron — it isn't lost, just delayed up to 24h.
5. **`cliff.toml`'s `tag_pattern` is strict CalVer**:
   `v[0-9]{4}\.[0-9]+\.[0-9]+`. A tag outside that shape is invisible to
   git-cliff's changelog generation — don't hand-craft tags like `v1.0.0-beta`
   expecting them to show up.
6. **Festival-freeze rule** (maintainer-confirmed, see skill `change-control`
   for the full unwritten-rules list): no risky deploys near or during the
   live festival. This applies to the release train too — check the festival
   freeze window before merging `release/next` or dispatching
   `release-web.yml`/`release-android.yml` manually, even though nothing in
   the workflow YAML enforces it technically.

First-ever Android release needs a **manual AAB upload** through Play Console
(the Google Play API can't create a new app listing) — see
`docs/tooling/android-release.md` for the one-time Play App Signing
enrollment; every release after that is fully automated.

---

## 4. D1 provisioning runbook (currently NOT provisioned)

`cloudflare-worker/wrangler.toml` has a **placeholder** database id:

```toml
[[d1_databases]]
binding = "RATINGS_DB"
database_name = "cbf-myfestival"
database_id = "00000000-0000-0000-0000-000000000000"
migrations_dir = "migrations"
```

Tests and `wrangler dev` use a **simulated local D1** (via
`@cloudflare/vitest-pool-workers`) and ignore this id entirely — the whole
worker test suite (`npm test` in `cloudflare-worker/`) runs green with the
placeholder in place, so a passing `test:worker` run tells you nothing about
whether the real database exists.

To provision the real thing (do this before any manual `wrangler deploy` that
needs to serve real `/v1alpha` review traffic):

```bash
cd cloudflare-worker

# 1. Create the D1 database in the Cloudflare account
wrangler d1 create cbf-myfestival
# → paste the returned database_id into wrangler.toml's database_id field

# 2. Apply migrations to the REAL (remote) database
wrangler d1 migrations apply cbf-myfestival --remote
# (only one migration exists today: migrations/0001_create_reviews_table.sql —
#  single `reviews` table, PK (bucket, festival_id, drink_id, device_id))
```

The `CLOUDFLARE_API_TOKEN` used for this needs **D1:Edit** permission in
addition to whatever Workers/Pages scopes it already has (comment in
`wrangler.toml` and the general secret at `docs/tooling/github-secrets.md`
cover Workers+Pages; D1 is an additional scope to add when provisioning).

**Before any manual (non-CI) `wrangler deploy`**, copy the festivals registry
into the worker directory — it's the embedded-at-deploy-time data source and
is gitignored so it isn't committed twice:

```bash
cp data/festivals.json cloudflare-worker/festivals.json
```

CI's `deploy-worker`/`validate-worker` jobs in `cloudflare-worker.yml` do this
copy step automatically; only a manual/local `wrangler deploy` needs you to
remember it. `cloudflare-worker/package.json`'s `pretest` script does the same
copy for tests, so `npm test` locally works without this step — it's deploy
specifically that needs it.

This whole runbook is a prerequisite for the "cloud sync" half of the My
Festival campaign (v1alpha API + D1 + Flutter sync client) — see skill
`my-festival-campaign` if you're picking that up.

---

## 5. Festival data updates

```bash
# 1. Edit the registry
$EDITOR data/festivals.json

# 2. Validate locally against the schema before pushing
./bin/mise run validate:festivals
# = npm ci (in scripts/) && node ../scripts/validate-festivals.js
# Ajv (strict:false + ajv-formats) against docs/code/api/festival-registry-schema.json

# 3. Push to main
git add data/festivals.json && git commit -m "..." && git push
```

Pushing triggers `cloudflare-worker.yml`: `validate-festivals` (re-checks the
schema in CI) → `test-worker` → `deploy-worker` (copies
`data/festivals.json` → `cloudflare-worker/festivals.json`, then
`wrangler deploy`). The worker embeds the registry at deploy time and serves
it from `GET /festivals.json` with `no-cache, must-revalidate` — there is no
separate "publish" step beyond the git push landing on `main`.

`data/festivals.json` (not `web/data/festivals.json` — AGENTS.md has a typo
here, verify against the actual file if in doubt) holds `festivals[]`,
`default_festival_id`, `version`, `last_updated`; per-festival fields include
`id` (`^[a-z0-9-]+$`), `available_beverage_types[]`, `data_base_url`
(relative or absolute), `is_active`, `charity_*`.

Cross-reference: **festival-freeze rule** (skill `change-control`) governs
*when* you're allowed to push a festivals.json change, not just how.

---

## 6. Where output lands

| Artifact | Path | Produced by |
|---|---|---|
| Web build | `build/web/` | `build:web`, `build:web:prod`, CI `build-web` job |
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` | `flutter build apk --release` |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` | `flutter build appbundle --release` |
| Android mapping (deobfuscation) | `build/app/outputs/mapping/release/mapping.txt` | release AAB build; uploaded to Crashlytics (Gradle plugin) and Play Console (CI step) |
| Coverage | `coverage/lcov.info` | `./bin/mise run coverage` |
| Playwright HTML report | `playwright-report/` | any `test:e2e*` run |
| Analyze log | path printed as `ANALYZE_LOG=...` (mktemp `/tmp/analyze-XXXXXX.log`) | `./bin/mise run analyze` — grep it, don't re-run to check something else |
| Test log | path printed as `TEST_LOG=...` (mktemp `/tmp/test-XXXXXX.log`) | `./bin/mise run test` — same idea |
| CI `web-build` artifact | uploaded from `build/web` (source-maps stripped) | `ci.yml` `build-web` job |
| CI `source-maps` artifact | `main.dart.js.map`, retained 7 days | `ci.yml` `build-web` job (only place `--source-maps` is passed outside a manual local build) |
| CI Android artifacts | `android-apk`, `android-aab`, `android-mapping` (release-android.yml); `app-debug-apk` (ci.yml, debug-signed release build) | respective workflows |
| OpenAPI spec artifact | `openapi-spec` (PR) / published to GitHub Pages (main) | `api-docs.yml` |

For the *measurement* side of these logs (how to interpret analyzer output,
decode a minified crash from a source map, read coverage deltas) see skill
`diagnostics-and-tooling` — this skill only tells you where things land, not
how to read them.

---

## 7. Operational checks — what you (the agent) can actually see

Be honest about the boundary: you have **no Cloudflare dashboard, no Firebase
Console, no Google Play Console access**, and cannot browse a deployed URL
yourself. What you *can* do from a shell:

```bash
# Worker health (public, no auth) — confirms the worker is up and serving
curl -s https://data.cambeerfestival.app/health
# → {"status":"ok"}

# Worker-served festival registry (public)
curl -s https://data.cambeerfestival.app/festivals.json | head -c 300

# Production / staging site availability (HTTP-level only — Flutter web
# renders to a <canvas>, so curl/HTML inspection cannot confirm the UI
# actually works; see debugging-playbook's note on Playwright's canvas limit)
curl -sI https://cambeerfestival.app
curl -sI https://staging.cambeerfestival.app

# A PR preview URL appears as a comment on the PR itself (posted by
# ci.yml's deploy-web-preview job) — read it with:
gh pr view <number> --json comments
```

What you **cannot** verify without a human: Cloudflare Pages deployment
status/logs (dashboard-only), Cloudflare Worker resource usage/limits, D1
database contents or query performance, Firebase Analytics event volume,
Crashlytics crash-free-rate or new crash groups, Google Play Console review
status/rollout percentage. **Flag these explicitly as outstanding** rather
than guessing — e.g. "worker `/health` returns ok; I cannot confirm the
Cloudflare Pages deployment finished — check the dashboard or `gh run watch`
the workflow run."

`gh run list --workflow=<name>` / `gh run watch <run-id>` (GitHub CLI, not a
dashboard) is the one dependable proxy for deployment status an agent *can*
use — it tells you whether the workflow that performs the deploy succeeded,
even though it can't show you the resulting live page.

The in-app `EnvironmentBadge` widget (`lib/widgets/environment_badge.dart`) is
a *user-facing* operational signal, not an agent-facing one: it renders a
colored pill (orange=staging, purple=preview, blue=development, hidden in
production) so a human tester glancing at the app can tell which environment
they're in. Point a human at it if they ask "how do I know I'm looking at
staging" — an agent cannot render or see it.

---

## When NOT to use this skill

- **Toolchain won't install, `mise` itself fails, need to recreate the dev
  environment from scratch, MISE_ENV layering questions** → skill
  `build-and-env`.
- **"Is this change allowed", which CI gate applies, review-comment triage,
  Do-Not-Modify list, the four unwritten rules, ADR process** → skill
  `change-control`.
- **Reading `ANALYZE_LOG`/`TEST_LOG` output, decoding a minified web crash
  from a source map, interpreting a coverage report, screenshot/page-check
  tooling** → skill `diagnostics-and-tooling`.
- **Executing the My Festival / cloud-sync roadmap end-to-end (of which D1
  provisioning here is one step)** → skill `my-festival-campaign`.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at that date:
`mise.toml`, `mise.dev.toml`, `mise-tasks/dev.sh`, `mise-tasks/build/web.sh`,
`mise-tasks/build/web/prod.sh`, `mise-tasks/serve/release.sh`,
`mise-tasks/test/e2e.sh`, `mise-tasks/setup/playwright.sh`,
`mise-tasks/analyze.sh`, `mise-tasks/test.sh`, `playwright.config.ts`,
`package.json` (root, e2e), `cloudflare-worker/wrangler.toml`,
`cloudflare-worker/package.json`, `cloudflare-worker/migrations/`,
`.github/workflows/{ci,release-pr,release,release-web,release-android,
cloudflare-worker}.yml`, `cliff.toml`, `docs/processes/release.md`,
`docs/tooling/{cloudflare-pages,android-release}.md`,
`lib/widgets/environment_badge.dart`. Ran `./bin/mise tasks ls --json` to
confirm no `build:android*` task exists.

Re-verification commands (run when a fact here feels stale):

```bash
# Task list still matches section 1/6? (--json for exact names)
./bin/mise tasks ls --json

# Release train still shaped the same way?
sed -n '1,50p' .github/workflows/release-pr.yml
sed -n '1,80p' .github/workflows/release.yml

# D1 still unprovisioned (placeholder id)?
grep -A2 database_id cloudflare-worker/wrangler.toml

# Deployment topology still matches reality (not the stale doc)?
grep -n "project-name" .github/workflows/ci.yml .github/workflows/release-web.yml
diff <(grep -c . docs/processes/ci-cd.md) <(grep -c . docs/tooling/cloudflare-pages.md)  # sanity: are they still divergent docs?

# CalVer tag pattern unchanged?
grep tag_pattern cliff.toml

# Worker health endpoint still unauthenticated and reachable?
curl -s https://data.cambeerfestival.app/health
```
