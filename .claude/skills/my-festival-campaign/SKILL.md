---
name: my-festival-campaign
description: >-
  Executable, decision-gated campaign for the project's hardest live problem —
  finishing the "My Festival" Phase 1 UI (issues #411, #413, #414, #415) AND the
  cloud-sync backend (D1 provisioning, v1alpha API deploy, Flutter sync client).
  Load when the task is "implement My Festival", "finish the tasting log", "add
  addTasting/removeTasting/setUserNotes", "want-to-try / tasted badge", "the My
  Festival screen", "multi-tasting detail screen", "provision D1 / deploy the
  reviews worker", "build the sync client", "wire up DrinkEntry sync",
  "offline outbox / flush on reconnect", or any slice of #315. Gives numbered
  phases with exact files, baseline + verification commands, the expected
  observation at each gate (and the branch to take on a surprise), the wrong
  paths to fence off, a ranked offline-sync solution menu, and the
  change-control routing (one PR per phase). NOT for unrelated bugs (see
  debugging-playbook) or editing the proto contract itself (see api-contract).
---

# My Festival campaign — Phase 1 UI + cloud sync

This is a **runbook**, not a design doc. Each phase names exact files, gives a
baseline command and a verification command, states the observation you should
see at the gate, and tells you where to branch if you see something else. Do the
phases in order within a track; **one PR per phase**.

Read as ground truth before starting: `docs/planning/my-festival/vision.md`
(the product spec) and the proto contract in
`proto/cambeerfestival/festival/v1alpha/` (`drink_entry.proto`,
`my_festival_service.proto`). Verify any file:line claim below against the code
before you rely on it — the tree moves.

## Two independent tracks

- **Track A — UI** (`#411 → #413 → #414 → #415`): local diary. All data stays
  in SharedPreferences. This is the maintainer's stated hardest live problem and
  the higher-value track — do it first.
- **Track B — Sync** (D1 + worker + Flutter client): additive backup. Can start
  after **A1** lands (A1 finalises the local `UserDrinkState` shape that sync
  serialises). Per `vision.md` Phase 3, sync is **strictly additive** —
  SharedPreferences stays the source of truth for the UI; the network is a
  backup, never a read dependency.

Interleaving is fine, but never let Track B change UI behaviour. If a sync PR
touches a screen, you have crossed the tracks — split it.

## Doc-drift warnings (trust code, not these docs)

- **`docs/planning/rating-service/design.md` is stale.** It describes Firebase
  Anonymous Auth and a `RatingsService` in `storage_service.dart`. Neither is
  real. The deployed worker uses an **`X-Device-Id` header** for identity (no
  Firebase auth), and `RatingsService`/`FavoritesService`/`TastingLogService`
  were unified into `UserDataStore` (`lib/services/user_data_store.dart`) by
  #391/#395. `storage_service.dart` now holds only `FestivalStorageService`.
  Use the design doc for *intent* only; use the proto + `cloudflare-worker/` +
  the code for *contract*.
- **AGENTS.md** still lists those three deleted services in its Architecture
  section — same drift, same resolution.
- **Deployed API ≠ full proto contract.** The proto describes a `DrinkEntry`
  resource (`.../entry`, `drinkEntries`) carrying `is_favourite`, `star_rating`,
  `would_recommend`, `note`, `pours`. The **worker only implements the narrower
  `Review`** (`.../review`, `reviews`, `reviewSummaries`) carrying `starRating`
  + `wouldRecommend`. The `DrinkEntry` sync endpoint is **not built** — see B3.

For the layer contract and the 11 enforced invariants, load skill
`architecture-contract`. For proto/AIP editing rules, load `api-contract`.

---

## Phase 0 — Baseline (do this first, every session)

**Goal:** a known-green starting point so any later red is *your* red.

```bash
./bin/mise run check          # generate → format → analyze → test → shell:check
```

**Expected at the gate:** exits 0. The tree is green today.

- If it fails while **installing dev tools** (proxy 403 on GitHub downloads —
  seen on Claude Code Web, 2026-07-02), fall back to
  `MISE_ENV=claude-code-web ./bin/mise run <task>` for base tasks (`analyze`,
  `test`, `generate`). This selects the web fixups without pulling dev tools.
  See skill `build-and-env` for the full trap.
- If it fails on **real test/analyze errors** on a clean checkout → stop; you
  have an environment or upstream-main problem, not a task. Do not build on red.

Record the passing test count now (run `./bin/mise run test`, read the summary
line) so you can prove you added tests and broke none later. Today the suite is
**~59 `*_test.dart` files** plus the worker's vitest suite
(`cloudflare-worker/test/`). Don't hardcode a pass count in the skill — read it
live.

**Read the invariants once.** Skim `architecture-contract`'s invariant list.
The ones this campaign leans on: single catalogue write-path (`_setAllDrinks`),
stale-response token guard (`_drinksLoadToken`), empty-record pruning
(`UserDrinkState.isEmpty`), stable identity = `id + festivalId`, and schema-
version safety in `UserDataStore`.

---

# Track A — the UI

Ground rules for the whole track:

- **One widget/screen per PR.** Big-bang UI redesigns are this project's
  costliest historical failure (visual churn + cascading widget-tree rewrites).
  Ship `#413`, `#414`, `#415` as separate PRs. See `ui-and-accessibility`.
- **Accessibility is not optional.** Every new interactive element needs a
  `Semantics` wrapper with a meaningful `label` (+ `button`/`value` as
  appropriate) and a matching semantic test. See AGENTS.md and
  `docs/code/accessibility.md`.
- **#412 is already largely landed.** `MyFestivalEntry`
  (`lib/models/my_festival_entry.dart`), `BeerProvider.myFestivalEntries` /
  `favoriteEntries`, and `lib/screens/my_festival_screen.dart` (which today
  contains class `FavoritesScreen`) already exist. Don't re-create them; extend
  them. Note the issues say `FavoriteDrinkEntry` — the code already renamed it to
  `MyFestivalEntry`.

## A1 — `#411` mutators + analytics (do this first; unblocks B)

**Goal:** add `addTasting`, `removeTasting`, `setUserNotes` through the full
stack, plus the five `festival_log_*` analytics events. Today only a **binary**
tasted toggle exists (`toggleTasted`).

**Files:** `lib/domain/repositories/drink_repository.dart`,
`lib/domain/repositories/api_drink_repository.dart`,
`lib/domain/controllers/user_drink_state_controller.dart`,
`lib/providers/beer_provider.dart`, `lib/services/analytics_service.dart`,
`test/domain/controllers/user_drink_state_controller_test.dart` (+ provider and
repository tests).

**Prerequisite already landed — do NOT reintroduce the bug it fixed.** #410/#447
made repository mutators **return the persisted `UserDrinkState`**; the provider
stores that returned value via `_personalState.apply(...)`. Confirm before you
start:

```bash
./bin/mise run test test/domain/repositories/api_drink_repository_test.dart
```

**Expected:** green, and `api_drink_repository.dart`'s mutators end with
`return persisted.isEmpty ? null : persisted;`. Your new `addTasting` /
`removeTasting` must follow the same shape — compute the effect **once**, persist
it, return it. **Never call `DateTime.now()` in both the repository and the
controller for the same mutation** (that is the exact divergence #410 fixed).

**Behaviour rules (from `vision.md` §Phase 1 and #411), each testable:**

| Rule | Test to write |
|---|---|
| `addTasting` appends a `DateTime` to `tastingEvents` | count grows by 1 |
| `addTasting` **MUST NOT clear `wantToTry`** | `wantToTry` unchanged after tasting |
| `removeTasting(event)` removes the matching event by value | count shrinks by 1 |
| Removing the **last** tasting on a `wantToTry==true` drink reverts it to want-to-try | derived — assert it appears in `wantToTry` and not `tasted` afterwards; write no special-case code |
| `setUserNotes(null)` clears notes; record prunes if now empty | `isEmpty` pruning still holds |

The revert-to-want-to-try rule is **derived, not stored** — section membership
comes from `wantToTry` / `tastingEvents.isEmpty` (see `myFestivalEntries` in
`beer_provider.dart` and the rule in `vision.md`). Do not add a code path for
it; add a test that proves it falls out for free.

**Analytics (`#411`):** add these five events to `AnalyticsService` — none exist
yet (grep confirms zero `festival_log_` today):

`festival_log_viewed`, `festival_log_add_to_try`, `festival_log_mark_tasted`,
`festival_log_multiple_tasting` (fire only when `tastingCount > 1` *after* the
append), `festival_log_delete_timestamp`. Always `unawaited(...)`. Analytics is
production-only by design (`analytics_service.dart`).

**Decision you must make and document in a code comment (#411 requires it):**
rapid consecutive "Mark as Tasted" taps could append duplicate events. Either
debounce at the provider (e.g. a minimum interval between appends) **or** accept
duplicates and rely on the delete UI. State which, and why, in a comment. Don't
leave it implicit.

**Gate:**
```bash
./bin/mise run test test/domain/controllers/user_drink_state_controller_test.dart
```
**Expected:** new tests green; the four "must land first" divergence tests still
green. If a timestamp-equality test flakes → you are computing `now()` twice;
collapse to one.

**PR:** `feat(my-festival): add tasting and notes mutators` — Relates to #315,
Fixes #411.

## A2 — `#413` drink-card status badge

**Goal:** render `○` (want-to-try) / `✓` (tasted once) / `✓ N×` (tasted N times)
on the card, per `vision.md` §Visual Design. Replace the heart icon.

**Files:** `lib/widgets/drink_card.dart` (heart button is at ~lines 95–112 today;
`_buildCardSemanticLabel` at ~154–191), `test/widgets/drink_card_test.dart`.

**Do:**
- Read `drink.userState` via the existing getters (`drink.isFavorite` =
  `wantToTry`, `drink.tastingCount`). Add a `_StatusBadge`.
- Extend `_buildCardSemanticLabel` — it currently omits tasted/want-to-try
  state. Add e.g. "Added to want to try" / "Tasted 3 times".
- WCAG AA contrast, ≥24×24 px touch target if tappable, `Semantics` on the badge.

**Golden-file gotcha (verified 2026-07-02):** #413 says update goldens in
`test/widgets/goldens/` — **that directory does not exist.** The only goldens are
four PNGs in `test/goldens/` (drink-detail + style-screen). `drink_card` has **no
golden test today**. So "update goldens" here means **write a golden test first**,
then generate it:

```bash
./bin/mise run goldens:update test/widgets/drink_card_test.dart
```

Review the generated PNG by eye once (it's the baseline); thereafter the golden
diff is the regression guard. See `validation-and-qa` for golden discipline.

**Gate:** `./bin/mise run test test/widgets/drink_card_test.dart` green +
semantic test asserting the badge label. **PR:** `feat(my-festival): drink-card
want-to-try / tasted badge` — Fixes #413.

## A3 — `#414` the My Festival screen

**Goal:** two-section screen — Want to Try (alphabetical list) over Tasted
(timeline grouped by day, reverse-chronological) — replacing the current
favourites body. Rename the nav tab.

**Files:** `lib/screens/my_festival_screen.dart` (extend the existing
`FavoritesScreen`), `lib/screens/screens.dart`, `lib/main.dart` (nav tab
icon/label/semantics ~406–417), `lib/router.dart`,
`test/screens/my_festival_screen_test.dart` (new).

**Non-negotiables:**
- **KEEP the route URL `/:festivalId/favorites`.** URLs are a public contract
  (deep links, bookmarks). Rename the *tab label and icon* to "My Festival", not
  the path. This is a maintainer-confirmed unwritten rule — see `change-control`.
- **Festival-flash guard is REQUIRED from day one.** The current screen already
  has it (`if (provider.currentFestival.id != festivalId) return
  buildLoadingScaffold();`). Keep it. Removing it re-opens #397 (one-frame flash
  of the previous festival's data). See `debugging-playbook`.
- **Placeholder rows** for `entry.drink == null` (catalogue not yet loaded) —
  the current code renders a `ListTile` with the drink ID; keep an equivalent.
  `myFestivalEntries` already sorts placeholders last.
- **Empty state** when both sections are empty: a friendly browse-and-bookmark
  prompt.
- Analytics: `festival_log_viewed` via `unawaited()` in a post-frame callback in
  `initState` (the AGENTS.md pattern — deferred, one-shot).
- Both list rows and section headers need `Semantics` labels.

Use `myFestivalEntries` (returns `.wantToTry` and `.tasted`) — it's memoised on
`(_personalStateRevision, _catalogueRevision, festivalId)`; don't recompute.

**Gate — deep test, not shallow** (assert what the user sees, per AGENTS.md):
add a want-to-try drink and a tasted drink, pump, assert both appear in the right
sections and a placeholder renders for an unloaded entry.
```bash
./bin/mise run test test/screens/my_festival_screen_test.dart
```
Screen tests need a real `GoRouter` with a stub `/` route (see AGENTS.md /
`validation-and-qa`). **PR:** `feat(my-festival): My Festival screen with
want-to-try and tasted sections` — Fixes #414.

## A4 — `#415` detail screen multi-tasting + notes

**Goal:** on `lib/screens/drink_detail_screen.dart`, replace the binary Tasted
checkbox with an append-a-tasting button; show a per-event timestamp list with
confirm-before-delete; swap the heart for a bookmark toggle; add a notes editor.

**Files:** `lib/screens/drink_detail_screen.dart`,
`test/screens/drink_detail_screen_test.dart`.

**Do:**
- "Mark as Tasted" appends (calls A1's `addTasting`); label changes on repeat
  taps ("Tasted again" / "Tasted 3×").
- Timestamp list: formatted date+time per row, per-row delete with a confirm
  dialog ("Remove this tasting?"), calls `removeTasting(event)`.
- Bookmark toggle: semantic label "Add to want to try" / "Remove from want to
  try".
- Notes editor: tappable area, saves on dismiss via `setUserNotes`.
- **Marking tasted MUST NOT clear `wantToTry`** (same rule as A1). Deleting all
  timestamps on a `wantToTry` drink reverts it automatically — no special code.

**Note the two golden baselines here** (`test/goldens/drink_detail_screen_*`) —
if your layout shifts them, regenerate with
`./bin/mise run goldens:update test/screens/drink_detail_screen_screenshot_test.dart`
and review the diff.

**Gate:** `./bin/mise run test test/screens/drink_detail_screen_test.dart` green,
including a semantic test for the delete-confirm and the bookmark label. **PR:**
`feat(my-festival): detail-screen multi-tasting, timestamps and notes` —
Fixes #415.

## Fenced off within Track A

- **`#416` photos — separate milestone, does NOT block A1–A4.** Needs new
  packages (`image_picker`, `path_provider`), a `PhotoStore` abstraction, a web-
  support decision, and orphan cleanup hooked into `UserDataStore.write`
  pruning. The data model already has `photoIds`. Do it *after* the diary works.
- **`#417` `wouldRecommend` — additive, low priority.** Adds `bool?
  wouldRecommend` to `UserDrinkState`. It is **purely additive**:
  `currentSchemaVersion` stays **1**, `fromJson` already returns null for absent
  keys — **no migration**. If you do it, thread it through constructor/copyWith
  (sentinel for the nullable)/toJson/fromJson/isEmpty/==/hashCode/toString and
  pin nothing new in `PreferenceKeys` (it lives inside the per-drink JSON blob).
  It also happens to be the field the worker's `Review` already stores server-
  side — doing #417 aligns the local model with the wire contract for B2.

---

# Track B — the cloud sync

Local-first, additive, free-tier, low-ops. **Nothing here may become a read
dependency for the UI.** For run/deploy mechanics load `run-and-operate`; for
proto/AIP editing load `api-contract`; this skill sequences the campaign.

## B1 — provision D1 and deploy the existing Review API

**Goal:** stand up the already-written `Review` API on real D1. No new worker
code — it's built (`cloudflare-worker/reviews.ts`, `shared.ts`, migration
`0001_create_reviews_table.sql`) and tested (`cloudflare-worker/test/`).

**Prove it green locally first** (uses a simulated in-memory D1 — no real DB):
```bash
./bin/mise run test:worker      # tsc typecheck + vitest (workerd pool)
```
**Expected:** green. The `pretest` step copies `data/festivals.json` →
`cloudflare-worker/festivals.json` (gitignored); a bare run without that copy
fails the import.

**Provision** (one-time — `wrangler.toml:26` `database_id` is the placeholder
`00000000-...`; binding `RATINGS_DB`, db name `cbf-myfestival`):
```bash
cd cloudflare-worker
wrangler d1 create cbf-myfestival           # prints the real database_id
# paste that id into wrangler.toml → [[d1_databases]].database_id
wrangler d1 migrations apply cbf-myfestival # applies migrations/*.sql
```
The `CLOUDFLARE_API_TOKEN` needs **D1: Edit** on top of Workers Scripts: Edit.

**Gate — the 503→200 flip.** Before the binding resolves, review routes return
`503 STORAGE_UNCONFIGURED` (the worker guards on `env.RATINGS_DB`); after, `200`.
Verify against the deployed origin:
```bash
curl -sS https://data.cambeerfestival.app/health
# expect: {"status":"ok"}

# round-trip against the TEST bucket (any origin other than the prod app → test)
curl -sS -X PATCH \
  https://data.cambeerfestival.app/v1alpha/festivals/cbf2025/drinks/beer-1/review \
  -H 'Content-Type: application/json' -H 'X-Device-Id: campaign-smoke' \
  -d '{"starRating":4,"wouldRecommend":true}'
# expect 200: {"name":"festivals/cbf2025/drinks/beer-1/review","starRating":4,...}

curl -sS https://data.cambeerfestival.app/v1alpha/festivals/cbf2025/reviewSummaries/beer-1
# expect: {"name":"...","ratingCount":>=1,"averageRating":...,"recommendRate":...}
```
- **See 503 after provisioning?** The binding didn't resolve — the `database_id`
  paste is wrong or the deploy predates the migration. Re-apply, redeploy.
- **See `test` data leaking to `prod`?** Bucket resolution keys on `Origin`; only
  `https://cambeerfestival.app` → `prod`, everything else → `test` (or the
  `RATINGS_BUCKET` var). That's correct isolation, not a bug.
- Wipe test rows afterwards: `DELETE FROM reviews WHERE bucket='test'`.

The worker README (`cloudflare-worker/README.md`) has the authoritative curl set
and the PATCH body shape (`{starRating?, wouldRecommend?, updateMask?}`). **PR:**
`chore(worker): provision D1 and deploy review API` — worker changes go through
their own `cloudflare-worker.yml` pipeline; touching the worker is on the
Do-Not-Modify-without-request list (`change-control`), so confirm intent first.

## B2 — Flutter client for reviews / summaries — DECISION GATE

**Goal:** a Flutter client that reads `reviewSummaries` (community aggregate) and
writes the caller's `review`. This is the first client code; make two decisions
before writing it.

**Decision 1 — generated vs hand-written client.**

| Option | Pros | Cons |
|---|---|---|
| **Generated** `packages/myfestival_client` (openapi-generator, dart-dio) via `proto:clients:dart` | contract-faithful; regenerates when the proto moves | needs **Java** + the jar; **not run in CI**; dart-dio pulls a heavier dependency tree; the generated surface covers `DrinkEntry`, which the worker doesn't serve yet |
| **Hand-written** thin `http` client | zero new deps (existing `http`); matches `BeerApiService`'s style; targets exactly the deployed `Review` routes | you maintain the JSON shapes by hand; drifts from proto if you're not careful |

**Recommendation to weigh, not obey:** for B2's small, stable Review surface,
hand-written mirrors the existing `BeerApiService` pattern and stays free-tier /
low-dep. Reach for the generated client when B3 needs the full `DrinkEntry`
surface. Record the choice in the PR description.

**Decision 2 — device identity.** The worker identifies callers by an
`X-Device-Id` header (non-empty, ≤200 chars). The app has **no stable per-install
UUID today.** You must add one:
- New entry in `PreferenceKeys` (`lib/constants/preference_keys.dart`), e.g.
  `deviceId` → value `'device_id'`, and **pin it** in
  `test/constants/preference_keys_test.dart` (the pinning test also asserts
  uniqueness). A mistyped key reads back null and silently re-identifies the
  device every launch.
- Generate a UUID once on first read, persist it, reuse forever. Send it as
  `X-Device-Id` on every review call.

See `architecture-contract` for the PreferenceKeys registry rule and
`docs-and-writing` for issue/PR house style.

**Gate:** unit tests with a mocked `http.Client` (mockito `@GenerateNiceMocks`,
`./bin/mise run generate`) covering: summary parse, review upsert, a stable
device-id round-trips through prefs, and a network failure surfaces without
crashing the UI. **PR:** `feat(sync): review client and stable device id`.

## B3 — DrinkEntry sync — implement or explicitly descope

**Goal:** full personal-state sync (favourite, rating, note, pours) with
offline-first semantics. **Reality check first:** the `DrinkEntry` contract
exists in `proto/` but the **worker does not implement it** — only the narrower
`Review` (star + recommend) is deployed. So B3 is a fork in the road.

**First move — decide and write it down:**
- **Descope (recommended near a festival):** ship B1+B2 (community reviews +
  personal star/recommend backup) and defer full `DrinkEntry` sync. This already
  delivers a cloud backstop without building an unimplemented endpoint. File an
  issue capturing the descope.
- **Implement:** build the worker's `DrinkEntry` endpoints
  (`Get/Update/Delete/List/BatchUpdate` + `DrinkSummary` reads) to match
  `my_festival_service.proto`, add a D1 migration for the entries table, then
  build the client. This is a multi-PR sub-campaign; do not attempt in one PR.

**Impedance mismatch you must resolve (open design question).** The local model
and the wire contract do not line up 1:1:

| Local `UserDrinkState` | Wire `DrinkEntry` | Note |
|---|---|---|
| `wantToTry: bool` | `is_favourite: optional bool` | direct |
| `rating: int?` | `star_rating: optional int32` | direct |
| `notes: String?` | `note: string` (empty = none) | direct |
| `tastingEvents: List<DateTime>` | `pours: optional int32` | **lossy — per-event timestamps are NOT on the wire; only the count is** |
| `wouldRecommend` (only if #417) | `would_recommend: optional bool` | needs #417 first |

Syncing tastings through `pours` **discards timestamps** — the Tasted timeline
(A3) can't be reconstructed on another device from `pours` alone. Decide:
(a) accept count-only sync and keep timestamps device-local; or (b) extend the
contract (that's an `api-contract` change, proto-first, WIRE-breaking rules
apply — do NOT edit protos from this skill). State the choice; don't sync
silently-lossy.

**Sync mechanics the contract already provides** (see `drink_entry.proto` /
`my_festival_service.proto`): `etag` (OUTPUT_ONLY) for If-Match optimistic
concurrency (REST clients send the `If-Match` header; server returns `ABORTED`
on stale — re-fetch and retry); `allow_missing` for upsert/idempotent replay;
soft delete (returns the tombstone with `delete_time`); `filter` on
`ListDrinkEntries` (`update_time > ...`) for delta sync; `BatchUpdateDrinkEntries`
with a parallel `repeated google.rpc.Status statuses` for partial-failure
reporting.

### Ranked solution menu for the offline outbox

The client keeps a local outbox of pending mutations and flushes on reconnect.
Rank the flush strategy — each has a theory obligation you must satisfy with a
test, not a claim:

| Rank | Strategy | Idempotency | Convergence | On stale etag (`ABORTED`) |
|---|---|---|---|---|
| 1 | **Per-entry PATCH replay** (one `UpdateDrinkEntry` per queued mutation, `allow_missing=true`) | replaying the same PATCH is a no-op only if the field values are unchanged — key the outbox by `drinkId` and coalesce to **latest desired state**, not a log of deltas | last-writer-wins per field; converges once the queue drains | re-fetch entry, re-apply local desired state onto fresh etag, retry once |
| 2 | **`BatchUpdateDrinkEntries` flush** (all queued mutations in one call) | same coalescing rule; one round-trip | same as (1); fewer requests | inspect per-item `statuses`; retry only the `ABORTED` slots |
| 3 | **Full-state reconcile** (push the whole festival's entries, pull with `filter=update_time>last`) | naturally idempotent (declarative) | strongest convergence; simplest mental model | whole-push loses concurrent remote edits unless you pull-merge first |

**Recommended:** start at rank 1 (simplest, matches AIP upsert semantics), move
to rank 2 only when request volume justifies it. Rank 3 is the cleanest theory
but the heaviest; reserve it for cross-device history (vision Phase 3+).

**Theory obligations to test explicitly:**
- **Idempotency:** flushing the same outbox twice yields the same server state.
- **Convergence:** two devices editing different fields of the same entry both
  survive (field-level LWW), not one clobbering the other.
- **`ABORTED` handling:** a stale-etag write re-fetches and retries; it does not
  drop the local intent or spin forever.

These are open research questions for this project (seamless offline/online in
festival conditions) — see skill `research-frontier` for the frontier framing
and the falsifiable milestones. **Local-first invariant holds throughout:**
SharedPreferences is the UI's source of truth; a total sync failure must be
invisible to a user browsing their diary.

**PR(s):** `feat(sync): drink-entry offline outbox (per-entry replay)` etc. —
worker-side and client-side split into separate PRs; worker PRs go through
`cloudflare-worker.yml` and need explicit intent (`change-control`).

---

## Wrong paths — fenced off (each with the why)

| Don't | Why |
|---|---|
| Rename the `/:festivalId/favorites` route | URLs are a public contract; breaks deep links/bookmarks. Rename the tab *label*, not the path. |
| Clear `wantToTry` when a drink is tasted | Section membership is **derived**; a drink can be both. Clearing it loses the user's forward intent and breaks the auto-revert rule. |
| Recompute a timestamp (or id) at two layers | The #410 divergence bug. Compute once in the repository, return it, store the returned value. |
| Add a schema migration for #417 `wouldRecommend` | Purely additive nullable field; `fromJson` returns null for absent keys. `currentSchemaVersion` stays 1. |
| Ship a **non-additive** schema change now the app is released | Schema v1 + a released app = real data migrations. Additive nullable fields are safe; renames/removals are not. Route them through `UserDataStore.migrate`. |
| Put device/caller identity in resource names | The proto keeps identity in the auth context (`X-Device-Id`) precisely so sign-in upgrades are transparent. |
| Reach for Firebase Auth / paid tiers / anything needing babysitting | Free-tier, low-ops only. The deployed identity is `X-Device-Id`, not Firebase. Boring beats clever, especially during festival week. |
| Redesign the My Festival screen in one big PR | The costliest historical failure mode. One widget/screen per PR; goldens guard the rest. |
| Deploy anything risky near/during the live festival | Maintainer rule — no risky deploys in festival week. |

---

## What counts as done — measured, never eyeballed

Success is named tests passing + specific command output + reviewed golden
diffs. Never "looks right."

- **Per phase:** the phase's gate command green; new semantic tests for every new
  interactive element; golden diffs generated and reviewed; `./bin/mise run
  check` green before commit.
- **Track B:** the exact curl outputs in B1 (503→200, PATCH+GET round-trip);
  worker vitest green; client unit tests with mocked `http.Client`.
- **Final promotion:** merge to `main` deploys to staging
  (`staging.cambeerfestival.app`) via `cloudflare-worker.yml` + the Pages
  pipeline; the PR preview e2e (`test-e2e-web`) must be green. The release train
  (CalVer tag → `release-web.yml`) is a separate, deliberate step — see
  `run-and-operate`.
- **Human-only step, flag it explicitly:** an agent cannot do manual device/
  browser testing (Flutter web renders to `<canvas>`, so Playwright can't assert
  rendered UI — ADR 0005). Marking tasted, deleting a timestamp, and the offline
  flush on a real phone with patchy signal are the maintainer's to verify. Say so
  in the completion summary. Only claim "production ready" when edge cases, error
  handling, and accessibility are all covered — otherwise it's "code complete."

---

## When NOT to use this skill

- **An unrelated bug** (stale drinks after switching festival, a web crash, a
  flaky test, a CI failure) → `debugging-playbook`.
- **Editing the proto contract / AIP questions / worker endpoint patterns** →
  `api-contract`.
- **"Where does this state/logic live" / invariant questions** →
  `architecture-contract`.
- **Running, building, deploying, provisioning D1, cutting a release** →
  `run-and-operate`.
- **Is this change even allowed / which CI gate / review-comment triage** →
  `change-control`.
- **UI change discipline, semantics patterns, golden protocol** →
  `ui-and-accessibility`.
- **Open sync research questions and their falsifiable milestones** →
  `research-frontier`.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at that date:

- Issue scope/order from GitHub #315 (implementation order: #410→#411→#412→#413
  →#414→#415→#416) and issue bodies #411, #413, #414, #415, #416, #417.
- #410/#447 (mutators return `UserDrinkState`) confirmed in
  `lib/domain/repositories/api_drink_repository.dart` (mutators end
  `return persisted.isEmpty ? null : persisted;`). `toggleTasted` is a binary
  toggle whose comment defers multi-tasting to #315.
- `addTasting`/`removeTasting`/`setUserNotes` and all `festival_log_*` events
  confirmed **absent** (grep over `lib/` on 2026-07-02).
- `UserDrinkState` shape from `lib/models/user_drink_state.dart`;
  `MyFestivalEntry` + `myFestivalEntries`/`favoriteEntries` from
  `lib/providers/beer_provider.dart`; screen guard/placeholder from
  `lib/screens/my_festival_screen.dart`; heart icon + semantic label lines from
  `lib/widgets/drink_card.dart`.
- Goldens: `test/goldens/` (4 PNGs); `test/widgets/goldens/` does **not** exist
  (verified by `find`).
- Worker: `Review` API (`/review`, `/reviews`, `/reviewSummaries`) implemented in
  `cloudflare-worker/reviews.ts`; 503 `STORAGE_UNCONFIGURED` guard on
  `env.RATINGS_DB`; `X-Device-Id` identity; bucket resolution in `shared.ts`;
  placeholder `database_id` in `wrangler.toml:26`; migration
  `0001_create_reviews_table.sql`; curl set + provisioning in
  `cloudflare-worker/README.md`. The `DrinkEntry`/`drinkEntries` proto endpoints
  are **not** implemented (grep over `cloudflare-worker/*.ts`).
- Proto contract from `proto/cambeerfestival/festival/v1alpha/drink_entry.proto`
  and `my_festival_service.proto` (etag OUTPUT_ONLY, allow_missing, soft delete
  returns resource, filter, BatchUpdate + `statuses`).
- `docs/planning/rating-service/design.md` confirmed stale (Firebase +
  `RatingsService`) vs the deployed `X-Device-Id` worker.

Re-verify when things drift:

```bash
# Have the mutators / analytics events landed yet? (empty output = still open)
rg -n 'addTasting|removeTasting|setUserNotes|festival_log_' lib/

# Is the DrinkEntry sync endpoint implemented in the worker? (empty = still not)
rg -n 'drinkEntries|/entry' cloudflare-worker/*.ts

# Did the favorites route survive?
rg -n 'favorites' lib/router.dart

# Current goldens on disk
find test -path '*goldens*' -name '*.png'

# D1 still a placeholder?
rg -n 'database_id' cloudflare-worker/wrangler.toml

# Baseline
./bin/mise run check        # add MISE_ENV=claude-code-web on a 403-sandboxed box
```
