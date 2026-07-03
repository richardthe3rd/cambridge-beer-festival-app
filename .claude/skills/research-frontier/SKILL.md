---
name: research-frontier
description: Open problems where this project could advance the state of the art, framed against the maintainer's own definition of SOTA for this app — seamless offline/online, it just works in festival conditions (mobile-only data, patchy signal). Load when asked "what's the frontier here", "what would make this project state-of-the-art", "what's an ambitious/research angle on this codebase", "is there a paper/thesis in this repo", "how would we prove offline sync actually converges", "what's open in cross-year drink matching / rating bias / catalogue freshness / e2e canvas testing", or before proposing any experiment whose result should count as a real result rather than a vibe. Every problem gives: why naive approaches fail, this repo's specific asset, the first three concrete steps with exact files/commands, and a falsifiable "you have a result when…" milestone. Everything in this skill is labeled open/candidate — nothing here is a decided plan. Also covers the promotion path from frontier idea to shipped change, and the constraint envelope (free-tier, no ops burden, festival freeze, mobile-only data) every candidate must survive.
---

# Research Frontier

This skill is speculative by design. It is not a backlog, not a promise, and
not architecture. Every claim below is labeled **open** (nobody has tried it)
or **candidate** (a plausible first move, unproven). If you find yourself
about to implement one of these as though it were decided, stop and read
[promotion path](#promotion-path-frontier-idea--shipped-change) first — a
frontier idea becomes real work only by passing through the same discipline as
any other change.

**When you should NOT be here**: if the task is to ship a planned feature
(My Festival UI, cloud sync backend) use skill `my-festival-campaign` instead —
it is the executable, decision-gated version of problem 1 below. If the task
is "is this idea rigorous enough to act on", use skill `research-methodology` —
it supplies the evidence bar and idea lifecycle this skill's milestones must
satisfy.

## What "state of the art" means for this project

The maintainer defined it directly, and it is the organizing idea for
everything below:

> **Seamless offline/online — it just works in festival conditions
> (mobile-only data, patchy signal).**

Festival attendees are in a marquee, on mobile data, competing with thousands
of other phones on one cell tower. The real technical challenge is not "add
more features" — it's "never let the network be visible to the user." Problem
1 is this headline problem stated directly. Problems 2–5 are narrower,
supporting the same festival-conditions reality from other angles: identity
across years, honest signal from strangers' phones, freshness without cost,
and proving any of this actually works on Flutter web.

---

## Problem 1 — Seamless offline/online personal-state sync under festival conditions

**Status: open.** This is the headline problem.

### (a) Why naive approaches fail

The obvious approach — "send the write, retry on failure, show a spinner or a
toast" — fails in festival conditions: a tasting note typed in a beer tent on
one signal bar sees connect timeouts, DNS flaps, and mid-request drops, not
clean up/down transitions. A naive retry-with-backoff loop either (1) blocks
the UI waiting for a round-trip the user doesn't care about, or (2) silently
drops the mutation when the app is backgrounded/killed before the retry fires.
Neither answers the question that matters for trust: *if I do this all day
with the network flapping, do I end up with everything I entered, exactly
once, on every device?* That's a convergence property; "spinner" or "toast" UX
is not a proof of it.

### (b) This project's specific asset

Three things line up, and only one of them (the worker) is deployed:

1. **A local-first versioned personal-data store already exists.**
   `lib/services/user_data_store.dart` — `SharedPreferencesUserDataStore`
   (`UserDataStore` interface, `read`/`write`/`remove`/`readAll`/`clearFestival`)
   persists one `UserDrinkState` per drink-per-festival, versions every payload
   (`schemaKey`/`currentSchemaVersion`), migrates on read, and prunes empty
   records. The class doc comment says the quiet part explicitly: *"today a
   `SharedPreferencesUserDataStore` (local-first), later a synced store (vision
   Phase 3) with the local store as the offline cache."* The sync-backend seam
   is already drawn — a constructor swap, not a rewrite.
2. **A sync-shaped wire contract is designed, not yet implemented.**
   `proto/cambeerfestival/festival/v1alpha/drink_entry.proto` +
   `my_festival_service.proto`, per `proto/README.md`'s "Sync machinery" table:
   `etag` (AIP-154 optimistic concurrency, `ABORTED` on stale), `allow_missing`
   (idempotent upsert, AIP-134), soft-delete tombstones (`delete_time`,
   `show_deleted`), delta sync (`ListDrinkEntriesRequest.filter` on
   `update_time`), and `BatchUpdateDrinkEntries` (AIP-235, offline-flush batch
   with per-item `google.rpc.Status`) — the vocabulary a real sync protocol
   needs, designed for this app's specific failure mode.
3. **A working, tested, deployed D1 slice exists — but it is narrower than the
   contract.** `cloudflare-worker/reviews.ts` implements
   `GET/PATCH/DELETE /v1alpha/festivals/{f}/drinks/{d}/review` against one D1
   table (`cloudflare-worker/migrations/0001_create_reviews_table.sql`:
   composite primary key `(bucket, festival_id, drink_id, device_id)` gives
   upsert-by-replace semantics), covering only `star_rating` + `recommend` —
   **no `etag`, no `allow_missing`, no soft delete, no `BatchUpdate`, and none
   of `wantToTry`/`tastingEvents`/`notes`/`photoIds`.** Caller identity is the
   `X-Device-Id` header (anonymous phase), never in the resource name.
   **This gap is the actual research opportunity**: the hard parts of a sync
   protocol are designed and AIP-reviewed but not yet built or proven against
   real flakiness.

### (c) First three concrete steps in this repo

1. Read `drink_entry.proto`, `my_festival_service.proto`, and
   `proto/README.md`'s "Sync machinery" table end to end, then read
   `.claude/skills/my-festival-campaign/SKILL.md` §B3 ("DrinkEntry sync —
   implement or explicitly descope") — it already states the impedance
   mismatch between `UserDrinkState` (Dart) and `DrinkEntry` (wire):
   `tastingEvents: List<DateTime>` → `pours: optional int32` is **lossy**
   (per-event timestamps aren't on the wire, only a count). Any convergence
   proof must state which side of that trade-off it assumes.
2. Build a flaky-network test harness reusing the pattern already in
   `test/beer_api_service_test.dart` and
   `test/domain/repositories/api_drink_repository_test.dart` (mockito mocks of
   `http.Client` throwing `SocketException`/`TimeoutException` — the
   exception set `lib/services/connectivity_io.dart`/`connectivity_web.dart`
   already treats as "offline"). Extend it to fail **probabilistically per
   call** rather than deterministically once — the difference between testing
   "one retry works" and testing "convergence holds under sustained
   flakiness."
3. Pick one rank from the offline-outbox menu already drafted in
   `my-festival-campaign` §B3 (rank 1: per-entry `PATCH` replay with
   `allow_missing=true`, coalesced by `drinkId` to latest desired state; rank
   2: `BatchUpdateDrinkEntries`; rank 3: full-state reconcile) and implement
   only enough of it to run against the step-2 harness — a pure Dart outbox
   class under `lib/domain/services/` or `lib/services/`, no UI, exercised by
   `flutter test` with no device. Don't touch the worker yet; a convergence
   proof against a mocked `DrinkEntry`-shaped fake server validates the
   client-side strategy before spending a worker PR.

### (d) You have a result when…

A test harness (pure Dart, runs under `./bin/mise run test`, no device/browser)
demonstrates: **a device offline for an entire simulated festival day
(hundreds of mutations, network failing on a randomized schedule) converges to
zero lost tasting events, want-to-try toggles, or ratings once connectivity is
restored** — verified by asserting the final `UserDrinkState` set equals the
set of mutations actually issued by the UI layer, not the set that happened to
reach the network on the first try. Two independent falsifiers: **flushing the
same outbox twice produces the same server state** (idempotency), and **two
devices editing different fields of the same entry both survive** (field-level
convergence, not last-writer-wins clobbering an unrelated field). These three
properties — no loss, idempotent replay, field-level convergence — are the
theory obligations `my-festival-campaign` §B3 already names; this problem is
"go prove them."

---

## Problem 2 — Cross-year drink/producer identity matching

**Status: open** (design sketch exists; no implementation, no measurement).

### (a) Why naive approaches fail

The obvious approach — "match by ID across `cbf2025` and `cbf2026` feeds" —
fails outright: **drink and producer IDs are not stable year to year.** This
was established by issue #349's ~900-drink field census (the same census that
proved there's no ordinal availability field — see skill `reference`). A
brewery that returns next year gets a new producer ID; a beer with the same
name may be re-keyed. Naive exact-ID join returns near-zero matches; naive
exact-name join misses re-brandings and typo variants ("IPA" vs "India Pale
Ale") — CAMRA volunteer-entered free text (see `reference` skill on
`status_text`) is exactly as inconsistent for names as for availability.

### (b) This project's specific asset

`docs/planning/my-festival/vision.md` "Phase 2 — Cross-Festival Recommendations
*(local inference)*" already sketches a **confidence-tiered** fuzzy-matching
approach rather than a naive join:

1. Exact name + brewery → high confidence
2. Same brewery + same style → medium confidence
3. Style-only → low-confidence genre signal

The vision doc is explicit that "signals should surface the confidence level
explicitly — never present a fuzzy match as a certain recommendation." That's
a rare thing: a planning doc that already states the honesty requirement a
naive implementation would skip. The asset is the multi-festival data itself —
`data/festivals.json` `DefaultFestivals` (`lib/models/festival.dart`) lists
four festivals with live feeds (`cbf2026`, `cbf2025`, `cbfw2025`, `cbf2024`),
each fetchable today via `Festival.getBeverageUrl()` — enough real year-pairs
to build a labeled sample without waiting for a new festival.

### (c) First three concrete steps in this repo

1. Read `docs/planning/my-festival/vision.md`'s Phase 2 section in full (~10
   lines; there is no algorithm, no threshold, no code — a product-level hint,
   not a spec).
2. Pull the same-category feeds for two adjacent festival years, e.g.
   `cbf2025/beer.json` and `cbf2026/beer.json` (`Producer`/`Product` shapes in
   `lib/models/drink.dart`), and build a small hand-labeled ground-truth
   sample: for a random subset of producers in the older feed, manually decide
   "same brewery in the newer feed? which drink(s), if any, are the same
   recipe returning?" Without this sample, "confidence tier" is an adjective,
   not a measurement.
3. Implement the tiered matcher as a pure function in `lib/domain/services/`
   (no Flutter/IO deps, per this project's domain-layer convention — see
   skill `architecture-contract`), taking two `List<Producer>` and returning
   confidence-tagged candidate matches; unit-test it against the hand-labeled
   sample from step 2, not against a mock.

### (d) You have a result when…

Running the matcher against the hand-labeled cross-year sample produces a
**measured precision figure per confidence tier** (e.g. "tier 1 matches are
correct 98% of the time on N=40 labeled pairs; tier 3 matches are correct 40%
of the time") — not a claim that the algorithm "seems to work." The
falsifiable bar: if a lower-confidence tier's measured precision is *not*
meaningfully lower than a higher tier's, the tiering itself is not adding
information and the vision doc's confidence-tier design needs revisiting
before any UI surfaces it (per vision.md's own rule: never present a fuzzy
match as certain).

---

## Problem 3 — Honest community signal from anonymous, self-selected devices

**Status: open** (two supporting design decisions already resolved; the
statistical honesty question is not).

### (a) Why naive approaches fail

The obvious approach — "average the star ratings, show the average" — fails
because of **self-selection bias**: festival-goers mostly try things they
already expect to enjoy, so individual ratings cluster at 3–5 stars.
`docs/planning/my-festival/vision.md`'s ratings-design section states this
directly: *"the bottom of the scale is rarely used, making it a poor signal
for ranking."* A naive top-N-by-average leaderboard mostly ranks "drinks few
people rated, one of whom gave 5 stars" above genuinely well-regarded drinks
with many honest 4s — the classic small-sample-size leaderboard failure, made
worse here because there is no login and anyone's phone can rate any drink at
any count.

### (b) This project's specific asset

Two resolved design decisions already narrow the problem:

1. **A binary "would you recommend it" signal**, tracked as GitHub issue #417
   (see `my-festival-campaign` and `architecture-contract` skills for status)
   and already wired into the deployed schema:
   `cloudflare-worker/migrations/0001_create_reviews_table.sql` has
   `recommend INTEGER CHECK (recommend IN (0, 1))` alongside `star_rating` —
   collected in production, independently nullable from the star rating. A
   yes/no signal is less gameable and less bias-prone than a 5-point scale for
   the bias described above.
2. **A min-count display threshold, deliberately deferred to the client.**
   `docs/planning/rating-service/design.md` §10 "Resolved Questions" answers
   "minimum ratings to show average?" with: the server always returns raw
   `average`/`count`/`distribution`; the **client** decides whether to display
   it, based on a configurable minimum (default 0 for testing, "raise to 3–5
   for production"). This design doc predates the deployed `X-Device-Id`/D1
   implementation and is stale on the auth mechanism (see
   `my-festival-campaign`'s doc-drift warning), but this specific resolved
   decision — threshold lives client-side — is still the live intent.

### (c) First three concrete steps in this repo

1. Read `docs/planning/my-festival/vision.md`'s ratings-design section (search
   "self-selection bias") and `docs/planning/rating-service/design.md` §10 in
   full — both name the problem; neither proposes a statistical correction
   beyond the min-count threshold.
2. Once real festival ratings exist in the deployed D1 table (`reviews`),
   pull an anonymized export (`rating_count`/`avg_rating`/`recommend_count`
   per drink, the shape already computed by `reviewSummaries` in
   `reviews.ts`) and run a bias analysis: does `recommend_count / rating_count`
   diverge meaningfully from what the star-rating average alone would
   suggest? Does the distribution shape (not just the mean) show the
   predicted 3–5 clustering from vision.md?
3. Prototype a ranking that is *not* a plain average — e.g. count-aware
   (Bayesian shrinkage-toward-prior, or the already-resolved min-count gate
   applied more aggressively for ranking than for display) — as a pure
   function over `ReviewSummary`-shaped data, unit-tested against synthetic
   distributions before touching any live-data question.

### (d) You have a result when…

A candidate ranking, run against **real festival rating data** (not
synthetic), demonstrably resists the self-selection bias named in vision.md —
concretely: the ranking's top drinks are not dominated by single-digit-rating
outliers, and a documented bias analysis (real distribution shape, real
`recommend_count`/`rating_count` divergence) either confirms the ranking
corrects for the predicted bias or explains why the predicted bias didn't
materialize in real data. Per skill `research-methodology`'s evidence bar, the
analysis must explain the actual observed distribution — including if it does
*not* show the clustering vision.md predicted — not just assert the fix
works.

---

## Problem 4 — Catalogue freshness without item-level deltas

**Status: open**, with the mechanism already designed and explicitly deferred.

### (a) Why naive approaches fail

The obvious approach for "keep drink availability fresh during a live
festival" is either (1) poll aggressively (wastes bandwidth on mobile data at
a venue with thousands of phones on patchy signal — directly hostile to the
project's own SOTA definition) or (2) build item-level delta sync ("give me
only drinks that changed since T"). Naive delta sync **cannot be built
honestly** here: `proto/README.md`'s "Freshness & polling" section states the
data reality plainly — the upstream feeds (`{festival}/{category}.json`) are
**whole-file snapshots** with one `timestamp` per file, not per drink (the same
absence of structure that caused the availability-status bug in #348/#349 —
see skill `reference`). A server cannot honestly attribute a change to a
single drink when the upstream data doesn't carry that granularity; item-level
delta filtering would have to fabricate a signal that isn't there.

### (b) This project's specific asset

The correct-granularity mechanism is already specified, matching the data's
real shape: **conditional re-fetch** (`If-None-Match`/`If-Modified-Since` →
`304 Not Modified` when a category file hasn't changed), using the feed's
actual per-category `timestamp` (surfaced as `Drink.update_time`/
`Producer.update_time` in the proto contract) as the freshness marker. The
`proto/README.md` text is explicit that this is designed, not shipped: *"Realising
the `304` path needs the worker to honour conditional requests and shorten the
drinks `Cache-Control` TTL — tracked separately from this contract."* The
worker's current behavior (`cloudflare-worker/worker.js`, per its ops
documentation) proxies `{festival}/{category}.json` with a fixed cache
lifetime and no conditional-request handling today.

### (c) First three concrete steps in this repo

1. Read `proto/README.md`'s "Freshness & polling" section in full, and read
   `cloudflare-worker/worker.js`'s proxy path (`else → proxy to
   data.cambridgebeerfestival.com`) to confirm today's actual
   `Cache-Control`/ETag behavior on the category-file proxy route — a
   read-only investigation before any worker change (change-controlled, see
   skills `api-contract` and `change-control`).
2. Measure the current baseline: during normal app use (or a scripted
   simulation hitting the worker's proxy route repeatedly), record bytes
   re-transferred for an *unchanged* category file versus what an honored
   `304` would save. This number is the entire case for doing the work —
   without it, "add conditional re-fetch" is a guess, not a measured
   improvement.
3. Prototype the worker-side change behind a staging-only deploy
   (`cloudflare-worker.yml`'s PR dry-run-deploy path exists for exactly this):
   honor `If-None-Match` against the upstream response's own ETag (or a
   worker-computed hash of the proxied body) and return `304` with no body
   when unchanged, before touching drinks `Cache-Control` TTL.

### (d) You have a result when…

A **measured bandwidth reduction** over a real or realistically-simulated
festival week — bytes actually saved by the `304` path versus the current
full-refetch baseline from step 2 — not a theoretical percentage. Given the
free-tier constraint (see [constraint envelope](#constraint-envelope)), a
secondary falsifier: the change must not increase Cloudflare Worker request
count or D1/KV cost in a way that threatens the free tier, since a
freshness win that trades bandwidth for a paid-tier bill is not a win under
this project's own rules.

---

## Problem 5 — Verifiable Flutter-web UI (the canvas gap)

**Status: open**, with the gap formally accepted in ADR 0005, not solved.

### (a) Why naive approaches fail

The obvious approach — "add more Playwright assertions" — cannot work by
construction. `docs/adr/0005-e2e-testing-strategy.md` states the constraint
directly: Flutter web renders its entire UI to a single `<canvas>` element.
Playwright drives the DOM/accessibility tree, not canvas pixels, so it can
assert URL mechanics, console errors, and ARIA presence — but it **cannot**
verify that a given route renders the correct screen, or any screen at all,
versus an error state. The ADR's "Consequences" section names the exact gap:
*"a route could return 200 but render an error state."* This is a structural
limitation of browser-DOM tooling against a canvas-rendered app, not a missing
test someone forgot to write. Today's e2e suite (`test-e2e/app.spec.ts`,
`routing.spec.ts`) cannot detect it — issue #386 (the router null-check crash)
was only caught because it threw a *console* error, not because any e2e
assertion inspected what rendered.

### (b) This project's specific asset

Three tools already exist, each evaluated for a narrower purpose, that could
be recombined for this one:

1. **Widget/golden tests already assert real rendered content**, just not
   through a browser — `test/goldens/` (4 PNGs from
   `drink_detail_screen_screenshot_test.dart` and
   `style_screen_screenshot_test.dart`), updated via
   `./bin/mise run goldens:update [file]`. Flutter's own renderer, not
   canvas-blind DOM inspection — it *can* see what a screen looks like,
   including its error state, if a golden is added for one.
2. **`scripts/screenshot-batch.mjs`** already drives a real browser against a
   real served build (`npx playwright`-based, config-driven,
   `./bin/mise run screenshots:batch` in dev env), taking actual pixel
   screenshots of live routes — closer to "does this route visually render"
   than any DOM-based assertion could be.
3. **Flutter's own `integration_test` package** was evaluated and explicitly
   *deprioritized, not rejected*, in ADR 0005 ("a valid option for future
   investment") — it runs inside the Flutter test harness and asserts on real
   widgets, so it doesn't have the canvas-blindness problem at all. GitHub
   issue #314 is understood to track revisiting this — **unverified**: not
   found by local text search, and this skill does not fetch external URLs;
   run `gh issue view 314` before relying on it.

### (c) First three concrete steps in this repo

1. Read `docs/adr/0005-e2e-testing-strategy.md` in full, including its "When
   to reconsider" triggers — any move on this problem should explicitly cite
   which trigger fired (per skill `change-control`, this kind of testing-
   strategy shift is architectural and needs an ADR update or successor, not a
   silent tool swap).
2. As a cheap first experiment that needs no new tooling: add a golden test
   asserting on a screen's **error state** specifically (today's 4 goldens are
   all success-path renders) — pick a screen with a reachable error UI (see
   the four-signal loading/error contract in skill `architecture-contract`,
   `_error` field) and force it via a repository mock that throws, the same
   pattern already used in `test/beer_provider_test.dart`. This is the
   cheapest possible instance of "a test that fails when a screen renders its
   error state" — it just doesn't yet run through a browser.
3. Prototype extending `scripts/screenshot-batch.mjs` (or a sibling script) to
   fail a check, not just save a file: fetch a route via
   `test/check-page.mjs`-style navigation (`./bin/mise run test:check-page`
   already exists for one-off checks), take a screenshot, and diff it against
   a known-good golden or assert on a rendered DOM/canvas signal Flutter *does*
   expose (e.g. an ARIA live region or semantics node the error view sets) —
   this is the bridge between "browser-driven" and "actually assert
   rendering," and is exactly the kind of tool this skill should not build
   silently; treat it as a candidate spike, report findings, and route any
   real adoption through an ADR successor to 0005.

### (d) You have a result when…

An automated check — golden, `integration_test`, or an extended screenshot
script — **fails today** when a targeted screen is forced into its error
state, and would have caught issue #386 (the router null-check web crash) or
an equivalent regression, in a way `test-e2e/app.spec.ts`'s current
"≤2 critical console errors" check cannot (that check is lenient by design and
checks console noise, not rendered content). The falsifiable bar is
specifically that: today's suite provably cannot catch "renders wrong/error
content on a 200 route," and the candidate tool provably can, demonstrated on
a real screen forced into that state, not a synthetic example.

---

## Promotion path: frontier idea → shipped change

A "you have a result" milestone above does not authorize a merge. Route it
through the same lifecycle every accepted idea in this repo passed through
(skill `research-methodology` §3, "the idea lifecycle"):

```
frontier idea (this skill)
  → convert to a planning doc: docs/planning/<topic>/ (vision.md/design.md
    pattern — see docs/planning/my-festival/vision.md,
    docs/planning/rating-service/design.md for the house style)
  → survive adversarial refutation (research-methodology §1b) — state the
    milestone's numeric prediction BEFORE running the experiment
    (research-methodology §2), not after
  → file numbered GitHub issues with triage comments (root cause / file:line
    / fix approach — see skill docs-and-writing for issue house style)
  → PR(s) with "Fixes #N", through change control (skill change-control):
    ./bin/mise run check, conventional commits, PR-title lint, CI as ground
    truth
  → an ADR (docs/adr/) if the result changes an architectural decision (e.g.
    a new E2E strategy superseding 0005, or a sync-protocol choice affecting
    the DrinkEntry contract) — see change-control §8 for ADR-vs-planning-doc
    vs-plain-PR
  → the planning doc archives to docs/planning/archive/<topic>/ once shipped,
    per this repo's existing pattern for accepted (and rejected) investigations
```

**No frontier idea may skip change control by virtue of being labeled
"research."** A proto change (problem 1 or 4) still goes through skill
`api-contract`'s buf/api-linter workflow and WIRE-breaking rules. A UI probe
(problem 5) still respects skill `ui-and-accessibility`'s incremental-change
discipline — this project's costliest historical failure mode is UI
redesigns, and "we were just prototyping a testing tool" is not an exemption.

## Constraint envelope

Every candidate above must survive these, not just the milestone in (d):

| Constraint | What it rules out | Source |
|---|---|---|
| **Free-tier only, no paid ops** | A sync backend, freshness mechanism, or e2e pipeline that needs a paid Cloudflare/Firebase tier, a device farm, or anything with a per-request bill that spikes at ~40,000 festival visitors | skill `change-control` Rule 2; ADR 0005 rejected Patrol/Firebase Test Lab partly on cost/quota (15 tests/day) |
| **No ops burden** | Anything needing manual restarts, rotation, or babysitting during festival week — this is a one-maintainer project with zero on-call capacity during the one week the app matters most | skill `change-control` Rule 2 |
| **Festival-week freeze** | Any deploy-affecting merge (worker, proto, sync client, new e2e pipeline) from 14 days before a festival's `start_date` through its `end_date` — check `data/festivals.json` `is_active`/dates first | skill `change-control` §5 |
| **Mobile-only data at the venue** | Any design assuming reliable connectivity, low-latency round-trips, or that a user will wait for a spinner — this is *the constraint problem 1 exists to solve*, and it binds every other problem's UI/UX surface too | maintainer's SOTA definition (this skill's header) |
| **Upstream feeds untouchable** | Any "ask CAMRA to add per-drink timestamps" or "ask them to keep IDs stable" resolution to problems 2 or 4 — the feeds are absorbed as-is, defensively parsed, never assumed stable | skill `change-control` Rule 4 |

## When NOT to use this skill

- **Shipping a planned feature** (My Festival UI, cloud sync backend,
  anything with a numbered issue and an implementation plan already) — use
  skill `my-festival-campaign`. It is the decision-gated, executable version
  of problem 1.
- **Deciding whether an idea (from here or anywhere) is rigorous enough to
  act on**, writing up an investigation, or running a resilience review/data
  census — use skill `research-methodology`. This skill supplies the *what*;
  that skill supplies the *how to know you're right*.
- **Any ordinary bug fix or debugging session** — use skill
  `debugging-playbook` or `failure-archaeology`. Nothing here is a bug.
- **Touching the proto contract itself** — use skill `api-contract` for the
  actual buf/api-linter workflow, AIP rules, and WIRE-breaking constraints;
  this skill only points at *why* a contract change might be worth making.

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at that date: read
directly — `proto/README.md` (full file), `proto/cambeerfestival/festival/v1alpha/drink_entry.proto`
and `my_festival_service.proto` existence, `lib/services/user_data_store.dart`
(doc comment + interface), `cloudflare-worker/reviews.ts` (route list, no
etag/allow_missing/batchUpdate/tombstone found by grep),
`cloudflare-worker/migrations/0001_create_reviews_table.sql` (full file),
`docs/planning/my-festival/vision.md` (Phase 2 confidence tiers, self-selection
bias section), `docs/planning/rating-service/design.md` (§10 Resolved
Questions — noted as stale on auth mechanism per `my-festival-campaign`'s
doc-drift warning, but the min-count-threshold decision itself still stands),
`docs/adr/0005-e2e-testing-strategy.md` (full file), `test/beer_api_service_test.dart`
and `test/domain/repositories/api_drink_repository_test.dart` (mockito
SocketException pattern), `scripts/screenshot-batch.mjs` (exists, Playwright-based).

**Not independently re-verified for this skill** (cited via sibling skills or
the discovery digests, not re-read from a live source): GitHub issue numbers
#417, #432, #349, #386, #314 — this repo's local clone is shallow and this
skill does not fetch external URLs. Issue #314 in particular was not found by
local text search (`grep -rn "314"` across `*.md` outside `.claude/skills/`
and vendored toolchain docs turned up nothing) — treat its existence/status as
unverified; run `gh issue view 314` before relying on it. The other four
numbers are corroborated by multiple sibling skills
(`architecture-contract`, `my-festival-campaign`, `failure-archaeology`,
`research-methodology`) that state they fetched them live.

Re-verify if the tree has moved:

```bash
# Has the worker grown etag/allow_missing/BatchUpdate support? (empty = still gap-only)
grep -n "etag\|allow_missing\|BatchUpdate\|delete_time" cloudflare-worker/reviews.ts

# Has conditional re-fetch (304) landed on the category-file proxy route?
grep -n "If-None-Match\|If-Modified-Since\|304" cloudflare-worker/worker.js

# Does the vision doc's Phase 2 cross-year matching still describe only a sketch (no code)?
grep -rn "Phase 2" docs/planning/my-festival/vision.md
ls lib/domain/services/ | grep -i match

# Has issue #417 (wouldRecommend) landed, changing the "recommend" column story?
grep -n "recommend" cloudflare-worker/migrations/0001_create_reviews_table.sql

# Is ADR 0005 still the live e2e strategy, or has a successor superseded it?
ls docs/adr/ | tail -5

# Do goldens still cover only success-path renders (no error-state golden yet)?
ls test/goldens/
```
