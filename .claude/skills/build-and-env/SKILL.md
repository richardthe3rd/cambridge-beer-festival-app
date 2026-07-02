---
name: build-and-env
description: Recreate and troubleshoot the Cambridge Beer Festival app's toolchain — mise self-bootstrap, environment layering (base/dev/human/claude-code-web), install failures, task introspection, CI-vs-local parity, and every environment-variable/config axis (MISE_ENV, dart-defines, TEST_LOG/ANALYZE_LOG, wrangler vars, BASE_URL). Load when the ask is "set up this repo from scratch", "flutter/mise install fails", "why did `./bin/mise run X` fail while installing tools", "403 / GitHub rate limit / libgit2 transport error", "what does MISE_ENV do here", "where is task X actually defined", "why does the CI build differ from my local build", "add a new mise task or tool", or "why did my Write come back reformatted". Does NOT cover running/serving/deploying the app (see `run-and-operate`) or test methodology (see `validation-and-qa`).
---

# Build and Environment

This repo's entire toolchain is driven by **mise**, bootstrapped by a single
committed script. There is no "install Flutter yourself" path — `./bin/mise`
is the only supported entrypoint, and every fact below was verified against
the working tree on 2026-07-02 (see Provenance).

## 1. From-scratch recreation

`./bin/mise` (`bin/mise:1-345`) is a self-contained bootstrap script, not a
thin wrapper around a pre-installed `mise` binary:

- Pins `MISE_INSTALL_PATH="$project_dir/.mise/mise-2026.5.8"` and redirects
  every mise data/config/cache/state directory under `.mise/` (`bin/mise:6-11`)
  — nothing touches `$HOME/.config/mise` (explicitly ignored, line 13) or a
  system-wide mise install. The project is marked trusted automatically
  (`MISE_TRUSTED_CONFIG_PATHS`, line 12).
- If `.mise/mise-2026.5.8` doesn't exist, it downloads the matching
  OS/arch tarball from GitHub releases (or `mise.en.dev` mirror) and verifies
  it against a **hardcoded SHA256 checksum table** baked into the script
  (`bin/mise:134-149`) before extracting — not just a checksum fetched from
  the same untrusted source.
- Then it `exec`s straight into the freshly-installed (or already-present)
  binary with all your original arguments (`bin/mise:345`).

**Never run raw `flutter`, `dart`, `npm`, etc.** — they may resolve to a
different version than CI. Always `./bin/mise run <task>` or
`./bin/mise exec -- <cmd>`.

### First-run sequence

```bash
./bin/mise run check &      # background: generate → format + analyze + test + shell:check
```

`check`'s dependency chain (`mise.toml:75-78`) forces, as a side effect:
1. `[deps.flutter] auto=true` (`mise.toml:24-25`) — first `flutter`-touching
   task triggers `flutter pub get` automatically.
2. `generate` — `dart run build_runner build --delete-conflicting-outputs`,
   producing `.mocks.dart` files consumed by `analyze`/`test`.
3. `flutter analyze --no-fatal-infos` and `flutter test`.

Installation of `flutter=3.44.0`, `node=22`, `shellcheck=0.9.0`, `shfmt=3.8.0`
(`mise.toml:18-22`) happens transparently the first time any task needs them —
there is no separate `mise install` step required, though `./bin/mise install`
works too and is what the SessionStart hook runs (§3c). If `check` fails on a
fresh machine due to missing system deps or no network for dev tools, fall
back to `./bin/mise deps &` to just fetch pub dependencies.

## 2. Environment layering

mise supports multiple environment files layered by `MISE_ENV`. This repo
uses four, plus a Tera-templated auto-selector:

| File | Selected by | Tools / tasks it adds | Audience |
|---|---|---|---|
| `mise.toml` | always (base) | `flutter=3.44.0`, `node=22`, `shellcheck=0.9.0`, `shfmt=3.8.0`; tasks: `generate`, `dart:format*`, `prettier:*`, `fmt:check`, `mise:format`, `format`, `check`, `goldens:update`, `validate:festivals`, `test:worker`, `analyze`, `test`, `coverage` | CI and everyone |
| `mise.dev.toml` | `MISE_ENV=dev` | `watchexec=2.5.1`, `buf=latest`, `github:googleapis/api-linter=latest`; tasks: all `proto:*`, plus file-tasks in `mise-tasks/` — `dev`, `dev:tunnel`, `build:web`, `build:web:prod`, `serve:release`, `test:e2e*`, `setup:playwright`, `setup:tunnel`, `screenshots:batch`, `test:check-page` | Building/running/proto work |
| `mise.human.toml` | `MISE_ENV=dev,human` | `claude`, `cloudflared`, `gh`, `npm:firebase-tools` | Human machines only — never load on an agent |
| `mise.claude-code-web.toml` | `.miserc.toml` auto-select, or explicit `MISE_ENV=claude-code-web` | `[settings] libgit2=false, gix=false` (git-transport fix, §3b); `node=path:/opt/node22`, `python=path:/usr`, `jq=path:/usr` (reuse sandbox-baked binaries instead of downloading) | Claude Code Web sandbox only |

`.miserc.toml` runs **before** any `mise.<env>.toml` and decides which `env`
list applies via Tera templating over OS-level context:

```toml
{% if env.CLAUDE_CODE_REMOTE | default(value='') == 'true' %}
env = ["claude-code-web", "dev"]
{% endif %}
```

So on Claude Code Web, a bare `./bin/mise ...` already resolves to
`claude-code-web` + `dev` — you get proto/e2e/build tasks with **no**
`MISE_ENV=dev` needed. Off the sandbox (`CLAUDE_CODE_REMOTE` unset), the
condition is false and `env` is omitted — you're on base only, and dev tasks
need `MISE_ENV=dev` explicitly per AGENTS.md.

**The trap**: `.miserc.toml:11-13` says explicitly — *an explicit `MISE_ENV`
environment variable overrides `.miserc.toml` entirely.* If you (or a shell
profile, or a CI step) sets `MISE_ENV=dev` on Claude Code Web, you silently
**lose** the `claude-code-web` fixups (git-transport settings, baked
node/python/jq paths) because `.miserc.toml`'s conditional never fires when
`MISE_ENV` is already set from outside. To combine both deliberately, spell
out `MISE_ENV=claude-code-web,dev`.

## 3. Known install traps (dated)

### (a) Web-sandbox proxy 403 on GitHub release downloads — verified 2026-07-02

The agent proxy in this sandbox returns 403 for direct GitHub release-asset
downloads. `buf`, `watchexec`, and `github:googleapis/api-linter` are all
installed via aqua/GitHub-release backends (`mise.dev.toml:18-26`), so the
**first** task that needs any of them fails mid-install — and because
`.miserc.toml` auto-selects `dev` on Claude Code Web, this means **any**
`./bin/mise run <task>` can trip it, even for a task that itself doesn't need
those tools, if mise decides to resolve/install the full active toolset.
Reproduced live in this session:

```
mise buf@1.70.0  [1/3] download buf-Linux-x86_64.tar.gz
mise WARN  GitHub API returned a 403 Forbidden error...
mise ERROR Failed to install tools: aqua:bufbuild/buf@latest, aqua:watchexec/watchexec@2.5.1, ...
```

**Workaround** (verified working live in this session):

```bash
MISE_ENV=claude-code-web ./bin/mise run analyze lib/models/   # base tasks only
MISE_ENV=claude-code-web ./bin/mise run test test/domain/     # test/analyze/generate/check all work
```

This explicit `MISE_ENV` shadows `.miserc.toml`'s auto-`dev` selection (§2
trap), so mise never tries to resolve `buf`/`watchexec`/`api-linter` — you
keep the `claude-code-web` git-transport fix but drop `dev`. **Proto and e2e
tasks will NOT work** under this workaround (they need the dev-only tools);
there is no fallback for those in this sandbox besides fixing the proxy. This
is a session/sandbox-specific condition — it may not reproduce in other
environments or after the proxy allowlist changes; re-test before trusting it
stale.

### (b) libgit2 / gix git-transport errors

`mise.claude-code-web.toml` sets `[settings] libgit2 = false, gix = false`.
Without this, Flutter SDK installation (which mise fetches via a git clone)
can fail with "Failed to configure the transport" errors in this sandbox —
the setting forces mise to fall back to shelling out to the system `git`
instead of its bundled git backends. This only applies when the
`claude-code-web` env is active; off-sandbox this isn't needed.

### (c) SessionStart hook behavior

`.claude/hooks/session-start.sh` runs only when `CLAUDE_CODE_REMOTE=true`
(otherwise exits 0 immediately). It emits `{"async": true, "asyncTimeout":
300000}` so Claude Code doesn't block the session waiting on it, then:

```bash
./bin/mise install        # installs flutter/node/shellcheck/shfmt (+ dev-env tools if selected)
./bin/mise run generate   # flutter pub get (via [deps.flutter] auto=true) + build_runner
```

Both run in the background with a 5-minute timeout. This is why, per
AGENTS.md's "Session Startup" instruction, you can start reading code and
planning immediately — by the time you need Flutter, install has usually
finished. Note `./bin/mise install` here is a **plain** invocation (no
`MISE_ENV=dev`), so it's also subject to the trap in (a): if it hits the 403,
dev-only tools (buf/watchexec/api-linter) simply won't be installed, but
`flutter`/`node`/`shellcheck`/`shfmt` (base) usually still succeed since
they're fetched from different backends (Flutter via git/archive, not a
GitHub release asset gated the same way).

## 4. Introspection

Discover tasks and config before guessing:

```bash
./bin/mise tasks ls                    # human-readable task list
./bin/mise tasks ls --json             # name, description, source, depends, file
./bin/mise ls --json                   # installed tools, versions, install paths, which config file requested them
./bin/mise config ls --json            # which mise.*.toml files are active and what tools each requests
./bin/mise env --json                  # resolved PATH and env vars for the active environment
```

**Finding a task's real definition**: `./bin/mise tasks ls --json` includes a
`"source"` (and for file-tasks, `"file"`) field pointing at the exact file.
Two shapes exist:
- **Inline** in `mise.toml`/`mise.dev.toml` under `[tasks."name"]` — e.g.
  `analyze` used to look like this; check there first for simple `run =`
  one-liners.
- **File-task** under `mise-tasks/` (dir structure mirrors the task's `:`
  segments — `mise-tasks/build/web/prod.sh` is task `build:web:prod`). These
  carry a `#MISE description="..."` / `#MISE depends=[...]` header comment
  instead of TOML, and are shellcheck+shfmt-enforced (`shell:check`,
  `shell:format-check` tasks lint every `*.sh` in the repo, not just
  `mise-tasks/`).

Currently every task under `analyze`, `test`, `coverage`, `dev`,
`dev:tunnel`, `build:web`, `build:web:prod`, `serve:release`,
`screenshots:batch`, `test:check-page`, `test:e2e*`, `setup:playwright`,
`setup:tunnel`, `shell:*` is a file-task in `mise-tasks/`; everything else
(`generate`, `dart:format*`, `prettier:*`, `fmt:check`, `mise:format`,
`format`, `check`, `goldens:update`, `validate:festivals`, `test:worker`,
`proto:*`) is inline TOML.

## 5. CI ↔ mise parity

| CI step (`.github/workflows/ci.yml`) | Mise equivalent | Divergence |
|---|---|---|
| `flutter pub get` | automatic (`[deps.flutter] auto=true`) | none |
| `dart run build_runner build --delete-conflicting-outputs` | `./bin/mise run generate` | none |
| `flutter analyze --no-fatal-infos` | `./bin/mise run analyze` | none |
| `flutter test --coverage` | `./bin/mise run coverage` | none |
| `flutter test` | `./bin/mise run test` | none |
| `flutter build web --release --base-href "/" --source-maps` + 5 `--dart-define`s | `MISE_ENV=dev ./bin/mise run build:web:prod` | **mise's `build:web:prod` (`mise-tasks/build/web/prod.sh`) does NOT pass `--source-maps`** — CI adds it, builds, then strips the `.map` file into a separate artifact before uploading the web build. Run the `flutter build web ... --source-maps` command by hand (see AGENTS.md "Debugging Flutter Web Crashes") when you need a local source map. |
| `buf lint` + `buf breaking` | *(no mise equivalent used in CI)* | `ci.yml`'s `proto` job uses `bufbuild/buf-action@v1` directly, bypassing mise entirely. `./bin/mise run proto:lint`/`proto:api-lint` (dev-only, `mise.dev.toml`) exist for local use but are not what CI runs. |
| — | `MISE_ENV=dev ./bin/mise run build:web` | Local-only convenience (no version dart-defines) for e2e testing; not a CI step. |

Also: CI's `build-android` job builds `--release` but is **debug-signed on
purpose** on PRs (to exercise R8 without real signing secrets); only
`release-android.yml` does real Play Store signing. That's an Android
signing divergence, not a mise one — see `run-and-operate` for the release
train.

## 6. Configuration axes catalog

| Axis | Default | Who reads it | Prod vs dev |
|---|---|---|---|
| `MISE_ENV` | unset (base only) off-sandbox; `claude-code-web,dev` auto-selected via `.miserc.toml` on Claude Code Web | mise itself, every `MISE_ENV=dev ./bin/mise ...` invocation in docs/CI | CI never sets it (base only — matches production build path minus dart-defines source-maps flag); dev machines/agents set `dev` explicitly for build/proto/e2e |
| `GIT_TAG`, `GIT_COMMIT`, `GIT_BRANCH`, `BUILD_VERSION`, `BUILD_TIME` | computed fresh each invocation from `git describe`/`git rev-parse`/`date` (`scripts/get_version_info.sh`); `GIT_TAG` empty and `BUILD_VERSION` falls back to `pubspec version+git.<sha>` off an exact tag | `mise-tasks/build/web/prod.sh` (`export` mode, `eval`'d) and `.github/workflows/*.yml` (`github` mode, written to `$GITHUB_OUTPUT`); consumed as Flutter `--dart-define`s, read at runtime in-app (e.g. About screen / EnvironmentBadge) | Dev builds via `build:web` skip all 5 (no version info); prod builds (`build:web:prod`, `release-web.yml`) always inject them |
| `TEST_LOG` / `ANALYZE_LOG` | `mktemp /tmp/test-XXXXXX.log` / `/tmp/analyze-XXXXXX.log` per run (`mise-tasks/test.sh:6`, `mise-tasks/analyze.sh:6`) | the `test`/`analyze` file-tasks themselves (tee output, preserve exit code via `${PIPESTATUS[0]}`) | Same on both; override to a stable path when you need to grep the same log across multiple invocations without re-running |
| `ENVIRONMENT` (wrangler `[vars]`) | `"production"` (`cloudflare-worker/wrangler.toml:6-7`) | Worker code (`worker.js`/`shared.ts`) for any environment-conditional behavior | Only one value committed — there's no separate staging `[vars]` block in `wrangler.toml`; staging behavior is driven by **origin-based** CORS/bucket logic instead (below), not this var |
| `RATINGS_BUCKET` (env override) | unset — falls back to `resolveBucket(origin, env)` (`cloudflare-worker/shared.ts:23-27`): `origin === "https://cambeerfestival.app"` → `"prod"`, else `"test"` | `shared.ts` bucket resolution for the D1 `reviews` table's composite key | Not set anywhere in committed config today; it's an escape hatch for forcing a bucket regardless of request origin. Do not set it in production without understanding it silently overrides the origin check |
| `RATINGS_DB` (D1 binding, not an env var) | `[[d1_databases]] binding = "RATINGS_DB"`, `database_id = "00000000-0000-0000-0000-000000000000"` **placeholder** (`wrangler.toml:20-25`) | `reviews.ts` via `env.RATINGS_DB`; missing/misconfigured → worker returns 503 `STORAGE_UNCONFIGURED` | Tests/local dev use wrangler's simulated local D1 (id ignored); a real deploy needs `wrangler d1 create cbf-myfestival` + paste the real id + `wrangler d1 migrations apply` — see `run-and-operate` for the provisioning runbook |
| `BASE_URL` (Playwright) | `"http://127.0.0.1:8080"` (`playwright.config.ts:34`) | `test-e2e/*.spec.ts` via `page.goto`/`baseURL` | Local/CI default targets a locally-served build; CI's `smoke-test-preview` job sets `BASE_URL=<Cloudflare Pages preview URL>` to run `csp-smoke.spec.ts` against a real deployed CSP policy — the only place that check is meaningful (`web/_headers` CSP isn't exercised any other way) |

## 7. Adding a tool or task correctly

**New tool**: add to the right `[tools]` table by audience — `mise.toml` if
CI needs it too, `mise.dev.toml` if it's build/proto/e2e-only, `mise.human.toml`
if it's a human-only convenience (never loaded on an agent). Run
`./bin/mise run mise:format` (or let the PostToolUse hook do it, §8) after
editing any `mise*.toml` file — it runs `mise fmt` to keep formatting
canonical, and CI's `fmt` job would otherwise flag drift.

**New task**:
- Simple one-liner with no args → inline `[tasks."name"]` block in `mise.toml`
  or `mise.dev.toml` (`run = '...'`, optional `depends = [...]`, `sources`/
  `outputs` for caching).
- Anything with real shell logic, or arguments → a file-task under
  `mise-tasks/` (path segments map to `:` in the task name — a task
  `foo:bar` lives at `mise-tasks/foo/bar.sh`). Required header:
  ```bash
  #!/usr/bin/env bash
  #MISE description="..."
  #MISE depends=["generate"]   # optional
  set -euo pipefail
  ```
  Argument parsing uses mise's `usage` KDL syntax turned into `$usage_<name>`
  env vars (see `goldens:update`'s `usage = 'arg "[file]" ...'` in `mise.toml`
  for the inline-task pattern, or add a `#MISE usage=...` header for a
  file-task).
- **Gate**: any `*.sh` file anywhere in the repo (not just `mise-tasks/`) is
  linted by `./bin/mise run shell:check` (shellcheck) and
  `./bin/mise run shell:format-check` (`shfmt -d`); `check` runs both
  transitively. A new file-task that fails shellcheck or isn't
  `shfmt`-formatted breaks the pre-commit gate and CI's `fmt` job.

## 8. Format-on-write hooks

`.claude/settings.json`'s `PostToolUse` hooks fire on every `Write`/`Edit`
tool call and auto-format based on the file extension touched
(`.claude/settings.json:55-81`):

| Extension | Runs | Task |
|---|---|---|
| `*.dart` | `./bin/mise run dart:format:fast` | no codegen, fast path |
| `*.js`/`*.ts`/`*.mjs` | `./bin/mise run prettier:format:fast` | no `npm ci`, fast path |
| `*.sh` | `./bin/mise run shell:format` | `shfmt -w -i 0 -ci` |
| `mise*.toml` | `./bin/mise run mise:format` | `mise fmt` |
| `*.proto` | `MISE_ENV=dev ./bin/mise run proto:format` | needs `buf` — dev env explicit here since the hook doesn't rely on `.miserc.toml` auto-selection |

Each hook command is best-effort (`|| true`) and silenced (`>/dev/null
2>&1`) — a formatter failure never blocks the tool call, but it also means
**a file you just wrote may come back slightly different on the next Read**
(reformatted quotes, indentation, etc.) even though you didn't touch it
again. This is expected; don't re-diff against your own Write output as if
it were unformatted — check the file, not your draft, when verifying a
change landed correctly. The proto hook is the one exception that needs
dev tools and can hit the §3a trap if `buf` isn't already installed.

## When NOT to use this skill

- **Running the dev server, building for real, deploying (Pages/Worker/D1/
  Android/release train)** → skill `run-and-operate`.
- **Test methodology — what counts as evidence, golden files, TDD workflow,
  worker/e2e test recipes** → skill `validation-and-qa`.
- **Deciding whether a change is allowed, which CI *gates* (not just tasks)
  apply, Do-Not-Modify list** → skill `change-control`.
- **Diagnosing a specific runtime bug/crash** → skill `debugging-playbook`.

## Provenance and maintenance

Written 2026-07-02. Verified by reading `bin/mise`, `.miserc.toml`,
`mise.toml`, `mise.dev.toml`, `mise.human.toml`, `mise.claude-code-web.toml`,
`.claude/hooks/session-start.sh`, `.claude/settings.json`,
`cloudflare-worker/wrangler.toml`, `cloudflare-worker/shared.ts`,
`scripts/get_version_info.sh`, `playwright.config.ts`, and every file under
`mise-tasks/`. The §3a 403 trap and its `MISE_ENV=claude-code-web`
workaround were reproduced live in this session, not inferred — command
output is quoted verbatim above.

Re-verification one-liners:

```bash
# Environment layering + auto-selection
cat .miserc.toml
./bin/mise config ls --json

# What's actually installed vs pending
./bin/mise ls --json

# Task inventory and where each is really defined
./bin/mise tasks ls --json | jq -r '.[] | "\(.name)\t\(.source // .file)"'

# Reproduce (or confirm fixed) the sandbox 403 trap
./bin/mise run proto:lint            # expect 403 if trap still live
MISE_ENV=claude-code-web ./bin/mise run analyze lib/          # expect success

# CI's actual web-build command (for the --source-maps divergence)
grep -n 'flutter build web' .github/workflows/ci.yml mise-tasks/build/web/prod.sh mise-tasks/build/web.sh

# Confirm proto CI bypasses mise
grep -n -A5 'proto:' .github/workflows/ci.yml | head -20

# Wrangler vars/bindings
cat cloudflare-worker/wrangler.toml
grep -n 'RATINGS_BUCKET\|resolveBucket' cloudflare-worker/shared.ts

# Playwright BASE_URL
grep -n 'BASE_URL' playwright.config.ts .github/workflows/ci.yml

# Format-on-write hook wiring
cat .claude/settings.json
```
