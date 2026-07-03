---
name: debugging-playbook
description: Load when debugging ANY misbehaviour in the Cambridge Beer Festival app — wrong/stale drinks after switching festival, one-frame flash of the previous festival, app stuck on cached data with no error, data reverting on cold start, web release "Null check operator" crashes (what does this crash symptom MEAN — the triage, not how to run the decode tooling), web build failures that work on mobile, wrong analytics environment, empty drink categories, flaky/failing widget tests (pumpAndSettle, copyWith, GoRouter, semantics, goldens), CI job failures (fmt/analyze/codecov/pr-lint/e2e/proto), or worker API errors (503 STORAGE_UNCONFIGURED, CORS rejection, 502). Provides a symptom → cause → discriminating-experiment → fix-pattern triage table for this project's real, historically-verified failure modes, plus dead-end traps not to repeat.
---

# Debugging Playbook

Symptom-first triage for this codebase. Every row below comes from a real incident
(issue/PR cited); code locations verified against the working tree on 2026-07-02.
Find your symptom, run the discriminating experiment, apply the fix-pattern. If
your symptom isn't here, check skill `failure-archaeology` before deep-diving —
most battles in this repo have already been fought once.

## How to debug here (method)

1. **Reproduce with the cheapest signal.** Prefer a unit/widget test over the dev
   server; prefer the dev server over a release build. Domain controllers
   (`lib/domain/controllers/`) are pure and synchronous — most state bugs
   reproduce in a plain Dart test.
2. **Run tests/analyze ONCE, then grep the log.** `./bin/mise run test` and
   `./bin/mise run analyze` print `TEST_LOG=`/`ANALYZE_LOG=` paths (temp files)
   at the start of the run. Grep that file for different things instead of
   re-running the suite. See skill `diagnostics-and-tooling` for the full
   workflow, coverage inspection, and the source-map crash-decode scripts.
3. **Isolate with a discriminating experiment** (third column below): one cheap
   observation that splits the hypothesis space in half. Predict the result
   before running it.
4. **Check history before deep-diving.** Skill `failure-archaeology` chronicles
   every major investigation, rejected fix, and revert. Re-proposing a rejected
   fix (see Traps below) wastes a review cycle at best.
5. **Fix through change control.** Every behaviour change goes through
   `./bin/mise run check`, a conventional commit, and PR + CI. See skill
   `change-control`. CI is ground truth: if analyzer and tests pass, a "this
   won't compile" review comment is wrong.

> Doc-drift warning: AGENTS.md still lists `FavoritesService`/`RatingsService`/
> `TastingLogService` as separate services. They no longer exist — personal state
> was unified into `UserDataStore` (`lib/services/user_data_store.dart`, #391/#395).
> `lib/services/storage_service.dart` now contains only `FestivalStorageService`.
> Trust the code.

---

## Triage: festival & provider state

| Symptom | Likely cause | Discriminating experiment | Fix pattern | History |
|---|---|---|---|---|
| Wrong/stale festival's drinks shown after switching festivals quickly | An older in-flight `loadDrinks()` completed after the switch and clobbered newer state — the stale-load-token guard is missing on a new async path | Add a log/breakpoint on `_setAllDrinks` and switch festivals rapidly: does a set fire for a festival that is no longer current? Grep your new code path for a `token != _drinksLoadToken` check | Capture `final token = ++_drinksLoadToken;` before the await; bail if `token != _drinksLoadToken` after EVERY await. Existing guards: `lib/providers/beer_provider.dart:86` (field), checks at lines 406, 451, 480, 495, 519 | #263, #266, PR #275 |
| Favourites/My Festival screen flashes the *previous* festival's data for one frame after a deep link or switch | `_festivalScopeRedirect` (`lib/router.dart:24-42`) schedules `setFestival` via `addPostFrameCallback` and returns null — the first frame renders against the old `currentFestival`. Any deferred-post-frame state change guarantees ≥1 stale frame | Pump exactly one frame in a widget test after navigating: does the old festival's content appear? | Guard the screen on route-vs-provider mismatch (`currentFestival.id != festivalId` → loading scaffold) — full pattern and rationale: skill `ui-and-accessibility` Part 4.1; reference implementation `lib/screens/my_festival_screen.dart:15-17` | #310 → #397, fixed PR #409 |
| Server-side festival change (e.g. new beverage type added) never picked up during a session | A held `Festival` reference went stale after a background registry refresh — old code only re-assigned when null | Compare `currentFestival.availableBeverageTypes` against the fresh registry response after `loadFestivals()` completes | Re-resolve held references into the new collection by domain key. `FestivalController.setSource` returns `true` when the current festival's beverage types changed; `loadFestivals()` (`beer_provider.dart:347-354`) then fires `unawaited(loadDrinks())` | #306, fixed PR #362 |
| Favourite/rating change appears then vanishes, or test finds stale values | Code holds a pre-`copyWith` `Drink` reference — the old instance is a snapshot and no longer in the list | After the mutation, look the drink up by `id + festivalId` in `provider.allDrinks` and compare with your held reference | Find items by domain key (`id + festivalId`), never `indexOf`/object identity (`beer_provider.dart:727`, `lib/models/drink.dart:312-323`). Tests must re-read from the provider after mutating | PR #366, #323/PR #380 |

## Triage: cache, offline & staleness

| Symptom | Likely cause | Discriminating experiment | Fix pattern | History |
|---|---|---|---|---|
| App stuck showing stale cache, no error, no retry for up to an hour | Vacuous success: festival has `availableBeverageTypes: []`, so `Future.wait([])` resolves instantly and the load "succeeds" without touching the network, stamping the freshness timestamp | Check the festival's `availableBeverageTypes` in `data/festivals.json` (or the live registry). Empty? This is it | "No work" ≠ "refreshed". `_refreshDrinksFromNetwork` resets `_lastDrinksRefresh = null` when types are empty (`beer_provider.dart:489-493`) so `isDrinksDataStale` stays true. Preserve this branch in any refactor | #308, fixed PR #382 |
| Offline user hammers the network on every app resume — OR — never retries after coming back online | Last-success and last-attempt semantics collapsed into one timestamp. Success-only stamping → retry storm; attempt-stamping-as-success → offline lockout | Toggle network off, resume the app twice within a minute: does a second fetch fire? (It shouldn't — 1-min rate limit) | Keep TWO timestamps: `_lastDrinksRefresh` (staleness, success only) vs `_lastDrinksRefreshAttempt` (rate-limit, stamped in `finally`, `beer_provider.dart:520`). Festivals side: `FestivalController.recordAttempt()`. Rate limit: `_refreshRetryThreshold` = 1 min (`beer_provider.dart:83`), checked in `refreshIfStale()` (547-575) | #307, fixed PR #336 |
| Favourites/ratings/cached drinks revert to an older snapshot on next cold start (in-memory state was fine all session) | Cache write race: concurrent unawaited persists — last `setString` wins on disk | Grep the suspect service for unawaited writes to SharedPreferences that aren't chained through a serial queue | Serialize writes through a chained future AND guard the chain: `_writeChain = writeTask.catchError((_) {})` — one thrown write must not poison the queue for the rest of the session. See `lib/services/cache_service.dart:25, 57-60` | #309, fixed PR #419 |
| One drink category (e.g. cider) silently empty while others load | Per-type 404 soft-omission: a type returning HTTP 404 lands in NEITHER `drinksByType` NOR `failedTypes` — deliberate, so a transient mid-deploy 404 preserves the cached entry instead of wiping it | `curl -si https://data.cambeerfestival.app/{festivalId}/{type}.json` — 404 means upstream genuinely has no file for that type; 200-but-empty means a data problem | Usually not a bug: fix the upstream data or the festival's `available_beverage_types` in `data/festivals.json`. Do NOT "fix" the omission — it protects the cache (`lib/services/beer_api_service.dart:55-91`; invariant also enforced in `cache_service.dart` merge) | Design decision; resilience-review family #302/#306-#309 |

## Triage: web platform & release crashes

| Symptom | Likely cause | Discriminating experiment | Fix pattern | History |
|---|---|---|---|---|
| Web release: "Null check operator used on a null value" from `navigator.dart`, often on load/refresh | A redirect-only route with no `builder`: while the provider initializes the redirect returns null, go_router mounts a Navigator with empty `pages` and no `onGenerateRoute`; Flutter's hardcoded `restorationScopeId: 'router'` then null-crashes in release | Decode the minified frame with source maps (skill `diagnostics-and-tooling` ships the decode script; remember the CI-vs-local ~4-line offset — try `line` and `line + 4`). Does it land in `navigator.dart` `_routeNamed`? | Every route gets a builder, even redirect-only ones — see the loading builder + explanatory comment at `lib/router.dart:76-85`. Regression guard: the e2e "no critical console errors" check | #386, fixed PR #408 (after Flutter 3.44 upgrade PR #384 surfaced it) |
| Web build fails (compile error naming `dart:io`) while mobile builds fine | Direct `import 'dart:io'` — those types don't exist on Flutter web | `grep -rn "import 'dart:io'" lib/` | Conditional imports: `import 'connectivity_web.dart' if (dart.library.io) 'connectivity_io.dart';` (`lib/services/beer_api_service.dart:5`). Stub pairs must NOT be added to barrel exports (`services.dart`) | #324, fixed PR #376 |
| Analytics events from previews/staging polluting production, or production events missing | `EnvironmentService` host classification. Historic bug: unknown hosts defaulted to *production* | `EnvironmentService.classifyHostname('<host>')` in a unit test — it's a pure static helper | Only `cambeerfestival.app` is production; unknown → NOT production (under-count beats pollution) — `lib/services/environment_service.dart` (`isProductionHost` 28-41; `classifyHostname` 45-56 is the name the experiment above calls). Testability pattern: `@visibleForTesting` pure helper bypasses the `kIsWeb` guard. Analytics is production-only (`_isAnalyticsEnabled`); Crashlytics `logError` runs everywhere | #269, fixed PR #327 |

## Triage: widget-test failures

| Symptom | Likely cause | Discriminating experiment | Fix pattern | History |
|---|---|---|---|---|
| Assertion sees stale state even after `pumpAndSettle()` | `pumpAndSettle()` does NOT await in-flight futures — an unawaited provider call is still running | Add `await` to the provider call: does the test pass now? | Always `await provider.setRating(...)` / `toggleFavorite(...)` before asserting | AGENTS lessons-learned (from subagent PR failures) |
| Test finds old field values after a mutation | Captured `Drink` reference is a pre-`copyWith` snapshot | Re-read the drink from `provider.allDrinks` by `id + festivalId` and compare | Re-read from the provider after every mutation; never assert on a reference captured before it | PR #366 |
| Screen test throws a routing error when pumped as a bare widget | Screen calls `context.go()`/`context.push()` — needs a real GoRouter | Does the screen (or a widget it builds) use navigation helpers or `context.go`? | Wrap in `MaterialApp.router` with a `GoRoute` for the screen's real path AND a stub `/` route (full recipe in AGENTS.md "Screen Widget Tests") | Established pattern; see `test/router_test.dart` |
| `findsOneWidget` fails on a semantics label that is visibly present (finds 2) | Duplicate semantics nodes: button widgets synthesise a node from their visible text; an explicit `Semantics(label:)` wrapper adds a second | `find.bySemanticsLabel(...)` count — is it 2? | Use `findsWidgets`, or prefer the widget-predicate strategy (`widget is Semantics && widget.properties.label == ...`) | AGENTS semantics-testing gotcha |
| Golden test diffs after an intentional visual change | Goldens are pixel snapshots; any rendering change diffs | Inspect the failure images under `test/failures/` — is the diff the intended change and nothing else? | `./bin/mise run goldens:update [test-file]`, re-run, review the PNG diff in the PR. Only 4 goldens exist, all in `test/goldens/`. Unintended diffs in unrelated goldens = scope creep — investigate, don't update. See skill `validation-and-qa` | Golden protocol |

## Triage: CI failures

| Failing check | Likely cause | Discriminating experiment (local) | Fix pattern | History |
|---|---|---|---|---|
| `fmt` job | Unformatted Dart/JS/shell | `./bin/mise run fmt:check` | `./bin/mise run format` (or `./bin/mise run --no-deps dart:format` for Dart-only). Run before every commit; `check` includes it | Recurring haiku-agent failure mode (AGENTS lessons) |
| `analyze` job | New analyzer warnings/errors | `./bin/mise run analyze lib/<changed-dir>/` then grep `ANALYZE_LOG` | Fix the findings; never edit `analysis_options.yaml` (Do-Not-Modify list) | — |
| `codecov/patch` | New lines uncovered | Is the *check* failing, or just the comment? Comments are informational | Add tests only if the check fails. Pure refactors inherit prior coverage — don't add tests to satisfy a comment on moved code. Delegating lines like `Uri.base.host` are expected-uncovered | PR #303; AGENTS coverage doctrine |
| `PR Lint` | PR title not conventional-commit format | Read the check log — it names the rule | Retitle: `type(scope): subject`, e.g. `fix(router): handle missing festival ID` | pr-lint.yml |
| `test-e2e-web` | Route/console-error regression — but note Flutter web renders to `<canvas>`, so Playwright checks URL mechanics and console only. **A route returning 200 ≠ working UI**; a page can 200 and render an error state | Build + serve locally (`MISE_ENV=dev ./bin/mise run build:web`, then serve + `test:e2e`; see skill `run-and-operate`), read the Playwright report artifact | Fix the routing/console error; for UI correctness use widget tests, not e2e (accepted gap, `docs/adr/0005-e2e-testing-strategy.md`) | ADR 0005; #386 was caught by this job |
| `proto` (buf breaking) | Wire/file-breaking change vs `main:proto` | `MISE_ENV=dev ./bin/mise run proto:lint` + api-lint (dev env only; CI uses buf-action directly) | Don't break released fields; follow the promotion path in `proto/buf.yaml`. If your fix requires suppressing an api-linter rule, the fix is probably wrong — see skill `api-contract` | #430 (WIRE rule) |

## Triage: worker & API (data.cambeerfestival.app)

| Symptom | Likely cause | Discriminating experiment | Fix pattern | History |
|---|---|---|---|---|
| `/v1alpha/...` returns 503 with reason `STORAGE_UNCONFIGURED` | `env.RATINGS_DB` D1 binding missing — `cloudflare-worker/wrangler.toml` ships a placeholder `database_id = "00000000-..."` | `curl -s https://data.cambeerfestival.app/v1alpha/festivals/x/drinks/y/review -H 'X-Device-Id: t'` and check the error body (`reviews.ts:158-166`) | Provision D1: `wrangler d1 create cbf-myfestival` → paste real id into wrangler.toml → `wrangler d1 migrations apply cbf-myfestival --remote` (`--remote` migrates the real DB, not the local sim); token needs D1:Edit. Full runbook: skill `run-and-operate` | v1alpha arc (PR #426); deploy still pending |
| Browser: CORS error calling the worker; curl works fine | Origin not in the allow-list — the worker returns NO CORS headers for unknown origins (silent reject) | Compare your page's `Origin` against `ALLOWED_ORIGINS` (`cloudflare-worker/worker.js:29-37`) and the wildcard suffixes in `getCorsHeaders` (worker.js:279-329): `*.cambeerfestival.pages.dev`, `*.staging-cambeerfestival.pages.dev`, `*.trycloudflare.com` | Add the origin to the allow-list — but `cloudflare-worker/` is on the Do-Not-Modify list; needs explicit maintainer request + PR | Allow-list design; ops trap (trycloudflare wildcard live in prod) |
| Worker returns 502 | Upstream `data.cambridgebeerfestival.com` fetch failed — the worker proxies everything not matched by its own routes | `curl -si https://data.cambridgebeerfestival.com/<same-path>` — is upstream itself down/erroring? | Nothing to fix app-side; upstream CAMRA feeds are untouchable (unwritten rule). The app's SWR cache is the mitigation — verify cached data still renders with the refresh notice | worker.js:102-137 |

---

## Traps — dead ends already tried (do NOT repeat)

| Tempting "fix" | Why it's wrong | What happened |
|---|---|---|
| Suppress an error by matching its **message string** (e.g. treat every "Null check operator used on a null value" as benign) | Message matching is catastrophically over-broad — it silences every future bug with the same message | `isBenignRestorationError()` did exactly this for the #386 crash on web release; deleted as dangerous when the real fix (route builder, PR #408) landed. Grep confirms it's gone from `lib/`. The narrowly-scoped `isTransientFontLoadError` (`lib/main.dart:74`) survives because it matches a specific transient font-load failure — don't widen it |
| Classify exceptions via `runtimeType.toString()` against a name set | Fragile (minification, renames) and untyped | Removed by PR #376 (#324). Correct pattern: conditional imports `connectivity_io.dart`/`connectivity_web.dart`, typed `is` checks. Also: `HandshakeException`/`CertificateException` extend `TlsException` — checking both is dead code |
| `import 'dart:io'` to get exception types for the check above | Breaks the web build outright | The constraint that forced the conditional-import design (#324; archived todo C1) |
| Substring-match free-text availability statuses (`'out'`, `'low'`) | `'out' ⊂ 'about'`, `'low' ⊂ 'below'`; mis-bucketed ~32% of statuses | #348 (backed by the ~900-drink census #349). Now exact-match map + explicit `unknown` (`lib/models/drink.dart`, PR #360). Vocabulary is NOT stable across festivals — keep the unknown branch |
| Skip stamping the timestamp on a no-op load, and stop there | Insufficient — a switch from a loaded festival to an empty one still looked fresh | #308's fix took two commits; the second explicitly resets `_lastDrinksRefresh = null` (`beer_provider.dart:492`) |
| Add a duplicate `etag` field to Update requests / return `Empty` from soft Delete / suppress an api-linter rule to make a reviewer happy | Automated reviewers repeatedly propose these; the AIP facts in AGENTS.md exist to refute them | See skill `api-contract` and AGENTS "Proto / AIP Design Facts" |

---

## When NOT to use this skill

- **Environment won't build / tools missing / mise install failures** → skill `build-and-env`.
- **You need the full history of an incident** (evidence, rejected alternatives, status) → skill `failure-archaeology`. This playbook only cites; that skill narrates.
- **You need to measure** (run tests/analyze and mine the logs, decode a source map, take screenshots, inspect coverage) → skill `diagnostics-and-tooling` — it owns the tooling this playbook's experiments rely on.
- **Deciding what evidence proves a fix** / deep-vs-shallow test design → skill `validation-and-qa`.
- **Deploying/running the app or provisioning D1** → skill `run-and-operate`.

## Provenance and maintenance

Written 2026-07-02. All code locations verified against the working tree at that
date; issue/PR numbers cross-checked against the failure history (local clone is
shallow — cite PRs/issues, not old SHAs). Sandbox note (2026-07-02): in the
Claude Code Web sandbox, `./bin/mise run <task>` may 403 while auto-installing
dev tools; `MISE_ENV=claude-code-web ./bin/mise run <task>` runs base tasks.

Re-verify before trusting drift-prone facts:

```bash
# Stale-load-token guard locations
grep -n "_drinksLoadToken" lib/providers/beer_provider.dart
# Festival-flash guard
sed -n '13,18p' lib/screens/my_festival_screen.dart
# Serialized cache write chain
grep -n "_writeChain" lib/services/cache_service.dart
# Empty-beverage-types staleness reset
sed -n '484,493p' lib/providers/beer_provider.dart
# Router / route builder for #386
sed -n '66,86p' lib/router.dart
# 404 soft-omission semantics
sed -n '55,91p' lib/services/beer_api_service.dart
# Environment host classification
sed -n '26,41p' lib/services/environment_service.dart
# Worker CORS allow-list + D1 error
grep -n "ALLOWED_ORIGINS" -A 9 cloudflare-worker/worker.js | head -12
grep -n "STORAGE_UNCONFIGURED" cloudflare-worker/reviews.ts
# Conditional import (dart:io on web)
grep -rn "if (dart.library.io)" lib/
# Dead ends stayed dead
grep -rn "isBenignRestorationError\|runtimeType.toString" lib/ || echo "clean"
# CI job names
grep -n "^  [a-z-]*:" .github/workflows/ci.yml
```
