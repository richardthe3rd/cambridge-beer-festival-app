---
name: research-methodology
description: The discipline that turns a hunch into an accepted result in the Cambridge Beer Festival app. Load when proposing a root cause, deciding whether a fix is "the" fix, writing an issue triage comment, drafting a planning doc, running a resilience review or data census, deciding whether an idea needs an ADR, or closing/archiving an investigation (accepted or rejected). Triggers — "is this the real root cause", "what's the fix for X", "write up this investigation", "should this be an ADR", "the reviewer suggested Y, is that right", "we tried this before, what happened", "run a census on the data", "kill this hypothesis before we ship it", "retire this planning doc". Provides: the evidence bar (explain ALL observations + survive adversarial refutation), predict-numbers-before-running, the idea lifecycle from hunch to archive, this project's preference for cheap/reversible config over flag systems, the historical sources of good ideas here, and the retirement protocol for dead ends.
---

# Research Methodology

This is not abstract scientific-method advice. Every rule below is reverse-engineered from a
specific investigation in this repo's history, cited by issue/PR number. If you cannot point to
the file, issue, or commit backing a claim, it does not belong in an issue, a PR description, or
this skill.

Jargon: **resilience review** = a deliberate pass over recently-shipped code looking for latent
bugs before they reach users (not a response to an incident). **Census** = an empirical survey of
live/production data to check an assumption before coding against it. **ADR** = Architecture
Decision Record (`docs/adr/`).

---

## 1. The evidence bar

A proposed root cause is not accepted until it clears two hurdles:

### 1a. It must explain ALL observations, including the negatives

A mechanism that explains the symptom but not a related non-symptom is incomplete — ship the
narrower fix and you will be back within the sprint.

**Worked example — issue #308** (`Future.wait([])` vacuous success):
- **Symptom**: a festival with `availableBeverageTypes: []` locked the user to stale cache for up
  to an hour with no error signal.
- **First mechanism proposed**: `isCompleteFailure` (`drinksByType.isEmpty && failedTypes.isNotEmpty`)
  is false when both collections are empty, so the provider treats "no work to do" as "refreshed."
  The first commit fixed this by simply *not updating* `_lastDrinksRefresh` on the empty-success
  path.
- **The negative it didn't explain**: switching from an already-loaded festival *to* an empty one.
  `_lastDrinksRefresh` was already set from the previous festival's real load, so leaving it
  untouched still left `isDrinksDataStale` false — the switch-to-empty-festival case still locked
  up.
- **Full-explanation fix**: a follow-up commit (`1fb41aa`, PR #382) explicitly **resets
  `_lastDrinksRefresh = null`** on the empty-success path, so a switch from a loaded festival to an
  empty one is correctly stale and retriable in both directions.
- **Lesson**: when your fix only kills the reproduction case you tested, ask what the *first*
  commit's mechanism predicts for the adjacent case (here: switching state, not just cold state).
  If you can't answer that from the mechanism alone, you don't have the mechanism yet.

### 1b. It must survive assigned adversarial refutation

Before accepting a hypothesis, actively try to kill it — check whether the code already handles
the case you're about to "fix," and whether your fix is bigger than the residual problem.

**Worked example — issue #310 → narrowed to #397** (FavoritesScreen one-frame flash):
- **Original hypothesis**: "the favourites screen doesn't switch festival on mount when the route's
  festival ID differs from the provider's current festival" — implying a fix inside the screen's
  build/init logic.
- **Adversarial test performed**: check whether `_festivalScopeRedirect` (`router.dart`) already
  schedules the switch. It does — via `addPostFrameCallback(setFestival)`. The original hypothesis
  was **already implemented**; shipping a "fix" for it would have been redundant code churn.
- **What survived**: `addPostFrameCallback` guarantees the redirect runs, but not before the
  *first frame* paints — that first frame still renders against the stale `currentFestival`. The
  issue was **narrowed**, not answered with a new fix, from "screen doesn't switch" (#310, false)
  to "residual one-frame stale-render window" (#397, true).
- **Resolution** (PR #409, `0656162`): guard the screen itself — `if (provider.currentFestival.id
  != festivalId) return buildLoadingScaffold();` (`lib/screens/my_festival_screen.dart:15`, the
  file containing the `FavoritesScreen` class) — render a loading scaffold for that one frame
  instead of stale content.
- **Lesson**: "does the current code already do X" is a five-minute adversarial check that either
  kills your hypothesis outright or narrows it to the true residual gap. Skipping it produces
  redundant fixes for problems that don't exist and misses the real, smaller problem.

**How to apply this to a reviewer comment or your own hunch:**
1. State the mechanism in one sentence that predicts a specific, checkable behavior.
2. List every related case (empty state, switching state, cold state, error state) and ask what
   the mechanism predicts for each — not just the one you reproduced.
3. Grep/read the code path the hypothesis implicates. If it's already handled, narrow the
   hypothesis instead of shipping a parallel fix — see `debugging-playbook` for the
   symptom→cause→experiment table this pattern feeds.
4. Only write the issue/PR once the mechanism survives both checks.

---

## 2. State the expected observation before running the experiment

Write down what you expect to see — test count, HTTP status, which `if`/`switch` branch fires,
how many records match — **before** you query, run, or grep. This is what turns "I looked at the
data and confirmed my theory" (confirmation bias, unfalsifiable) into a real test.

**Worked example — issues #349 → #348** (availability-status data census):
- #349 was an explicit census of ~900 live drink records, run to check assumptions before writing
  the parsing fix in #348.
- Claims were checked against the census **before** being written into the fix, and not all
  survived:
  - Confirmed: substring matching mis-bucketed `"Some beer remaining"` (~32% of summer-festival
    statuses, a large share) as `low` because `'out'` and `'low'` are substrings of `'about'` and
    `'below'`.
  - Confirmed: no ordinal/numeric availability field exists anywhere in the upstream data — a
    free-text status string is genuinely all there is, so the fix had to be a string→enum map, not
    a numeric threshold.
  - **Disconfirmed and explicitly labeled unverifiable**: an intuition floated during the census
    that a "legacy vegan" field/convention existed in older festival data. The census could not
    substantiate it, and the finding was written up as unverifiable rather than asserted as fact.
- **Resulting fix** (PR #360): exact-match status map (`lib/models/drink.dart:237-244` —
  `'sold out'→out`, `'nearly finished!'→veryLow`, `'a little remaining'→low`, `'some beer
  remaining'→good`, `'plenty left'→plenty`, `'arrived'→plenty`), unknown text → `unknown` +
  raw text passed through to the UI rather than guessed at. Also confirmed: the vocabulary is
  **not stable across festivals** — the `_statusMap` carries an `arrived` entry (historical
  winter vocabulary per #348/#349 records, not reproduced in the current live feeds) — another
  prediction the census let the fix state explicitly instead of silently assuming.
- **Lesson**: "the num branch never fires" or "this field always has this shape" is a claim about
  the data, not the code. Check it against a census of real records before it becomes a `case` in
  a switch statement. When the census can't confirm a claim, say so — an unverifiable finding
  written down honestly is more useful than a guess asserted as settled.

**Recipe**: before running any grep/query/test against live or historical data —
1. Write the prediction: "I expect N% of records to match pattern X" / "I expect this branch to
   never fire" / "I expect status code 404."
2. Run the check.
3. Record match or mismatch explicitly — a mismatch is not a failure, it's the reason the census
   was worth running. See skill `proof-and-analysis-toolkit` for the census-recipe mechanics
   (how to structure the query, sample size, etc.) — this skill only covers the discipline of
   predicting first.

---

## 3. The idea lifecycle

Every idea that reached production in this repo passed through the same shape. Skipping a stage
is the difference between a fix that sticks and one that gets reverted or re-litigated.

```
hunch
  → planning doc in docs/planning/<topic>/ (vision.md / design.md pattern)
  → resilience review or data census, filing concrete numbered issues
  → issues with triage comments (root cause + file:line + fix approach)
  → PR with "Fixes #N" through change control (see skill change-control)
  → decision recorded in an ADR (docs/adr/) when architectural
  → planning doc archived to docs/planning/archive/<topic>/
  → IF REJECTED: documented retirement (see §6) instead of silent abandonment
```

Verified artifacts for each stage, so you can find the pattern to copy:

| Stage | Real example in this repo |
|---|---|
| Planning doc (open roadmap) | `docs/planning/my-festival/vision.md` — phased roadmap, "Status: Vision", rejected-alternatives table inline (e.g. "colour-coded card backgrounds — accessibility issues, cluttered") |
| Planning doc (speculative backend design) | `docs/planning/rating-service/design.md` — Phase 4 community-ratings design; explicitly out-of-scope-marked against the Phase 1 feature already shipped |
| Resilience review → filed issues | PR #302 (stale-while-revalidate offline caching) → its resilience review filed issues #306, #307, #308, #309 |
| Data census → filed issue | Issue #349 (∼900-record census) → issue #348 (availability-status parsing fix) |
| Issue with triage comment | AGENTS.md / this repo's convention: "Issues have triage comments with exact file paths, root causes, and recommended fixes" — check the issue before starting work |
| PR through change control | Any `Fixes #NNN` PR; see skill `change-control` for the classification→CI-gate map and merge checklist |
| ADR for an architectural decision | `docs/adr/0001`–`0005` (GH Actions caching, composite actions, parallel build, path-based URLs, E2E strategy) — each records the decision **and** the rejected alternatives with reasons |
| Archived planning doc | `docs/planning/archive/patrol-firebase-testing/` (plan.md, review.md, summary.md — the rejected native-E2E investment); `docs/planning/archive/deep-linking/`; `docs/planning/archive/ci-review/` |
| Rejected idea, documented | ADR 0005 (Patrol/Firebase Test Lab) — see §6 |

**Do not shortcut this for anything that changes user-visible behavior.** A hunch that skips
straight to a PR without an issue loses the triage-comment discipline the next reader depends on;
an architectural change without an ADR loses the "why," and a future agent will re-litigate a
settled question. See skill `change-control` for what's actually gated by CI versus what's a
process norm.

---

## 4. Prefer cheap, reversible experiment mechanisms

This project does not build runtime feature-flag systems for experiments. It prefers
**server-configurable or `const` thresholds** — cheap to ship, cheap to reverse, no flag-service
infrastructure to operate during a live festival (see the free-tier/low-ops discipline in skill
`change-control`).

**Worked example — `minRatingsToShowAverage`** (`docs/planning/rating-service/design.md`, §10
"Resolved Questions", item 2): the design explicitly rejects a purpose-built minimum-ratings flag
service. Instead: the API always returns the raw aggregate (average, count, distribution); a
single client-side constant decides whether to *display* it —

```dart
// Config: minimum ratings before showing community average
static const int minRatingsToShowAverage = 0; // 0 for dev/testing, 3+ for production
```

Tunable without redeploying the backend, testable at `0` in dev, reversible by editing one
constant. This is a planning-doc design, not yet shipped code — treat it as a candidate pattern to
follow, not as an implemented API.

**Worked example — `RATINGS_BUCKET`** (`cloudflare-worker/shared.ts:16,24-25`, already shipped):
the Review API buckets test vs. production data by resolving the calling origin (`prod` only for
`https://cambeerfestival.app`, else `test`), with an env-var override `RATINGS_BUCKET` for local
and CI testing. No separate flagging service, no dashboard — one environment variable, defaulted
sanely, overridable when needed.

**When you're tempted to build a flag system**: ask whether a `const` (client) or a single env var
/ config field (server) gets you the same reversibility. If yes, that's the answer here — it's
what shipped every time this question came up.

---

## 5. Where good ideas historically came from (name the pattern)

When you're looking for what to work on next, or want precedent for *how* an idea should surface,
these are the sources that have actually worked in this repo — not aspirational, count-verified in
`failure-archaeology`:

1. **Post-ship resilience reviews** — deliberately re-examine a feature shortly after shipping it,
   looking for latent bugs, and file them as issues rather than waiting for a user report. PR #302
   → issues #306/#307/#308/#309 is the reference instance; #302's own review is why four separate
   correctness bugs in stale-while-revalidate caching were caught pre-incident.
2. **Empirical censuses of live data** — before writing a parsing/classification fix, count what
   the real data actually looks like. Issue #349 → #348 is the reference instance (see §2).
3. **Refusing wrong reviewer fixes, and recording the fact** — when an automated or human reviewer
   proposes a fix that's actually wrong, the discipline is not just "ignore it" but "write down
   why it's wrong so the next reviewer doesn't propose it again." This is why AGENTS.md carries
   fact tables like the AIP proto rules and the Dart/`dart:io` exception hierarchy — each fact
   exists because a reviewer got it wrong at least once. See `isBenignRestorationError` in §6 for
   the inverse case (a broad suppression that *should* have been challenged and wasn't, until it
   was removed).
4. **Incident post-mortems that became fact tables** — issue #386 (router null-check crash on
   web release) produced not just a fix (PR #408) but a permanent AGENTS.md-documented workflow
   (source-map crash decoding, the CI-vs-local ~4-line dart-define offset) so the next web crash
   is diagnosed in minutes, not hours.
5. **Issue-narrowing instead of issue-inflation** — when a hypothesis is found already-handled,
   the discipline is to shrink the issue to the true residual gap (§1b, #310 → #397), not to
   invent a new issue to justify the investigation time already spent.

If you're using skill `research-frontier` to pick a problem, prefer framing it through one of
these five lenses rather than starting from a blank hunch — it's what has actually produced
accepted results here.

---

## 6. Retirement protocol

A rejected idea is not a failure to hide — it's a first-class result that saves the next person
from re-doing the investigation. When an idea dies (a hypothesis is disproven, a design is
abandoned, a workaround is removed as wrong):

1. **Record symptom → why-rejected → evidence** in the project's failure chronicle. In this repo
   that's the skill `failure-archaeology` (cross-reference it, don't duplicate its content here).
2. **Close the GitHub issue with an explicit `state_reason`** (not just "closed") — distinguishing
   "not planned" / "won't fix, here's why" from "completed."
3. **Archive the planning doc** to `docs/planning/archive/<topic>/` rather than deleting it — the
   reasoning stays discoverable even though the plan is dead.

**Worked example — Patrol + Firebase Test Lab (ADR 0005)**: a full 4–5-week, 5-phase native-E2E
plan was written (`docs/planning/archive/patrol-firebase-testing/plan.md`, `review.md`,
`summary.md`), then explicitly rejected in favor of Playwright URL-smoke-only testing. The ADR
records *why*: Firebase Test Lab setup complexity (GCP service accounts, instrumentation builds),
a 15-tests/day free-tier cap, and that Flutter widget tests already cover interaction flows — plus
named **reconsideration triggers** ("if the app ships needing device-specific testing," "if visual
regression testing becomes important"). The plan files were archived, not deleted, specifically so
a future agent tempted to re-propose Patrol can read why it lost the first time.

**Worked example — `isBenignRestorationError` removal**: a broad workaround that downgraded
*every* "Null check operator used on a null value" web-release error to non-fatal, by message
string alone, was deleted as dangerously over-broad once the real, narrow root cause (`/` route
with no builder, issue #386) was found and fixed properly (PR #408). The retirement here isn't a
planning doc archive — it's a removed workaround with the reason recorded in the issue and in
`failure-archaeology`: "catch-all 'benign error' suppression by message is a footgun." The lesson
generalizes — a suppression/workaround that later gets replaced by a real fix should be actively
*removed*, not left in place "just in case," once you understand why it was wrong.

**Do not** let a rejected idea just go silent (an abandoned branch, a planning doc quietly never
referenced again). If you find one of those while working in this repo, that's a signal to write
the retirement up retroactively, not to leave it undocumented.

---

## When NOT to use this skill

- **Picking what to work on** → skill `research-frontier` (open problems, why current SOTA fails,
  falsifiable milestones). This skill is about *how* to validate an idea once you're chasing it,
  not which idea to chase.
- **The mechanics of an analysis** (how to structure a data census query, how to decode a
  source-map crash, how to audit an async race) → skill `proof-and-analysis-toolkit`. This skill
  covers the *discipline* (predict first, explain all observations); that skill covers the
  *recipes*.
- **Whether a change is allowed, what CI gate it needs, or how to triage a review comment as
  right/wrong** → skill `change-control`. This skill assumes you already know the idea is worth
  pursuing and covers how to validate it, not how to ship it.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree of `/home/user/cambridge-beer-festival-app`
(shallow clone, ~50 commits — older history cited by issue/PR number, not SHA, except where a
SHA is quoted above from material already verified in this document).

Facts verified directly during authoring (re-run these to check for drift):

- `docs/planning/my-festival/vision.md` exists with "Status: 💡 Vision" and a rejected-alternatives
  table — `head -5 docs/planning/my-festival/vision.md`
- `docs/planning/rating-service/design.md` §10 contains the `minRatingsToShowAverage` resolved
  question — `grep -n minRatingsToShowAverage docs/planning/rating-service/design.md`
- `cloudflare-worker/shared.ts` resolves `RATINGS_BUCKET` — `grep -n RATINGS_BUCKET cloudflare-worker/shared.ts`
- `docs/adr/0005-e2e-testing-strategy.md` records the Patrol/Firebase rejection and reconsideration
  triggers — `sed -n '35,52p' docs/adr/0005-e2e-testing-strategy.md`
- `docs/planning/archive/patrol-firebase-testing/` contains plan.md, review.md, summary.md,
  readme-review.md — `ls docs/planning/archive/patrol-firebase-testing/`
- The FavoritesScreen festival-flash guard exists at the stated location — `grep -n "currentFestival.id != festivalId" lib/screens/my_festival_screen.dart` (currently line 15)
- The exact-match availability status map exists — `sed -n '233,244p' lib/models/drink.dart`
- `docs/adr/` contains exactly 5 numbered ADRs plus README — `ls docs/adr/`

Facts inherited from the initial 2026-07-02 repo survey and not independently re-verified against a
primary source in this session (issue text is not fetchable from the shallow local clone without
GitHub network access, which this skill's authoring rules disallow as load-bearing): the exact
issue numbers #306/#307/#308/#309/#310/#397/#348/#349/#386, the "~900 live records" and "~32% of
summer statuses" figures from the #349 census, and the "legacy vegan claim was found unverifiable"
detail. Re-verify by reading the actual GitHub issues (`gh issue view <N>` or the GitHub UI) before
citing these numbers in something load-bearing (a new issue, a PR description) if this skill is
being used long after the 2026-07-02 write-up.

Re-verification commands:
```bash
# Confirm the sibling skills this doc cross-references still exist under these exact names
ls .claude/skills/ | grep -E '^(research-frontier|proof-and-analysis-toolkit|change-control|failure-archaeology)$'

# Confirm ADR count hasn't grown without this doc being updated
ls docs/adr/*.md | wc -l

# Confirm no new docs/planning/ topic has appeared that should be added as a lifecycle example
ls docs/planning/
```
