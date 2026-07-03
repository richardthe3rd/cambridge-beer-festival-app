---
name: diagnostics-and-tooling
description: Load when you need to MEASURE something in the Cambridge Beer Festival app instead of eyeballing it — running `./bin/mise run test`/`analyze` and grepping the printed TEST_LOG/ANALYZE_LOG path, decoding a minified Flutter-web crash stack from a source map (how do I run the decode tooling), reading `coverage/lcov.info` or a Codecov comment, driving `scripts/check-page.mjs`/`screenshot-batch.mjs` for a headless page/console-error probe, interpreting `flutter analyze` lint/complexity output, checking what Crashlytics/Analytics actually record in production, or using `./bin/mise doctor`/`env --json`/`ls --json` to diagnose a toolchain problem. Ships two helper scripts (`scripts/decode-stack.mjs`, `scripts/lcov-summary.sh`). Does not tell you what a symptom MEANS (see `debugging-playbook`) or what makes a test good (see `validation-and-qa`).
---

# Diagnostics and Tooling

Every fact below was re-verified against the working tree on 2026-07-02 (see
Provenance). If a command's output disagrees with what's written here, trust
the command — then fix this file.

**Theme:** run the measurement tool once, read its output carefully, and
interpret it correctly. Don't guess at "it's probably fine" or "that looks
like the bug" — grep the log, decode the stack, read the coverage line.

---

## 1. Test / analyze log workflow

`./bin/mise run test [path]` and `./bin/mise run analyze [path]` are thin
wrappers (`mise-tasks/test.sh`, `mise-tasks/analyze.sh`) around `flutter test`
/ `flutter analyze --no-fatal-infos`. Both:

1. Print a log path FIRST, before running anything: `TEST_LOG=/tmp/test-XXXXXX.log`
   or `ANALYZE_LOG=/tmp/analyze-XXXXXX.log` (mktemp-generated).
2. Stream output through `tee` into that file, filtering two noise lines
   (`Woah! You appear|superuser privileges` — root-user warnings irrelevant
   here).
3. Preserve the real exit code via `${PIPESTATUS[0]}` (the tee would otherwise
   mask a non-zero `flutter` exit).
4. Print a ready-to-use grep command at the end:
   - test: `grep -n 'FAILED\|ERROR' $TEST_LOG`
   - analyze: `grep -n 'error\|warning' $ANALYZE_LOG`

**Run once, grep many times.** Do not re-run the whole suite to look for a
different string — the log file already has everything.

```bash
./bin/mise run test test/domain/services/drink_filter_service_test.dart
# TEST_LOG=/tmp/test-AbCdEf.log
grep -n 'FAILED\|ERROR' /tmp/test-AbCdEf.log
grep -n 'preference_keys' /tmp/test-AbCdEf.log   # any other query, same log
```

### Stable paths across multiple runs

Override the mktemp path with the env var so repeated runs land in one place
you can diff:

```bash
TEST_LOG=/tmp/my-run.log ./bin/mise run test
ANALYZE_LOG=/tmp/my-analyze.log ./bin/mise run analyze lib/screens/
```

### What good/bad output looks like

- **test**: `flutter test` prints one line per test group in `MM:SS +N: <name>`
  form, ending `All tests passed!` (good) or `Some tests failed.` with `FAILED`
  markers and stack traces above the summary (grep target: `FAILED\|ERROR`).
  Verified live: `00:02 +2: All tests passed!`.
- **analyze**: `Analyzing <paths>...` then either `No issues found! (ran in
  N.Ns)` (good — verified live against `lib/utils/` and `lib/constants/`), or
  one line per finding, bullet-separated:
  `  info • <message> • <file>:<line>:<col> • <lint_rule_name>`
  (severity is `info`, `warning`, or `error`; `--no-fatal-infos` means `info`
  findings don't fail the task, `warning`/`error` do).

### Env override reference

| Var | Purpose |
|---|---|
| `TEST_LOG` | Force `mise-tasks/test.sh`'s log to a fixed path instead of mktemp |
| `ANALYZE_LOG` | Same for `mise-tasks/analyze.sh` |

Both tasks `#MISE depends=["generate"]` — they run code generation first, so
mock/model changes are picked up automatically.

---

## 2. Source-map crash decoding

When a Flutter web release build throws in production (Crashlytics report,
Playwright console.error, CI e2e failure), the stack trace is minified JS:
`main.dart.js:89998:16`. Decode it back to Dart source + line with the shipped
helper.

### Step 1 — build with source maps

The normal build tasks (`build:web`, `build:web:prod`) do **not** pass
`--source-maps` (verified: `mise-tasks/build/web/prod.sh` has no such flag).
Build directly:

```bash
./bin/mise exec -- flutter build web --release --base-href "/" --source-maps
# -> build/web/main.dart.js
# -> build/web/main.dart.js.map
```

### Step 2 — decode with `scripts/decode-stack.mjs`

The `source-map` npm package is not a project dependency — install it
temporarily and uninstall when done (per AGENTS.md discipline; do not leave it
in `package.json`):

```bash
npm install source-map

node .claude/skills/diagnostics-and-tooling/scripts/decode-stack.mjs \
  build/web/main.dart.js.map \
  89998:16:"crash point" \
  89533:25:"caller"

npm uninstall source-map
```

Output: `<label> -> <file>:<line> (<name>)`, or `NO MATCH ... — wrong map
file, or line is inside generated runtime glue, not app code` when the
position isn't in the map (e.g. it's Dart SDK/package runtime glue, not your
code — see step 4).

### Step 3 — the CI-vs-local line offset (~4 lines)

CI's `build-web` job (`.github/workflows/ci.yml:201-208`) inlines five
`--dart-define` values (`GIT_TAG`, `GIT_COMMIT`, `GIT_BRANCH`,
`BUILD_VERSION`, `BUILD_TIME`) that a plain local build doesn't have — this
shifts minified line numbers by roughly 4 lines. Three ways to handle it,
cheapest first:

1. **Pull CI's own map instead of rebuilding** — `build-web` uploads it as
   artifact `source-maps` (`ci.yml:210-215`, 7-day retention, path
   `build/web/main.dart.js.map`) before stripping it from the deployable
   `web-build` artifact. Guarantees exact parity if the crash came from an
   actual CI/deployed build:
   ```bash
   gh run list --workflow=ci.yml --branch=main --limit=5
   gh run download <run-id> -n source-maps -D /tmp/ci-source-map
   node .claude/skills/diagnostics-and-tooling/scripts/decode-stack.mjs \
     /tmp/ci-source-map/main.dart.js.map 89998:16
   ```
2. **Try both offsets in one call** — `decode-stack.mjs` supports `--offset N`,
   trying the exact line first then `line+N`, labelling which one hit:
   ```bash
   node .claude/skills/diagnostics-and-tooling/scripts/decode-stack.mjs \
     build/web/main.dart.js.map --offset 4 89998:16
   ```
3. **Reproduce CI's exact numbering** by rebuilding locally with the same
   placeholder dart-defines:
   ```bash
   ./bin/mise exec -- flutter build web --release --base-href "/" --source-maps \
     --dart-define=GIT_TAG=local --dart-define=GIT_COMMIT=local \
     --dart-define=GIT_BRANCH=local --dart-define=BUILD_VERSION=local \
     --dart-define=BUILD_TIME=local
   ```

### Step 4 — Flutter SDK frames

If a frame decodes into `flutter/lib/src/widgets/navigator.dart:6047` (SDK
code, not app code), the source lives inside the mise-managed Flutter install
tarball, not in this repo:

```
.mise/http-tarballs/<hash>/packages/flutter/lib/src/widgets/navigator.dart
```

Verified present at `.mise/http-tarballs/a0facd8901.../packages/flutter/...`
in this checkout. There may be two tarballs (old/new Flutter version pin) —
pick the one matching the build you're decoding.

---

## 3. Coverage

```bash
./bin/mise run coverage   # depends=["generate"]; runs `flutter test --coverage`
```

Output: `coverage/lcov.info` (gitignored — verified `.gitignore:123`). This is
the same file Codecov ingests in CI (`ci.yml` `test` job uploads it with
`CODECOV_TOKEN`, `fail_ci_if_error: false`).

### Reading it locally: `scripts/lcov-summary.sh`

```bash
.claude/skills/diagnostics-and-tooling/scripts/lcov-summary.sh                      # coverage/lcov.info, all files
.claude/skills/diagnostics-and-tooling/scripts/lcov-summary.sh coverage/lcov.info 40 # only files at/below 40%
```

Prints one row per source file — `LH LF PCT% FILE` (lines-hit, lines-found,
percent), sorted worst-first, with a `TOTAL` row for the project-wide
aggregate. Verified end-to-end against a real `coverage/lcov.info` generated
from `flutter test --coverage test/constants/preference_keys_test.dart`:
narrow-scope runs correctly show near-zero totals for untouched files (this is
expected — it reflects only the tests you ran, not the whole suite).

The `TOTAL` line is close to, but not identical to, Codecov's `project%` gate
— Codecov may compute flags/carry-forward differently; use this script to
triage which files to improve, not as the exact gate number.

### `codecov.yml` thresholds

```yaml
coverage:
  status:
    project: { default: { target: 70%, threshold: 1% } }
    patch:   { default: { target: 70%, threshold: 1% } }
```

- **`codecov/patch` check failing** (not just a PR comment) — this is a real
  CI gate; the patch (your diff) must hit ≥70% coverage within 1% tolerance.
  Fix it or ask whether the drop is justified before merging.
- **A Codecov PR *comment*** showing a coverage drop with the checks still
  green is informational only (per AGENTS.md "CI is ground truth" / "Coverage
  warnings are informational unless codecov/patch itself fails"). Pure
  refactors that move previously-untested code inherit the old coverage —
  don't add tests solely to silence the comment.

---

## 4. Page / screenshot probes

Two Playwright-driven Node scripts at repo root (`scripts/`), wrapped by mise
file-tasks (dev env only — `MISE_ENV=dev` off-sandbox, plain `./bin/mise` on
Claude Code Web per `.miserc.toml`):

### `test:check-page` → `scripts/check-page.mjs`

```bash
./bin/mise run test:check-page                                    # localhost:8080, screenshot.png
./bin/mise run test:check-page http://localhost:8080/cbf2026 my.png
node scripts/check-page.mjs -u <url> -s <path> -t <timeoutMs> -w <waitMs>
```

Launches headless Chromium, navigates, waits for a Flutter-init signal
(console message containing `Starting application from main method` /
`Using MaterialApp configuration`, OR a `flt-glass-pane`/`flutter-view`
element appearing in the DOM — whichever comes first, up to `--wait`ms),
takes a full-page screenshot, and prints every console message plus a
categorized error/warning summary. **Exit code is `1` if any console
`error`-type message fired**, `0` otherwise — safe to use as a pass/fail gate
in a script.

### `screenshots:batch` → `scripts/screenshot-batch.mjs`

```bash
./bin/mise run screenshots:batch                                  # screenshots.config.json → screenshots/
./bin/mise run screenshots:batch my-config.json my-output-dir
node scripts/screenshot-batch.mjs -c <config.json> -b <baseUrl> -o <dir> -w <waitMs>
```

Config file is a bare JSON array of `{ "path": "...", "name": "..." }`
entries; one browser instance is reused across all pages (Flutter-init wait
only happens once, on the first page). Exits `1` if any page failed to load
OR logged a console error.

**Both scripts require the app already running** (`MISE_ENV=dev ./bin/mise
run serve:release` or `run dev`) — they don't start a server themselves.

### Playwright HTML report (from `test:e2e`)

`playwright.config.ts:26-28` — reporter is `[["list"], ["html", {open:
"on-failure"}]]` locally, `[["github"], ["html", {open: "never"}]]` in CI.
Default output folder (no `outputFolder` override in config, verified) is
`playwright-report/index.html` at repo root; failure artifacts (screenshots,
video, trace) land in `test-results/`. In CI, `ci.yml` uploads this folder as
artifact `playwright-report` (also `csp-smoke-report` for the CSP smoke job) —
7-day retention. Open the report locally with `npx playwright show-report` or
just open `playwright-report/index.html`.

---

## 5. Complexity / lint measurement

There is no numeric cyclomatic-complexity gate in this repo — `dart analyze`
doesn't compute one, and no `dart_code_metrics`-style tool is configured
(verified: not in `pubspec.yaml`, no `analysis_options.yaml` metrics section).
What exists instead is a set of **structure-oriented lint rules elevated to
error/warning** in `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    dead_code: error
    unused_element: warning
    unused_local_variable: warning
    cascade_invocations: warning
    unnecessary_lambdas: warning
    avoid_positional_boolean_parameters: warning
    always_declare_return_types: warning
    require_trailing_commas: warning
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_locals: true
    prefer_single_quotes: true
    always_declare_return_types: true
    avoid_positional_boolean_parameters: true
    cascade_invocations: true
    require_trailing_commas: true
    unnecessary_lambdas: true
```

These were reinforced during the `BeerProvider` decomposition series (staged
controller extraction that shrank a god-object) to hold the line against
regrowing one — see skill `failure-archaeology` for that history. Treat "is
this file getting too complex" as a qualitative judgment backed by these
rules, not a number you can threshold on.

**How to measure it:** run analyze on the path you're worried about and read
severities, not just the pass/fail:

```bash
./bin/mise run analyze lib/providers/
grep -n 'warning\|error' "$ANALYZE_LOG"   # path printed by the task
```

A clean run with zero `warning`/`error` lines (infos are non-fatal, per
`--no-fatal-infos`) is the closest thing to a "not too complex" signal this
repo has.

---

## 6. Production observability (honestly scoped)

What exists in code, verified:

- **Crashlytics** (`lib/main.dart:37-53`) — `FlutterError.onError` and
  `PlatformDispatcher.instance.onError` both route to
  `FirebaseCrashlytics.instance`. Fatal vs non-fatal: `isTransientFontLoadError`
  (font-fetch failures, expected transient) is recorded as **non-fatal**
  (`recordFlutterError` / `recordError(..., fatal: false)`); everything else is
  **fatal** (`recordFlutterFatalError` / `fatal: true`). Manual error logging
  goes through `AnalyticsService.logError()` →
  `crashlytics.recordError(..., fatal: false)` — this one runs in **every**
  environment, not just production (verified `lib/services/analytics_service.dart`).
- **Firebase Analytics** — gated by `AnalyticsService._isAnalyticsEnabled =>
  EnvironmentService.isProduction()`. Production-only: staging/preview/local
  builds log nothing (by design — avoids polluting prod metrics; see issue
  #269 in `failure-archaeology` for why "unknown host → production" was a
  landmine that got fixed to "unknown → NOT production").
- **Cloudflare** — no Cloudflare Web Analytics beacon script exists in
  `web/` (verified: no `cloudflareinsights.com`/beacon reference). Cloudflare
  Pages and Workers both have built-in request analytics in the dashboard
  regardless of app code, but that requires **dashboard access this agent
  does not have** — flag to the human maintainer rather than guessing at
  traffic/error numbers.

**What an agent can verify:** the wiring above (code paths, fatal/non-fatal
routing, environment gating). **What an agent cannot verify:** actual
production crash-free rate, actual Analytics event volume, actual Cloudflare
request/error counts — all of those live in dashboards (Firebase console,
Cloudflare dashboard) with no CLI/API access configured in this repo. Don't
claim "no crashes in production" or "traffic looks fine" without dashboard
access — say the check is outstanding and needs the human.

---

## 7. mise introspection as diagnosis

When a task fails and it's unclear whether it's a code problem or a toolchain
problem, check mise itself before assuming the code is wrong:

```bash
./bin/mise doctor              # sanity-checks the mise install itself; verified runs without downloading tools
./bin/mise env --json          # resolved PATH and env vars mise is injecting — confirms which Flutter/Node is actually active
./bin/mise ls --json           # installed tools + versions + install paths + which config file requested them
./bin/mise config ls --json    # which mise.*.toml files are active for the current MISE_ENV and what tools each declares
```

Verified live in this sandbox: `mise ls --json` shows `flutter 3.44.0` sourced
from `mise.toml`, installed at `.mise/installs/flutter/3.44.0`; `config ls
--json` shows exactly two active config files
(`mise.claude-code-web.toml` + `mise.toml`) under the sandbox's auto-selected
env. If a task uses the wrong tool version, `ls --json`'s `source.path` tells
you which config file to fix — see skill `build-and-env` for the full
environment-layering model (this skill only covers using introspection to
diagnose, not the layering rules themselves).

---

## Sandbox note (dated 2026-07-02)

If `./bin/mise run <task>` hard-fails with a 403 while auto-installing dev
tools on Claude Code Web, prefix base tasks with `MISE_ENV=claude-code-web`
(e.g. `MISE_ENV=claude-code-web ./bin/mise run test test/constants/`). Full
explanation and scope of the workaround: skill `build-and-env` §3a.

---

## When NOT to use this skill

- **Deciding what a measurement means** (e.g. "tests are flaky because of X",
  "this CI failure is caused by Y") — that's triage, not measurement. Use
  `debugging-playbook` for the symptom → cause table.
- **Deciding what a test SHOULD assert, or whether a test is good enough** —
  use `validation-and-qa` (deep-vs-shallow doctrine, semantics-testing
  strategies, golden-update protocol, definition of done).
- **Setting up the toolchain from scratch, or understanding `MISE_ENV`
  layering itself** — use `build-and-env`.
- **Running/building/serving/deploying the app** — use `run-and-operate`.

---

## Provenance and maintenance

Written 2026-07-02. Verified by reading the actual files and by running
commands live in this sandbox:

- Read directly: `mise-tasks/test.sh`, `mise-tasks/analyze.sh`,
  `mise-tasks/coverage.sh`, `mise-tasks/build/web/prod.sh`,
  `scripts/check-page.mjs`, `scripts/screenshot-batch.mjs`,
  `mise-tasks/test/check-page.sh`, `mise-tasks/screenshots/batch.sh`,
  `codecov.yml`, `analysis_options.yaml`, `playwright.config.ts`,
  `.github/workflows/ci.yml` (source-maps + playwright-report artifact
  blocks), `lib/main.dart` (Crashlytics wiring),
  `lib/services/analytics_service.dart`, `.gitignore`.
- Ran live: `./bin/mise run analyze lib/constants/`, `lib/utils/`;
  `./bin/mise run test test/constants/preference_keys_test.dart` (via
  `MISE_ENV=claude-code-web` sandbox fallback) — confirmed
  `TEST_LOG=`/`ANALYZE_LOG=` output format and grep hints; `flutter test
  --coverage test/constants/preference_keys_test.dart` +
  `scripts/lcov-summary.sh coverage/lcov.info` end-to-end; `./bin/mise doctor`,
  `env --json`, `ls --json`, `config ls --json`.
- Ran `node --check` on `decode-stack.mjs` and `bash -n` on
  `lcov-summary.sh` — both pass; scripts were already correct, no fixes
  needed.
- Confirmed via `find`: `.mise/http-tarballs/<hash>/packages/flutter/...`
  path exists. Confirmed via `grep`: no Cloudflare Web Analytics beacon
  anywhere under `web/`.

### Re-verification commands

| Fact | Re-check with |
|---|---|
| TEST_LOG/ANALYZE_LOG behavior unchanged | `cat mise-tasks/test.sh mise-tasks/analyze.sh` |
| Coverage thresholds unchanged | `cat codecov.yml` |
| build:web:prod still omits `--source-maps` | `cat mise-tasks/build/web/prod.sh` |
| CI dart-defines for source-map parity unchanged | `grep -A6 'flutter build web' .github/workflows/ci.yml` |
| `source-maps` / `playwright-report` artifact names unchanged | `grep -B2 -A4 'upload-artifact' .github/workflows/ci.yml` |
| Complexity-adjacent lint rules unchanged | `cat analysis_options.yaml` |
| Crashlytics fatal/non-fatal routing unchanged | `sed -n '30,60p' lib/main.dart` |
| Analytics production-gating unchanged | `grep -n isProduction lib/services/analytics_service.dart lib/services/environment_service.dart` |
| Helper scripts still parse | `node --check .claude/skills/diagnostics-and-tooling/scripts/decode-stack.mjs && bash -n .claude/skills/diagnostics-and-tooling/scripts/lcov-summary.sh` |
| Sandbox 403 workaround still needed | try a plain `./bin/mise run analyze lib/` in a fresh Claude Code Web session; if it no longer 403s, the `MISE_ENV=claude-code-web` prefix note can be retired |
