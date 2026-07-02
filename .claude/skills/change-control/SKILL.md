---
name: change-control
description: How changes are classified, gated, and reviewed in the Cambridge Beer Festival app. Load BEFORE committing, opening a PR, merging, deciding whether a change is allowed at all, or acting on a review comment. Triggers — "can I change X", "which CI checks run", "why did PR Lint fail", "should I fix this codecov comment", "is it safe to deploy now", "do I need an ADR", "rename the favorites route", "bump a dependency", "edit festivals.json", "the reviewer says this is wrong". Provides the change-classification→CI-gate map, the non-negotiable gates with the incident behind each, the Do-Not-Modify list, four maintainer-confirmed unwritten rules (URL contract, free-tier-only, festival freeze, untouchable upstream feeds), review-comment triage, issue/ADR discipline, and a pre-merge checklist.
---

# Change Control

This skill is the gatekeeper: what kind of change you are making, which gates
apply, and which changes are forbidden outright. Nothing in this repo routes
around it — every behavior change goes through `./bin/mise run check`, a
conventional commit, and a PR with green CI.

## 1. Classify the change first

CI is path-filtered (`dorny/paths-filter` in `.github/workflows/ci.yml:36-51`
and `.github/workflows/cloudflare-worker.yml:42-47`). What you touch determines
which gates fire.

| Class | Paths | CI jobs that fire | Extra rules |
|---|---|---|---|
| App code / UI | `lib/**`, `test/**`, `web/**`, `android/**`, `pubspec.yaml`, `test-e2e/**`, `package.json`, `playwright.config.ts`, `mise.toml` (the `app` filter) | `fmt`, `analyze`, `test` (+codecov upload), `build-web`, `test-e2e-web` (Playwright), `build-android`, `deploy-web-preview` (staging Pages + PR comment), `smoke-test-preview` (CSP against the deployed preview) | UI changes: incremental only — see skill `ui-and-accessibility` (redesigns are this project's costliest historical failure mode). Accessibility is mandatory (AGENTS.md). |
| Models + storage | subset of app code | same as app code | If a SharedPreferences key or on-disk format is involved → §2.5 (key pinning / migration). If `Drink`/`UserDrinkState` shape changes → run `./bin/mise run generate` for mocks. |
| Data (registry) | `data/festivals.json`, `scripts/**` | `cloudflare-worker.yml`: `validate-festivals` (Ajv schema check), `test-worker`, `validate-worker` (PR dry-run) — and on merge to main, `deploy-worker` **straight to production** (data.cambeerfestival.app) | Validate locally first: `./bin/mise run validate:festivals`. Merging to main IS a production deploy. Note: `docs/processes/festival-data-prs.md` is mislabeled — it's a My Festival feature PR/FAQ, not a data runbook; see skill `run-and-operate` for the real procedure. |
| cloudflare-worker | `cloudflare-worker/**` | same workflow: `test-worker` (vitest on workerd), `validate-worker` dry-run on PR, `deploy-worker` to production on main | On the Do-Not-Modify list (§3) — explicit request required. |
| functions (Pages Functions) | `functions/**` | `fmt`, `analyze`, `test` (includes `cd functions && npm test`) — but **not** `build-web`, so `deploy-web-preview` is transitively skipped (its `needs:` includes the skipped `build-web`) | Crawler-preview injection; tests use a mocked HTMLRewriter (real one not exercised — see skill `validation-and-qa`). |
| proto (API contract) | `proto/**` | `proto` job: `buf lint` + `buf breaking` against `main:proto` (bufbuild/buf-action, bypasses mise); `api-docs.yml` regenerates OpenAPI/Redoc | See skill `api-contract` for the full workflow and AIP fact table. Breaking-change rules: FILE+WIRE per `proto/buf.yaml`. |
| `.github/workflows/` | workflow files | editing `ci.yml` itself matches the `app` filter; `cloudflare-worker.yml` triggers its own workflow; other workflows (release chain, pr-lint) trigger **nothing** until they run for real | On the Do-Not-Modify list (§3). The release chain is fragile — see rationale. |
| Docs | `docs/**`, `*.md`, `.claude/**` | **no CI jobs** fire (no filter matches) — only `pr-lint` checks the PR title | Style and taxonomy: see skill `docs-and-writing`. |

Every PR regardless of class: `pr-lint.yml` (conventional-commit title check).

## 2. Non-negotiable gates — and the incident behind each

### 2.1 `./bin/mise run check` before every commit

`check` = format + analyze + test + shell:check, with codegen as a dependency
(`mise.toml:75-78`). Never raw `flutter` commands — mise pins Flutter 3.44.0
to match CI.

```bash
./bin/mise run check                      # full pre-commit gate
./bin/mise run --no-deps dart:format      # after every Dart edit (skips codegen)
```

**Why**: haiku-class agents doing mechanical substitutions repeatedly produced
formatting that CI's `fmt` job rejected (AGENTS.md "Lessons Learned"); and
skipping `generate` after model changes ships stale `.mocks.dart` that fails
`analyze`. One local run is cheaper than a failed CI round-trip.

### 2.2 Conventional commits + PR-title lint

Commits: `<type>(<scope>): <subject>` (`feat`, `fix`, `docs`, `style`,
`refactor`, `test`, `chore`). PR titles must also conform —
`.github/workflows/pr-lint.yml` runs `amannn/action-semantic-pull-request@v6`
and rejects non-conforming titles (skipped only for the `release/next` branch,
whose "Release X.Y.Z" titles are intentionally non-conventional).

**Why**: the release train is automated on top of commit messages.
`release-pr.yml` runs git-cliff over conventional commits to generate
CHANGELOG and release notes (`cliff.toml`, strict CalVer
`tag_pattern = "v[0-9]{4}\.[0-9]+\.[0-9]+"`). A non-conforming commit
silently vanishes from the changelog; a silently-empty release-notes
extraction once shipped notes-less releases (now fails loudly — CHANGELOG
2026.5.x era). Note `pr-lint` triggers on opened/edited/reopened only —
pushing commits does not re-run it; fix a red check by editing the PR title.

### 2.3 CI is ground truth

If `analyze` and `test` pass, a review comment claiming "this won't compile"
or "this type doesn't exist" is **wrong** — skip it, don't act on it
(AGENTS.md "CI and Coverage").

**Why**: automated reviewers repeatedly proposed incorrect fixes — e.g.
claiming `dart:io` exceptions lack `const` constructors, or proposing
duplicate `etag` fields the api-linter rejects. The AGENTS.md
"Dart / Flutter Type Facts" and "Proto / AIP Design Facts" sections exist
specifically to refute these. See §6 for the triage protocol.

### 2.4 Codecov policy

`codecov.yml`: project **and** patch targets are 70% with 1% threshold. The
CI upload uses `fail_ci_if_error: false` (`ci.yml:173`) — upload failures
never block.

Blocking rule: **only a failing `codecov/patch` status check blocks a merge.**
Codecov PR *comments* noting a drop are informational. Pure refactors inherit
prior coverage — moved code that was untested before is not a new gap; do not
add tests solely to satisfy a coverage comment on unchanged logic.

**Why**: coverage gating was deliberately moved from report-lcov to codecov
(PR #303) with this exact policy to stop coverage noise from driving
make-work test additions.

### 2.5 Preference-key pinning (changing a key value = data migration)

Every SharedPreferences key lives in `lib/constants/preference_keys.dart`;
every value is pinned by `test/constants/preference_keys_test.dart` (which
also asserts uniqueness). Never use an inline key string. Changing an
existing key's **value** orphans all data stored under the old key — that is
a data migration, not a rename; the pinned test fails to force a deliberate
decision. The shipped example: the one-time legacy migration
(`personal_state_migration_v1`) that folded `favorites`/`ratings`/
`tasting_log_` keys into unified `user_state_` records.

**Why**: a mistyped key reads back `null` and silently loses user data
(centralised by PR #356). Note doc drift: AGENTS.md still names
`FavoritesService`/`RatingsService`/`TastingLogService` — those were unified
into `UserDataStore` (`lib/services/user_data_store.dart`); trust the code.

## 3. The Do-Not-Modify list (AGENTS.md §Do Not Modify)

| Path | Rule | Rationale |
|---|---|---|
| `.github/workflows/` | Only on explicit user request | The release chain is a house of cards tuned around GitHub quirks: GITHUB_TOKEN-created events don't trigger downstream workflows (hence `workflow_dispatch` chaining in `release.yml`), CI deliberately skips the release PR, caching strategy is an accepted ADR (0001/0002). Casual edits break releases in ways only visible at the next release. |
| `cloudflare-worker/` | Only on explicit user request | It is the production data proxy at `data.cambeerfestival.app` — every app install depends on it, and a merge to main deploys it to production immediately (§1). |
| `pubspec.yaml` package versions | Only when genuinely necessary | Version bumps have global blast radius: the Flutter 3.38→3.44 upgrade (PR #384) surfaced a release-only router crash (#386) that took a source-map investigation to decode. |
| `analysis_options.yaml` | Never | The lint baseline is the enforced house style; loosening it invalidates the "CI is ground truth" gate, and tightening it creates repo-wide churn. Change requires a deliberate maintainer decision. |

## 4. The four unwritten rules (maintainer-confirmed; no repo doc states them — this skill is their home)

### Rule 1 — URLs and deep links are a public contract

Never break an existing route path. The route table is `lib/router.dart`;
ADR 0004 chose path-based festival-scoped URLs precisely so links are
shareable — which makes them permanent.

Concretely forbidden: renaming `/:festivalId/favorites` as part of the
"My Festival" rename. Issue #414 states it verbatim: *"Keep the route URL as
`/:festivalId/favorites` — changing it breaks existing deep links and
bookmarks."* The screen class, nav label, and icon all change; the URL does
not. If a URL genuinely must move, ship a redirect (pattern:
`web/_redirects` already 302s the old `/{festival}/drink/{id}` form) and
keep the old path serving indefinitely.

### Rule 2 — Free-tier / low-ops only

Nothing that needs a paid tier or babysitting during festival week. Boring
beats clever. Concretely forbidden: paid CI runners or device farms (ADR
0005 rejected Firebase Test Lab partly over cost and its 15-tests/day free
cap), services requiring manual restarts/rotation, anything with a
per-request bill that spikes when 40,000 visitors open the app. The whole
stack — Cloudflare Pages/Worker/D1, GitHub Actions, Firebase Analytics —
runs on free tiers today; keep it that way.

**Why**: festival-week economics. The team is one maintainer; during the
festival there is no ops capacity, and the app's entire value is
concentrated into six days a year.

### Rule 3 — No risky deploys near or during a live festival

See §5 for the freeze protocol.

### Rule 4 — Upstream CAMRA data feeds are untouchable

CAMRA (Campaign for Real Ale) volunteers publish the drink data the app
consumes via `data.cambridgebeerfestival.com`. The app absorbs whatever they
emit. Concretely forbidden: a fix strategy of "ask upstream to clean the
data", code that assumes a field's type or vocabulary is stable, or
rejecting a whole feed because one record is malformed. The codified
consequences: parse every field defensively with type variants
(`lib/models/drink.dart` — abv as num|String, allergens as int|bool|num),
skip malformed entries rather than crash the batch (#273), and map free-text
status by exact match with an explicit `unknown` fallback (#348 — substring
matching mis-bucketed ~32% of statuses; vocabulary changed between
festivals). See skill `reference` for the feed-reality details.

**Also from the maintainer**: the costliest historical failure mode is UI
redesigns — visual churn and cascading widget-tree restructures. Change
control implication: no drive-by restyling inside functional PRs; UI changes
are incremental and scoped. See skill `ui-and-accessibility`.

## 5. Festival freeze

Check whether a festival is live or imminent before any deploy-affecting
merge:

```bash
jq -r '.festivals[] | "\(.id)\t\(.start_date)..\(.end_date)\tactive=\(.is_active)"' data/festivals.json
```

Compare against today's date. `is_active: true` marks the current/next
festival; `Festival.isLive()/isUpcoming()` in `lib/models/festival.dart:150-181`
implement the same date logic in-app.

**Freeze window** (this skill's codification of maintainer rule 3; no repo
doc defines the exact span): from **14 days before `start_date` through
`end_date`** of any festival, treat the project as frozen.

| During freeze | Allowed? |
|---|---|
| `data/festivals.json` corrections (hours, charity link, beverage types) | Yes — this is what festival week needs; schema-validated and worker-tested. Still runs the full `cloudflare-worker.yml` gate. |
| Critical user-facing bug fix (app unusable / wrong data shown) | Yes — full gates, smallest possible diff, watch the deploy land. |
| Docs, issues, planning | Yes — no deploy surface. |
| UI changes, refactors, new features | No — merge to main deploys to staging and moves the release train forward. Park on a branch. |
| Dependency / Flutter / toolchain bumps | No. |
| Worker, proto/API, release-workflow changes | No. |
| Cutting a release (merging `release/next`) | Only if it carries a critical fix; otherwise wait. |

Rationale: a broken deploy during the festival cannot be fixed at leisure —
it fails in front of the entire yearly audience, on mobile data, with one
maintainer who is probably on-site.

## 6. Review-comment triage protocol

For each automated or human review comment, decide **act / skip / refute**:

| Signal | Action |
|---|---|
| Comment contradicts passing CI ("won't compile", "type error", "missing import") | **Skip.** CI is ground truth (§2.3). |
| Codecov comment (coverage drop, uncovered lines) with `codecov/patch` check green | **Skip.** Informational only (§2.4). |
| Coverage comment on a pure refactor (moved, unchanged logic) | **Skip.** Refactors inherit prior coverage. |
| Proposed proto fix that would require suppressing an api-linter rule | **Strong signal the fix is wrong.** Check the AIP fact table in skill `api-contract` (etag/OUTPUT_ONLY, soft-delete returns resource, `type` vs `child_type`, batch statuses, `optional` signal fields) before acting. |
| Claim about Dart/Flutter type behavior | Check the "Dart / Flutter Type Facts" list in AGENTS.md (const exception constructors, `TlsException` subtyping, conditional-import stubs stay out of barrels) — and skill `reference` for the glossary. |
| Comment proposes breaking a route URL, a preference-key value, or an upstream-feed assumption | **Refute** citing §4 / §2.5 — reply on the thread so the refutation is recorded. |
| Correct, in-scope finding (real bug, missing edge case, a11y gap) | **Act.** Fix, re-run `./bin/mise run check`, push. |
| Correct but out-of-scope finding | **File an issue** (§7) and link it from the thread; don't scope-creep the PR. |

Uncertain whether a comment is right? Prove it wrong or right with a small
experiment — see skill `proof-and-analysis-toolkit` (review-comment
refutation recipe).

## 7. Issue discipline

GitHub Issues is the single source of truth
(`https://github.com/richardthe3rd/cambridge-beer-festival-app/issues`).
`docs/todos.md` is archived — never add to it.

- **Before starting work**: check open issues; many carry triage comments
  with exact file:line, root cause, and a recommended fix.
- **On discovering a bug/improvement**: file an issue, don't fix drive-by.
  A good issue has a plain-language title (no `fix:` prefix — that's for
  commits), root cause with file + line, a concrete fix approach, and labels:
  `bug` or `enhancement` plus one of `priority:high` (real user impact or
  data correctness — fix next), `priority:medium` (fix soon), `priority:low`
  (backlog).
- **In commits/PRs**: reference the issue in the body/description —
  `Fixes #123` / `Closes #123` — so the merge auto-closes it and links fix
  to context permanently.

## 8. ADR vs planning doc vs plain PR

| Vehicle | When | Where / how |
|---|---|---|
| **ADR** (Architecture Decision Record) | A cross-cutting technical direction with real alternatives that someone might later try to reverse: CI/caching strategy, URL scheme, E2E approach. If you rejected an option somebody will re-propose, write it down. | `docs/adr/NNNN-title.md`, sequential number, sections Status/Date/Context/Decision/Consequences, update the index in `docs/adr/README.md`. Five exist (0001–0005). |
| **Planning doc** | A multi-issue, multi-PR campaign needing a shared vision before issues can be cut — e.g. `docs/planning/my-festival/vision.md` driving issues #411–#415. | `docs/planning/<feature>/`; move to `docs/planning/archive/` when done or abandoned (the abandoned Patrol/Firebase plan lives there as a warning). Planning docs go stale — issues supersede them (the my-festival phase-1 doc was superseded by #390). |
| **Plain PR** | Everything else: bug fixes, single features, refactors, data updates. | Branch → `./bin/mise run check` → conventional commit → PR titled conventionally → green CI → merge. |

Style rules for all written docs: skill `docs-and-writing`.

## 9. Pre-merge checklist

| # | Check | How |
|---|---|---|
| 1 | Change classified; you know which CI jobs will fire | §1 table |
| 2 | Not on the Do-Not-Modify list (or explicit user request in hand) | §3 |
| 3 | No route URL, preference-key value, or public contract broken | §4.1, §2.5 |
| 4 | Festival freeze checked | §5 `jq` one-liner |
| 5 | `./bin/mise run check` passes locally | §2.1 |
| 6 | Only planned files changed | `git diff main...HEAD --stat` (subagent work: diff against the merge-base) |
| 7 | Commit messages + PR title conventional | §2.2 |
| 8 | Issue referenced (`Fixes #N`) | §7 |
| 9 | New interactive UI has `Semantics` + a semantic test | AGENTS.md §Accessibility; skill `ui-and-accessibility` |
| 10 | Data change validated (`./bin/mise run validate:festivals`) and you accept that merge = production deploy | §1 data row |
| 11 | Review comments triaged (acted / skipped / refuted / filed) | §6 |
| 12 | All CI checks green — including `codecov/patch` status (not the comment) | §2.3, §2.4 |

## When NOT to use this skill

- **Diagnosing a failure or crash** → skill `debugging-playbook` (symptom
  triage) and `failure-archaeology` (has this been fought before?).
- **Running, building, serving, deploying** → skill `run-and-operate`
  (includes the festival-data update and release-train runbooks).
- **Writing or restructuring docs/ADR prose** → skill `docs-and-writing`
  (this skill only says *when* an ADR is required).
- **Proto/API design questions** → skill `api-contract`.
- **Test strategy / what counts as evidence** → skill `validation-and-qa`.
- **Environment setup problems** → skill `build-and-env`.

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at
`/home/user/cambridge-beer-festival-app` (shallow clone), AGENTS.md, GitHub
issue #414 (fetched live), and `data/festivals.json`. The 14-day freeze
window in §5 and the freeze allowed/forbidden table are this skill's
codification of a maintainer-confirmed verbal rule — no repo doc defines the
span; adjust here if the maintainer states a different one.

Re-verification one-liners (run from the repo root):

```bash
# CI path filters and job wiring
grep -n -A16 'paths-filter' .github/workflows/ci.yml | head -30
grep -n 'paths:' -A6 .github/workflows/cloudflare-worker.yml
# PR-title lint + release/next exemption
grep -n 'release/next\|semantic-pull-request' .github/workflows/pr-lint.yml
# Codecov targets
cat codecov.yml
grep -n 'fail_ci_if_error' .github/workflows/ci.yml
# check task composition
grep -n -A3 '\[tasks.check\]' mise.toml
# Do-Not-Modify list
grep -n -A6 'Do Not Modify' AGENTS.md
# Preference-key pinning
grep -n 'expect(PreferenceKeys' test/constants/preference_keys_test.dart
# Route table (URL contract)
grep -n "path: '" lib/router.dart
# URL rule source
# → https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/414 ("Keep the route URL")
# Festival dates / freeze
jq -r '.festivals[] | "\(.id)\t\(.start_date)..\(.end_date)\tactive=\(.is_active)"' data/festivals.json
# Changelog automation depends on conventional commits
grep -n 'tag_pattern' cliff.toml
# ADR index
grep -n '^| \[' docs/adr/README.md
```
