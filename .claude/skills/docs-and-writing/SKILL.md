---
name: docs-and-writing
description: Maintaining the docs of record and all user/reader-facing prose in the Cambridge Beer Festival app — docs/ taxonomy and lifecycle, ADR house style and when one is required, GitHub Issue house style (title/root-cause/labels), commit and PR message format, completion-summary rules, known doc drift to fix or file, and external positioning (what's actually public, and claim discipline). Load BEFORE writing or editing anything under docs/, opening a GitHub issue, writing a commit message or PR description/title, writing an ADR, archiving a planning doc, or drafting any completion summary. Triggers — "where does this doc go", "do I need an ADR for this", "write a good issue for this bug", "what should the commit message say", "is docs/README.md up to date", "this doc looks wrong/stale", "can I say this is WCAG compliant / production-ready", "will this show up in the changelog".
---

# Docs and Writing

This skill governs every piece of writing this project keeps as a record:
`docs/`, ADRs, GitHub Issues, commit messages, PR titles/descriptions, and
completion summaries. If you are about to create a `.md` file, file an issue,
or write a commit message, read this first — there is one home for each kind
of fact, and conventions here feed automated systems (changelog generation,
PR-title CI gate) that silently misbehave if you improvise.

## 1. The docs-of-record taxonomy

`docs/` has five top-level categories, indexed in `docs/README.md`. Each
answers a different question:

| Directory | Question it answers | Example |
|---|---|---|
| `docs/code/` | "How does this work **right now**?" | `docs/code/routing.md`, `docs/code/accessibility.md`, `docs/code/domain-architecture.md` |
| `docs/adr/` | "**Why** did we decide this, and what did we reject?" | `docs/adr/0004-path-based-url-strategy.md` |
| `docs/processes/` | "What's the repeatable **procedure**?" | `docs/processes/ci-cd.md`, `docs/processes/release.md` |
| `docs/tooling/` | "How do I **set up** this piece of infrastructure?" | `docs/tooling/cloudflare-pages.md`, `docs/tooling/firebase.md` |
| `docs/planning/` | "What are we **proposing** to build?" (not yet decided/shipped) | `docs/planning/my-festival/vision.md`, `docs/planning/rating-service/design.md` |
| `docs/planning/archive/` | "What did we propose **and then finish or abandon**?" | `docs/planning/archive/deep-linking/`, `docs/planning/archive/patrol-firebase-testing/` |

`docs/todos.md` is a sixth, explicitly dead, category: it is archived
(banner: *"Issues are now tracked in GitHub... preserved for historical
reference only. Do not add new items here."*). GitHub Issues is the single
tracker for bugs/features/tasks — see §3.

### The lifecycle rule

**A planning doc has exactly two ways to stop being "active":** it ships, or
it's abandoned. Either way, it moves to `planning/archive/` and its durable
decision gets extracted into an ADR. A planning doc is not itself a decision
record — decisions belong in `adr/` where they're indexed and searchable;
the planning doc is the working scratchpad kept for archaeology.

Two worked examples, both real:

- **Shipped** — `docs/planning/archive/deep-linking/` (design docs,
  implementation plan, phase completion reports) captures the full campaign
  that became festival-scoped path-based URLs. The decision itself — path vs
  hash URLs, why festival-scoped, alternatives rejected — lives in
  **ADR 0004**, not in the archived folder. `docs/README.md` states this
  explicitly: *"Phase 1 complete, decisions captured in ADR 0004."*
- **Abandoned** — `docs/planning/archive/patrol-firebase-testing/` holds a
  full 4–5-week, 5-phase plan for Patrol + Firebase Test Lab native E2E
  testing that was **never implemented** — cost, complexity, and the 15
  tests/day free-tier cap killed it before a line of Patrol code shipped.
  The decision (why Playwright URL-smoke instead, and the triggers that
  would justify reopening) is **ADR 0005**, not the archived plan.

Rule of thumb: if you find yourself writing "we decided to..." inside a
planning doc that's about to be archived, that sentence belongs in a new or
existing ADR instead — see §2 for when an ADR is warranted at all.

Two currently-active planning docs exist and are not yet archived:
`docs/planning/my-festival/vision.md` (multi-phase roadmap for issues
#411–#415, this project's hardest live problem) and
`docs/planning/rating-service/design.md` (community ratings backend). Do not
archive these — they haven't shipped or been abandoned.

## 2. ADR house style

Read an existing ADR before writing one — `docs/adr/0004-path-based-url-strategy.md`
is a good template because it has real, rejected alternatives. Extracted
structure:

```markdown
# ADR NNNN: <Title>

**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: YYYY-MM-DD
**Deciders**: <who>

**Context**: <the forces at play — technical/political/social — in 2-4 sentences>

---

## Decision

<what was decided, with enough structure (tables, code blocks, URL patterns)
that a reader unfamiliar with the debate understands the shape of the choice>

---

## Alternatives Considered

### <Alternative A>
- <its merit>
- Rejected because: <the concrete reason>

### <Alternative B>
- ...

---

## Consequences

### Positive
- ...

### Negative
- ... (a real ADR states the accepted downsides plainly, not just the win)

---

## Implementation

- **<Component>**: <file path>
- ...

## Related Documents

- <cross-references, including docs/code/ pages describing the current implementation>
```

`docs/adr/README.md` defines the format as
Status/Context/Decision/Consequences (the alternatives section is
established by all five existing ADRs even though the README's own summary
omits it — follow the ADRs, not the README's abbreviated description).

**Index discipline**: every ADR is listed in the `docs/adr/README.md` table
(ADR number, title, status, date) *and* cross-linked from `docs/README.md`'s
own ADR section and its "Understand a past decision" quick-reference. Update
both when adding one.

**Next-number convention**: strictly sequential, zero-padded to 4 digits.
Five exist today (0001–0005); the next is `0006-<kebab-case-title>.md`. Check
`docs/adr/README.md`'s table for the current max before assigning a number.

### When an ADR is required

Per `docs/README.md`'s own contributing guidance and the pattern across all
five: write an ADR for a **cross-cutting technical decision with real
alternatives that someone could later propose again** — CI/caching strategy,
a URL/routing scheme, an E2E testing approach, a build-parallelization
choice. The tell: if you rejected an option and someone might re-propose it
in six months without this doc, write it down now. Routine implementation
choices, single-PR refactors, and anything without a real rejected
alternative do not need one — see skill `change-control` §8 for the
ADR-vs-planning-doc-vs-plain-PR decision table.

## 3. GitHub Issue house style

GitHub Issues is the single source of truth for bugs, features, and tasks
(AGENTS.md "Issue Tracking"; `docs/todos.md` is archived — never add to it).
A good issue, extracted from AGENTS.md and the real triage-comment pattern
this project uses:

- **Title**: plain language, no conventional-commit prefix. `fix:`/`feat:`
  prefixes are for commits and PR titles (§4), not issue titles — an issue
  titled "fix(router): handle missing festival ID" is wrong; "Router crashes
  on missing festival ID" is right.
- **Root cause + location**: exact file and line number, not just "there's a
  bug in the router." The digest of this project's own closed issues shows
  the pattern consistently: *"`_currentFestival` reference goes stale... —
  `beer_provider.dart` ~254–305"* (issue #306); *"the prefix `tasting_log_cbf2025`
  also matches `cbf20250`"* (issue tracked as archived todo M1).
- **Concrete fix approach**: state the fix strategy, not just the symptom —
  "token-based guard: a load started before a festival switch can no longer
  apply its result" (the actual resolution described for issue #266), not
  "should probably add some kind of guard."
- **Labels**: `bug` or `enhancement`, plus exactly one priority:

| Label | Meaning |
|---|---|
| `priority:high` | Fix next — real user impact or data correctness |
| `priority:medium` | Fix soon — meaningful but not urgent |
| `priority:low` | Backlog — latent, polish, or speculative |

- **Triage-comment convention**: this project's maintainer (or an agent
  during a resilience review) often adds a follow-up comment on an issue
  with the exact file:line, root cause, and recommended fix *after* initial
  filing — so before starting work on any open issue, read its comments, not
  just the title and body. Skipping this risks duplicating analysis that's
  already been done, or missing a decision already made about the approach.

**When you discover a bug or improvement while doing something else**: file
an issue: do not fix it as a drive-by inside an unrelated PR, and do not add
it to any doc (`docs/todos.md` is dead). Reference the issue number in the
PR that eventually fixes it (§4).

## 4. Commit and PR style

Conventional Commits, enforced two ways: human discipline on commit
messages, and a CI gate (`pr-lint.yml`, `amannn/action-semantic-pull-request@v6`)
on PR titles that fires on `opened`/`edited`/`reopened` — **not** on new
pushes, so a red PR-Lint check is fixed by editing the title, not by
pushing another commit. `pr-lint` is skipped only when `head_ref ==
'release/next'` (the automated release PR's "Release X.Y.Z" title is
intentionally non-conventional).

```
<type>(<scope>): <subject>

<body — what and why, not how>

Fixes #123
```

- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
- **Subject**: under 72 characters, imperative mood ("add", not "added"/"adds").
- **Body**: wrapped at 72 characters, explains why not how.
- **Footer**: reference the issue — `Fixes #123` / `Closes #123` — so the
  merge auto-closes it.
- **Whole message**: under ~20 lines.

PR titles follow the same `type(scope): subject` grammar as commits — they
are linted independently of the commits inside the PR.

```
feat(drinks): add low-alcohol filter
fix(router): handle missing festival ID
chore: bump Flutter to 3.44.0
```

### Commit subjects are user-facing writing

`cliff.toml` drives the CHANGELOG and GitHub Release notes via git-cliff over
conventional commits (`release-pr.yml`). The template renders each commit's
**subject line verbatim** (title-cased) as the changelog bullet:

```
- {% if commit.scope %}**{{ commit.scope }}**: {% endif %}{{ commit.message | upper_first }}
```

Only `feat`, `fix`, `perf`, `refactor`, and `docs` commits are grouped into
the changelog (`cliff.toml` `commit_parsers`); `test`, `style`, `chore`,
`ci`, and `build` commits are explicitly `skip = true` and never appear.
`filter_unconventional = true` drops anything that doesn't parse as a
conventional commit at all. Practical consequence: **write commit subjects
as if a user will read them** — "fix(router): handle missing festival ID"
becomes a release-note line users see; "fix: stuff" does too, verbatim,
looking exactly that bad.

### GitHub MCP body-field gotcha

When creating a PR, issue, or comment via the GitHub MCP tools, the `body`
parameter takes a plain string. Do **not** wrap it in `$(cat <<'EOF' ... EOF)`
heredoc syntax — that shell idiom has no meaning to the MCP tool and the
literal `$(cat <<'EOF'` / `EOF` text will appear in the rendered
issue/PR/comment. Heredocs are only for the `gh` CLI invoked via Bash.

## 5. Completion-summary rules

When reporting what was done (PR descriptions, session summaries, comments
to the user), AGENTS.md is explicit:

- Keep it **under 150 lines**.
- Focus on **what changed and what needs testing** — not a recap of code the
  reader can already see in the diff.
- **No self-congratulation, no excessive emoji.** Don't repeat information
  already in the code or commit messages.

This applies to this skill's own PRs too, and to any `/ship-issues`-style
agent's final report.

## 6. Known doc drift — fix inline if trivial, else file an issue

These are real, currently-verified inaccuracies in the repo's own docs. Do
not silently perpetuate them by copying from the stale doc; when you touch
the *area* a stale doc describes, fix the doc in the same PR if it's a small
edit, otherwise file an issue (`docs`-scoped, `priority:low` unless it's
actively misleading someone into a wrong action) rather than doing an
unscoped drive-by rewrite.

| Where | What's wrong | What's true |
|---|---|---|
| `AGENTS.md` §Architecture (Infrastructure list, ~line 67) and §Adding User Preferences (~line 399) | Lists `FavoritesService`, `RatingsService`, `TastingLogService` as live classes in `storage_service.dart` | These were unified into `UserDataStore` (`lib/services/user_data_store.dart`, `SharedPreferencesUserDataStore`) via issues #390/#391/#393, landed in PR #395. `storage_service.dart` now contains **only** `FestivalStorageService`. `lib/services/services.dart` exports `storage_service.dart` and `user_data_store.dart` as separate files — verify with `grep -n "class " lib/services/user_data_store.dart lib/services/storage_service.dart`. |
| `docs/tooling/cloudflare-pages.md` | References a doc called `CICD.md` and a workflow file `deploy-worker.yml` | The real process doc is `docs/processes/ci-cd.md`; the real workflow is `.github/workflows/cloudflare-worker.yml` (confirm: `ls .github/workflows/ | grep -i worker`). |
| `docs/processes/festival-data-prs.md` | Filename and its listing in `docs/README.md` ("FAQ for handling festival data pull requests") imply a data-update runbook | The file's actual content is a press-release-style PR/FAQ for the **"My Festival" personal-tracking feature** — unrelated to how to open a festival-data PR. The real festival-data update procedure (edit `data/festivals.json`, validate, push, `cloudflare-worker.yml` deploys) belongs in skill `run-and-operate`, not this file. |
| `docs/README.md` footer | `**Last Updated**: February 2026` | `docs/todos.md` itself was archived 2026-05-24, and other docs have moved since; the index stamp is stale by the project's own git history. Update it whenever you touch the index (see §7). |

If a drift fix would touch more than the doc itself (e.g. renaming a
workflow file to match the doc, rather than fixing the doc to match the
workflow), that's a real change — classify and gate it via skill
`change-control`, don't fold it into a docs-only PR.

## 7. Duty to update `docs/README.md`

`docs/README.md` is a hand-maintained index (not generated). Its own
"Contributing to Docs" section states the rule: **update this README when
adding new documents.** Concretely, when you add a doc:

1. Add it to the relevant category list (§1 table) with a one-line
   description.
2. If it answers a common question, add it to the "Quick Reference" ("I want
   to...") section too.
3. Bump the `**Last Updated**` stamp at the bottom of the file to the
   current month/year.
4. If it's an ADR, also update `docs/adr/README.md`'s index table (§2).

A doc that exists but isn't indexed is effectively lost to the next reader —
this repo has no other doc-discovery mechanism (no generated site nav, no
search).

## 8. External positioning — what's actually public, and claim discipline

Before writing anything that describes the app's status externally (a PR
description destined for a public repo, a completion summary, a claim about
compliance), know what a stranger can actually see:

| Surface | URL / identifier | Notes |
|---|---|---|
| Production web app | `https://cambeerfestival.app` | Live user-facing site (README badge, Cloudflare Pages project `cambeerfestival`) |
| Staging web app | `https://staging.cambeerfestival.app` | Mirrors `main`; also per-PR previews at `<branch>.staging-cambeerfestival.pages.dev` |
| Android listing | Google Play, package `ralcock.cbf` | `https://play.google.com/store/apps/details?id=ralcock.cbf`; linked from the README Play Store badge |
| API docs | `https://richardthe3rd.github.io/cambridge-beer-festival-app/` | Redoc-rendered OpenAPI spec, published by `.github/workflows/api-docs.yml` on every `main` push touching `proto/**` |
| Data proxy | `https://data.cambeerfestival.app` | Cloudflare Worker; not a doc surface but publicly reachable |
| README badges | CI, PR Lint, Codecov, Flutter version, Platforms, GitHub release, License, Play Store | All link to genuinely live, checkable state — don't add a badge for something not actually wired up |

**Claim discipline**: never assert compliance or maturity beyond what's
verified in this repo.

- Accessibility docs (`docs/code/accessibility.md`, AGENTS.md) target
  **WCAG 2.1 Level AA** — say "targets" or "implements patterns for," not
  "is WCAG-compliant," unless an actual audit backs the claim. No such audit
  exists in this repo today.
- "Production-ready" has a specific, narrower definition here (AGENTS.md
  "Definition of Done"): code-complete **plus** edge cases, error handling,
  and accessibility verified — and even then, manual browser/device testing
  cannot be performed by an agent and must be flagged as outstanding. Do not
  claim "production ready" as a synonym for "the tests pass."
- `docs/todos.md`'s own closing self-assessment ("Grade: A- (90/100)", "the
  app is well-architected... production-ready") is exactly the kind of
  self-congratulatory, unverified claim this section warns against — it is
  archived and superseded by GitHub Issues precisely because that scoring
  had no methodology behind it. Don't reproduce that style in new writing.

## 9. Maintaining this skill library

Skills live in `.claude/skills/<name>/SKILL.md`. Every skill (this one
included) ends with a **Provenance and maintenance** section: a date-stamp,
what it was verified against, and re-verification commands for facts likely
to drift. This is not decorative — it is the mechanism that keeps a library
built for a one-human-plus-agents team from silently rotting the way
`docs/tooling/cloudflare-pages.md` and `docs/processes/festival-data-prs.md`
already have (§6).

**Rule**: when a code change you're making invalidates a fact stated in a
skill, update that skill in the *same PR* — don't leave it for a future
"docs cleanup" pass (there won't be one; that's exactly how the drift in §6
accumulated). Concretely: renaming a service, moving a workflow file,
changing a CI gate, or retiring a script are all skill-invalidating changes
if any skill mentions them by name.

## When NOT to use this skill

- **Dart/Flutter code style, widget patterns, linter rules** → skill
  `change-control` classifies the change; skill `ui-and-accessibility` owns
  UI/a11y patterns and widget standards.
- **Release mechanics** (CalVer bump, tagging, the release-PR/release
  workflow chain, Play Store/Cloudflare Pages deploy steps) → skill
  `run-and-operate`. This skill only covers how the *release notes text*
  gets generated from commits (§4), not how to cut a release.
- **Whether an ADR is required for a specific decision, or which CI gates a
  doc-only change triggers** → skill `change-control` (§8 owns the
  ADR-vs-planning-doc-vs-plain-PR decision; §1 confirms docs-only changes
  fire no CI job except `pr-lint`).
- **Proto/API contract documentation content** (not process) → skill
  `api-contract` for the AIP facts and OpenAPI/Redoc generation pipeline
  details; this skill only covers where the *published* Redoc site lives
  (§8).

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at
`/home/user/cambridge-beer-festival-app` (shallow clone): `docs/README.md`,
`docs/adr/README.md`, `docs/adr/0004-path-based-url-strategy.md`,
`docs/todos.md`, `docs/tooling/cloudflare-pages.md`,
`docs/processes/festival-data-prs.md`,
`docs/planning/archive/deep-linking/PHASE-1-COMPLETE.md`,
`docs/planning/my-festival/vision.md`, `AGENTS.md`, `cliff.toml`,
`.github/workflows/pr-lint.yml`, `.github/workflows/api-docs.yml`,
`README.md`, `lib/services/services.dart`. The commit-subject → changelog
mechanism was verified by reading `cliff.toml`'s Tera template directly, not
inferred. Issue #306/#266/M1 details are cited from the failure-archaeology
discovery pass, not fetched live in this session — re-verify against GitHub
before quoting them verbatim in a new doc.

Re-verification one-liners (run from the repo root):

```bash
# ADR index and count
grep -n '^| \[' docs/adr/README.md
ls docs/adr/*.md | grep -v README

# docs/README.md staleness
grep -n 'Last Updated' docs/README.md

# The FavoritesService/RatingsService/TastingLogService drift
grep -n 'FavoritesService\|RatingsService\|TastingLogService' AGENTS.md
grep -n 'class ' lib/services/user_data_store.dart lib/services/storage_service.dart
grep -n 'export' lib/services/services.dart

# cloudflare-pages.md drift (CICD.md / deploy-worker.yml don't exist)
grep -n 'CICD.md\|deploy-worker.yml' docs/tooling/cloudflare-pages.md
ls .github/workflows/ | grep -i worker

# festival-data-prs.md mislabeling
head -5 docs/processes/festival-data-prs.md

# PR-title lint trigger and release/next exemption
cat .github/workflows/pr-lint.yml

# Changelog generation only covers feat/fix/perf/refactor/docs
grep -n 'group =\|skip = true' cliff.toml

# Public URLs still match README badges
grep -n 'cambeerfestival.app\|play.google.com\|github.io' README.md

# API docs still published from proto/** on main
grep -n 'paths:\|branches:' .github/workflows/api-docs.yml
```
