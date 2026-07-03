---
name: failure-archaeology
description: Load when you need the HISTORY behind a design decision, not just its current shape — before re-investigating something that "seems broken," before proposing a fix that touches state management/storage/caching/routing/connectivity/CI/proto/testing, before re-litigating an architecture choice, or when a review comment suggests reverting something or re-adding removed code (isBenignRestorationError, runtimeType matching, catalogue-decorated favourites, Patrol/Firebase E2E). Triggers — "didn't we already try this", "why is it done this way", "has this bug happened before", "why was X removed/rejected", "what did the ADR decide", "is this still open", "what's the rejected-alternatives list". Provides symptom→root-cause→evidence→status→lesson entries for every major investigation in this repo, the explicit dead-ends/rejections section, the ADR alternatives tables, and the still-open/deferred list — so nobody re-fights a settled battle.
---

# Failure Archaeology

This is the chronicle. Every row below is a *closed* (or explicitly *still-open*)
investigation: what broke, why, the evidence trail (issue/PR/SHA/file:line), its
final status, and the one-sentence lesson to carry forward. It exists so an agent
with zero context doesn't spend a review cycle re-proposing a fix that was already
tried and rejected, or re-breaking something that was already hardened.

**Entry format (strict):** Symptom → Root cause → Evidence → Status → Lesson.

**Status vocabulary:**
- `fixed-in` — landed, cite the PR/SHA/commit message.
- `rejected-because` — proposed, explicitly turned down, with the reason.
- `still-open` — known, not yet fixed; check before assuming it's new.

All PR/issue numbers and SHAs below were checked against `git log` and the working
tree on 2026-07-02. The local clone is **shallow (~50 commits)** — anything with a
SHA was verified directly; older items are cited by PR/issue number only (correct
per GitHub, not re-derivable from `git log` here).

---

## 1. State management (BeerProvider & domain controllers)

### Rapid festival switch races the drinks fetch
- **Symptom** → switching festivals quickly showed the *previous* festival's
  drinks; a slow in-flight `loadDrinks()` overwrote the newer festival's data.
- **Root cause** → concurrent `loadDrinks()` calls, no cancellation token; the
  older completion clobbered newer state.
- **Evidence** → PR #263 (discard stale drinks responses); PR #275 added the
  `_drinksLoadToken` guard (Fixes #266). Guard checked at
  `lib/providers/beer_provider.dart:480,495,519` today (`_refreshDrinksFromNetwork`).
- **Status** → fixed-in #275, still enforced.
- **Lesson** → any async load keyed to a mutable "current selection" needs a
  monotonic token; `await` alone cannot cancel an orphaned future.

### `_currentFestival` reference goes stale after a background registry refresh
- **Symptom** → a server-side change to a festival's `availableBeverageTypes`
  (e.g. cider added) silently never loaded for the session.
- **Root cause** → `initialize()` seeds `_currentFestival` from cache, fires
  `unawaited(loadFestivals())`; the success branch only reassigned
  `_currentFestival` when it was null, so the stale cached `Festival` object
  stayed referenced while in-flight `loadDrinks` used its old types.
- **Evidence** → issue #306 (priority:high); fixed by PR #362.
- **Status** → fixed-in #362.
- **Lesson** → when a background refresh replaces a collection, re-resolve any
  held reference into the new collection by domain key, not identity.

### Empty `availableBeverageTypes` is a spurious "success" that suppresses retry for an hour
- **Symptom** → a festival with `availableBeverageTypes: []` locked the user to
  stale cache for up to an hour with no error signal.
- **Root cause** → `Future.wait([])` resolves immediately; the "complete
  failure" check is false when both drinks and failures are empty, so the
  provider treated it as success and stamped `_lastDrinksRefresh = now()`.
- **Evidence** → issue #308; fixed in `1fb41aa` (PR #382, verified in `git log`).
  Two-commit arc: first commit skipped updating the timestamp; realised that
  was insufficient and a follow-up explicitly resets
  `_lastDrinksRefresh = null` (see comment at
  `lib/providers/beer_provider.dart:487-492`) so a switch to an empty-type
  festival stays stale and retriable.
- **Status** → fixed-in #382.
- **Lesson** → "no work to do" is not "refreshed." A vacuous `Future.wait([])`
  success is a classic empty-collection trap — distinguish no-op from success
  explicitly.

### Offline resume hammers the network on every foreground
- **Symptom** → a persistently-offline user re-triggered `loadFestivals()` on
  *every* app resume.
- **Root cause** → `_lastFestivalsRefresh` set only on network success;
  cache-only init and the catch/fallback path never set it, so
  `isFestivalsDataStale` stayed true forever.
- **Evidence** → issue #307 (priority:high). Two competing semantics were
  weighed: (1) treat cache-fallback as a refresh — risks offline lockout after
  recovery — vs (2) a separate `_lastFestivalsRefreshAttempt` rate-limiter.
  Resolved by PR #336 (option 2).
- **Status** → fixed-in #336.
- **Lesson** → separate "last success" (staleness) from "last attempt"
  (rate-limit). Collapsing them creates either a retry storm or an offline
  lockout.

### In-place mutation of `Drink` with no rollback
- **Symptom (latent)** → `toggleFavorite`/`setRating`/`toggleTasted` mutated
  `Drink` fields in place; on repository throw, memory and disk diverged with
  no rollback; widgets holding a reference saw the mutation before
  `notifyListeners()`.
- **Evidence** → archived todo H4 (`docs/todos.md:112-117`, cites
  `beer_provider.dart:462,494,509` at the time); fixed by PR #366 ("make Drink
  user-state fields immutable with copyWith").
- **Status** → fixed-in #366.
- **Lesson** → after `copyWith`, the old instance is a pre-mutation snapshot
  and is no longer in the list; find items by domain key (`id + festivalId`),
  never `indexOf`/object identity. Tests must re-read from the provider after
  a mutation.

### The BeerProvider decomposition series (staged god-object teardown)
- **Arc** (all SHAs verified in `git log`) → PR #357 (DrinkFilterController) →
  #388 `e79734f` (split DrinksScreen widgets) → #396 `c353cfe` (favourites from
  personal-state store) → #398 `bb0bcf8` (UserDrinkStateController) → #399
  `175257d` (simplify controllers, remove parallel-switch boilerplate) → #402
  `1ef421b` (FestivalController) → #403 `f1a73b8` (UserPreferencesController).
  #389 `e180e6a` added complexity lint rules to CI to hold the line.
- **Status** → fixed-in (complete as of #403); enforced going forward by the
  complexity lint from #389.
- **Lesson** → extraction was staged behind data-layer prerequisites (#390/
  #391/#393) — controllers could only be pulled out once personal state
  became queryable independently of the catalogue. Don't attempt a UI/state
  refactor before its data-layer precondition lands.

---

## 2. Storage / persistence

### Personal state fragmentation → UserDataStore unification
- **Symptom (tech-debt trap)** → adding one personal field required edits in
  ~7 places; the shape couldn't represent multiple tastings/notes/photos.
- **Root cause** → three parallel key schemes — `FavoritesService`
  (`favorites_{festivalId}` StringList), `RatingsService`
  (`ratings_{festivalId}_{drinkId}` int), `TastingLogService` (single
  timestamp `tasting_log_{festivalId}|{drinkId}`) — each projected onto
  `Drink.isFavorite/rating/isTasted`.
- **Evidence** → issues #391 (record shape), #393 (persistence
  boundary/sync seam), #390 (personal data queryable *without* the catalogue —
  root cause of the favourites-flash family). Landed in `f0ed032` (PR #395,
  verified: "refactor(storage): unify personal state into a versioned
  UserDataStore") — one `UserDrinkState` per drink-per-festival behind
  `SharedPreferencesUserDataStore` (`lib/services/user_data_store.dart`).
- **Dead end explicitly rejected — no migration code shipped.** The commit
  message states this plainly: pre-release, no users with saved data to
  migrate. The companion planning doc that assumed the old shape
  (`favoriteDrinks = _drinks.where(...)`, catalogue-decorated favourites) was
  removed as stale in the same-era PR #394 ("remove stale planning docs and
  fix dangling links") and superseded by the #390 data-layer approach —
  **this is the "superseded my-festival phase-1 implementation" referenced
  elsewhere**: decorating the loaded catalogue with favourite/tasted booleans
  was abandoned in favour of a first-class, catalogue-independent store.
- **Status** → fixed-in #395 (unification), fixed-in #396 (catalogue
  independence). No-migration was a deliberate one-time decision, not a
  standing policy — a future schema change with real user data DOES need a
  migration path (see `SharedPreferencesUserDataStore`'s versioned
  `migrate()` at `lib/services/user_data_store.dart` for the mechanism that
  exists precisely so this isn't needed again).
- **Lesson** → "personal data as a decoration painted onto the loaded
  catalogue" is an inverted ownership model; make personal data a first-class
  queryable store and hydrate catalogue details onto it, not the reverse.

### Dual-mutation timestamp divergence
- **Symptom** → every mutator computed `DateTime.now()` twice — once in the
  repository (persisted), once in the controller (in memory) — so
  `updatedAt` diverged. Latent for booleans; becomes user-visible once
  multi-tasting per-timestamp deletion matches by value.
- **Evidence** → issue #410 (priority:high, "must land before
  addTasting/removeTasting"); fixed in `fd50fc2` (PR #447, verified in
  `git log`): repository mutators now *return* the persisted `UserDrinkState`;
  `UserDrinkStateController.apply()` stores that value directly instead of
  recomputing it.
- **Status** → fixed-in #447.
- **Lesson** → a mutation computes its effect once and returns it; never
  recompute "the same" derived value (timestamps, IDs) at two layers.

### Mistyped preference keys silently lose data
- **Evidence** → PR #356 centralised keys into `PreferenceKeys`
  (`lib/constants/preference_keys.dart`); AGENTS.md mandates pinning every
  key's literal value in `test/constants/preference_keys_test.dart`.
- **Status** → fixed-in #356; enforced by the pinning test going forward.
- **Lesson** → a mistyped SharedPreferences key reads back `null` and
  silently loses the user's data. Changing an existing key's *value* is a
  data migration, not a rename — the pinned test exists to force that
  decision deliberately.

### Festival-prefix key collision
- **Symptom** → prefix `tasting_log_cbf2025` also matched `cbf20250` (missing
  trailing separator).
- **Evidence** → archived todo M1 (`docs/todos.md:198-201`, cites
  `lib/services/tasting_log_service.dart:56-59` — file no longer exists,
  subsumed by the UserDataStore unification, PR #395).
- **Status** → fixed-in #395 (subsumed; the service that had the bug is gone).
- **Lesson** → prefix matching over compound keys must include the separator
  character, not just the shared substring.

### `"null"` string identifiers
- **Symptom** → `json['id'].toString()` on a null id produces the literal
  string `"null"`; multiple records collapse to id `"null"` → `ValueKey`
  collisions, wrong lookups.
- **Evidence** → issue #272 (priority:high); fixed by PR #339.
- **Status** → fixed-in #339.
- **Lesson** → never coerce a nullable id via `.toString()`; skip the record
  or synthesize a stable id instead.

---

## 3. Caching

### DrinkCacheService write race (data reverts on next cold start)
- **Symptom** → concurrent `merge()` calls each fired an unawaited
  `_persistTypes()`; last `setString` won on disk, so the next launch could
  revert to an older snapshot. In-memory state stayed correct for the
  session — the bug only showed up at the next cold start.
- **Evidence** → issue #309 (from the #302 resilience review; options
  weighed: serialise / versioned writes / coalesce → chose serialise). Fixed
  in `be8d65f` (PR #419, verified). Confirmed in current
  `lib/services/cache_service.dart`: `_writeChain` is a chained `Future` and
  `merge()` does `_writeChain = writeTask.catchError((_) {})`.
- **Second-order bug fixed in the same PR** → if `_persistTypes` threw, the
  unguarded chain became a permanently-errored future — every subsequent
  `.then()` silently skipped, disabling persistence for the whole session.
  Fixed by splitting `writeTask` (caller-observable, returned as
  `DrinkCacheUpdate.written`) from `_writeChain` (always `catchError`-guarded).
- **Status** → fixed-in #419.
- **Lesson** → serialise writes-to-shared-storage through a chained future;
  a serial queue built on a future chain must be `catchError`-guarded, or one
  failure poisons the whole chain for the rest of the session.

### Stale-while-revalidate offline caching (the feature that spawned the resilience family)
- **Evidence** → PR #302: persist last-good drinks/festivals, render cache
  immediately, refresh in background, show a dismissible notice on refresh
  failure. Its own resilience review filed #306, #307, #308, #309 (all
  covered above) *before* they hit a user.
- **Status** → fixed-in #302 plus its four follow-ups.
- **Lesson** → shipping a caching layer created a cluster of subtle
  correctness bugs by nature; "ship, then run a resilience review that files
  its own bugs" is the reusable process — see the cross-cutting lesson below.

---

## 4. Routing / deep-linking

### Deep links & browser refresh loaded the wrong festival
- **Symptom** → cold-loading `/cbf2024/...` left the app on its default
  festival; detail routes showed "Drink Not Found" for valid links.
- **Root cause** → `_handlePostInitRedirect` early-returned for valid
  festival IDs without calling `setFestival`; detail routes had no redirect
  at all.
- **Evidence** → PR #275 (Fixes #266): shared `_festivalScopeRedirect`
  applied to detail routes, plus the `_drinksLoadToken` guard. Also PR #289
  (update browser URL on web nav), PR #300 (illegal percent-encoding in style
  route).
- **Status** → fixed-in #275; two siblings still open (see §12 below).
- **Lesson** → every route that can be cold-loaded needs its own festival
  validation/redirect; a shared helper used inconsistently reproduces the bug
  route-by-route.

### Router null-check crash on the root redirect (Flutter state restoration)
- **Symptom** → `Null check operator used on a null value` at
  `navigator.dart:6047` on web release only.
- **Root cause** → the `/` route was redirect-only (no builder). While
  `BeerProvider` initialises, the redirect returns null; go_router mounts a
  `Navigator` with `pages: []` and no `onGenerateRoute`; `WidgetsApp` hardcodes
  `restorationScopeId: 'router'`; the restoration code path calls
  `widget.onGenerateRoute!`, which is null in release builds.
- **Evidence** → issue #386 (decoded via source maps from a CI e2e failure
  after the Flutter 3.44 upgrade, PR #384); fixed in `d9af94d` (PR #408,
  verified). Current fix confirmed live at `lib/router.dart` — the `/` route
  now has an explicit `builder: (context, state) => const Scaffold(body:
  Center(child: CircularProgressIndicator()))`, with an inline comment citing
  #386 by number.
- **Dead end removed** → a prior workaround, `isBenignRestorationError()`,
  downgraded *every* "Null check operator..." message on web release to
  non-fatal by string match alone. Verified deleted: `grep -rn
  "isBenignRestorationError"` across `lib/` and `test/` returns nothing. The
  e2e "no critical console errors" check (`test-e2e/app.spec.ts`) is the
  regression guard that replaced it.
- **Proposed proper fix NOT adopted** → setting
  `restorationScopeId: 'go-router'` (or similar) might bypass the hardcoded
  `'router'` scope, but changes Android/iOS back-stack restoration behavior
  and needs manual device smoke-testing before it's safe. Verified: no
  `restorationScopeId` override exists anywhere in `lib/`. Deliberately not
  taken; no upstream Flutter issue filed (no minimal repro; loosely related:
  flutter/flutter#134813).
- **Status** → fixed-in #408 (loading builder); `isBenignRestorationError`
  rejected-because too broad; `restorationScopeId` proper fix
  rejected-because (deferred, needs manual mobile testing) — still-open as a
  "nicer fix exists but isn't worth the risk" item.
- **Lesson** → a redirect-only route with no builder is a latent crash; give
  every route a builder. Catch-all "benign error" suppression by message
  string is a footgun — it hides real regressions along with the one it was
  written for.

### FavoritesScreen one-frame flash of the previous festival's favourites
- **Root cause** → `_festivalScopeRedirect` schedules `setFestival` in a
  post-frame callback and returns null, so the first frame renders against
  the *old* `currentFestival`.
- **Arc** → issue #310 → narrowed to #397 (residual one-frame window after
  the first fix) → fixed in `0656162` (PR #409, verified): the screen (now
  `FavoritesScreen` inside `lib/screens/my_festival_screen.dart`) guards with
  `buildLoadingScaffold()` whenever `currentFestival.id != route festivalId`.
  The steady-state root cause was actually fixed by #396 (favourites keyed
  independently of the catalogue), which also resolved #390.
- **Status** → fixed-in #409 (frame guard) + #396 (root cause).
- **Lesson** → deferring a state change via `addPostFrameCallback` guarantees
  at least one frame of stale render; any screen reachable that way must
  guard on route-vs-provider mismatch, not just fix the underlying data model.

---

## 5. Connectivity / platform

### `runtimeType` string-matching to classify network exceptions
- **Symptom (latent)** → `isConnectivityFailure()` matched `dart:io`
  exception types via `.runtimeType.toString()` against a hardcoded name set.
- **Constraint that killed the naive fix** → `import 'dart:io'` breaks the
  web build outright — `dart:io` types don't exist on Flutter web, so you
  can't just `import 'dart:io'` and use `is SocketException` directly in
  shared code.
- **Evidence** → issue #324; fixed in `161bdd3` (PR #376, verified) via
  conditional imports: `lib/services/connectivity_io.dart` (dart:io path) /
  `lib/services/connectivity_web.dart` (web stub, always false), selected in
  `beer_api_service.dart` by `dart.library.io`.
- **Second bug fixed in the same PR** → `HandshakeException` was dead code —
  it's a subtype of `TlsException`, which was already caught by the same
  predicate.
- **Status** → fixed-in #376; both facts now codified in AGENTS.md so
  automated reviewers don't re-suggest the runtimeType approach.
- **Lesson (now AGENTS.md facts)** → `CertificateException` and
  `HandshakeException` both `extends TlsException`; `dart:io` exceptions have
  `const` constructors; the conditional-import stub files must NOT be added
  to the `services.dart` barrel export — they're only meaningful imported
  together via the conditional-import syntax in the one file that uses them.
- **Predecessor** → archived todo C1 ("dart:io Import Breaks Web Builds").

### Other platform/error-handling fixes
- PR #331 — return a `Future` from async URL-launch handlers (a `void ...
  async` function swallows its own errors).
- PR #334 — dispose `http.Client` instances owned by repositories.
- Two sequential network calls before first render (archived todo C2) →
  `Future.wait`, later folded into the #302 SWR caching work.

---

## 6. CI / tooling / release

### Flutter 3.44 upgrade shifted crash line numbers, surfaced the router crash
- PR #384 (3.38.3→3.44.0) is what triggered issue #386 above to actually
  crash in CI. AGENTS.md documents the source-map decode workflow this
  required, including the CI-vs-local ~4-line offset caused by
  `--dart-define` inlining different string constants ("try both `line` and
  `line + 4`").
- **Status** → fixed-in #408 (the crash); the source-map decode workflow is
  now a standing tool, not a one-off (see skill `diagnostics-and-tooling`).

### Release/deploy chain traps
- **GITHUB_TOKEN cascade limitation** → a release PR merged with
  `GITHUB_TOKEN` did not re-trigger downstream deploy workflows (GitHub
  suppresses `push`-triggered workflow chaining from the default token) →
  moved to explicit `workflow_dispatch` calls (CHANGELOG 2026.5.5).
- **Empty release notes** → a silent empty `git-cliff` extraction had shipped
  at least one notes-less release; fixed by failing loudly if extraction
  produces empty output.
- PR #276 — a stray `GITHUB_REPO` env var broke git-cliff changelog
  generation.
- PR #293 — same-day releases collided on Android version codes; build
  number changed from `YYYYMMDD` to `date*100+patch`.
- PR #282 — don't trigger the Android build on functions-only changes.
- PR #299 — extracted inline CI shell into mise file-tasks
  (shellcheck+shfmt-enforced).
- PR #274 — add a bash shebang to task scripts (a task silently ran under
  the wrong shell without one).
- PR #303 — replaced `report-lcov` with Codecov for coverage gating. AGENTS.md
  codifies the resulting policy: CI is ground truth; Codecov PR comments are
  informational unless the `codecov/patch` *check* itself fails; pure
  refactors inherit prior coverage (don't add tests solely to satisfy a
  coverage-drop comment on unchanged logic).
- **Status** → all fixed-in as cited; the policies (fail-loud release notes,
  workflow_dispatch for deploys, Codecov-as-informational) are now standing
  rules, not one-off patches — see skill `change-control` for the current
  gate list.

### Staging/preview traffic polluting production analytics
- **Root cause** → `EnvironmentService.isProduction()` defaulted *unknown*
  hosts to production; Cloudflare `*.pages.dev` preview hosts weren't in the
  known-host list, so preview traffic counted as production analytics.
- **Evidence** → issue #269 (priority:high) → PR #327. Verified live in
  `lib/services/environment_service.dart`: `isProductionHost()` explicitly
  comments "Unknown hosts are not production — safer to under-count than
  pollute analytics" and returns `false` for anything not on the known-host
  allowlist.
- **Status** → fixed-in #327.
- **Lesson** → "unknown → production" defaults are data-integrity landmines.
  This bug also drove a testability pattern now standard here: extract
  `isProductionHost(String)` as a `@visibleForTesting` pure static helper so
  `kIsWeb`/`Uri.base.host` platform guards don't block VM unit tests (the
  public `isProduction()` still delegates to it).

---

## 7. Proto / API design (AIP)

Recent build-out arc, all SHAs verified in `git log`: PR #422 (buf tooling) →
#425 `4de4707` (v1alpha contract/OpenAPI/codegen) → #426 `9dfc334` (Review API
on D1) → #429 `d73ec4f` (DrinkEntry sync contract consolidation) → #430
`abbba9c` (WIRE-breaking rule + promotion path) → #433 `ba45f1a` (catalogue
API contract).

AGENTS.md encodes the following AIP facts specifically because automated
reviewers repeatedly proposed *incorrect* fixes for them — treat a proposed
fix that requires suppressing an api-linter rule as a strong signal the fix
itself is wrong:

- **AIP-154** — `etag` is `OUTPUT_ONLY`; do not add a duplicate `string etag`
  to Update *requests* (the linter's `0134::request-unknown-fields` and
  `0154::no-duplicate-etag` rules reject it). If-Match concurrency routes by
  transport: proto-native clients echo `resource.etag`; REST/HTTP clients use
  the standard `If-Match` header. Rejected reviewer claim: "OUTPUT_ONLY
  breaks OpenAPI clients" — it doesn't; document the header instead.
- **AIP-164** — a soft-delete `Delete` (sets `delete_time`, doesn't remove the
  row) must return the resource, not `google.protobuf.Empty`, so the caller
  gets the tombstone's `delete_time` and new `etag` in one round-trip.
- **AIP-132** — grandparent-scoped Lists use `type =
  "api.cambeerfestival.app/Festival"`, not `child_type`, on the `parent`
  field annotation, when the List operates above the resource's immediate
  parent (e.g. listing all `DrinkEntry` under a festival when DrinkEntry's
  immediate parent is `drinks/{drink}`).
- **AIP-235** — `BatchUpdateXxx` responses need a parallel `repeated
  google.rpc.Status statuses` field (same length as the request) so callers
  can identify and retry failed items individually; `repeated Resource items`
  alone can't represent partial failure.
- **`optional` keyword** — signal fields where "not yet set by the user" must
  be distinguishable from an explicit zero/false (rating, pour count,
  favourite) should be `optional T`, not bare `T`.

**Status** → all `rejected-because` entries above are standing doctrine, not
one-time rulings — expect automated reviewers to keep proposing these same
four fixes; the counter-argument is already written down so you don't have to
re-derive it. See skill `api-contract` for the live workflow and promotion
path.

---

## 8. Testing traps

### Patrol + Firebase Test Lab — planned in depth, then abandoned
- **Evidence** → ADR 0005 (`docs/adr/0005-e2e-testing-strategy.md`) +
  `docs/planning/archive/patrol-firebase-testing/` (confirmed on disk:
  `plan.md` 565 lines, `review.md` 775 lines, `readme-review.md` 295 lines,
  `summary.md` 271 lines — a genuinely full 4–5-week, 5-phase plan, not a
  stub).
- **Why abandoned** → setup complexity (Firebase Test Lab, GCP service
  accounts, instrumented builds), cost for a pre-release app, the Test Lab
  free tier caps at 15 tests/day, and Flutter's own `testWidgets` already
  covers widget interactions.
- **Known gap accepted, not fixed** → Flutter web renders to a `<canvas>`
  element, so Playwright (what was adopted instead) can never do meaningful
  DOM-based UI testing on web — a route can return 200 and still render an
  error state underneath. ADR 0005 documents specific reconsider-triggers;
  check it before re-proposing Patrol.
- **Status** → rejected-because (cost/complexity/free-tier cap for a
  pre-release app); Playwright adopted for URL/ARIA smoke only
  (`test-e2e/*.spec.ts`); reconsider only if the ADR's triggers fire.
- **Lesson** → matching test-infrastructure investment to project stage
  matters more than "best practice" E2E coverage; a smaller adopted tool used
  consistently beats a comprehensive tool that's too expensive to run daily.

### Recurring widget-test gotchas (each traces to a real fix, not a style preference)
- Stale references after `copyWith` → re-read from the provider after the
  mutation, don't reuse the pre-mutation reference (see §1, PR #366).
- `pumpAndSettle()` does not await in-flight provider `Future`s → always
  `await provider.setRating(...)` etc. before asserting.
- Stable identity in list operations → find by `id + festivalId`, never
  `indexOf`/object identity (see §1 and §10).
- Duplicate semantics nodes → button widgets (e.g. `FilledButton.icon`)
  synthesise a semantics node from their own text label; an extra explicit
  `Semantics(label:)` wrapper creates a second node with the same label, so
  `findsOneWidget` fails — use `findsWidgets` or the widget-predicate
  strategy instead.
- Deep vs. shallow tests → assert what the user actually sees
  (`find.text(...)`), not an internal state variable
  (`provider.currentFestival.id`).
- Screens using navigation must be wrapped in a real `GoRouter` with a stub
  `/` route, or `context.go()`/`context.push()` throws mid-test.
- `kIsWeb`-guarded logic is untestable on the VM directly — extract a pure
  `@visibleForTesting` helper (the pattern issue #269 established).

### Search jank
- **Symptom** → every keystroke ran all filters plus an analytics call.
- **Evidence** → archived todo M4 (`docs/todos.md:225-228`, cites
  `lib/screens/drinks_screen.dart:106` at the time); fixed by PR #328
  (300 ms debounce). Confirmed live: `drinks_screen.dart` debounces search at
  300 ms.
- **Status** → fixed-in #328.
- **Lesson** → any UI-driven filter/search recompute plus a network or
  analytics call needs debouncing by default, not as an afterthought once a
  user complains.

---

## 9. Models & data-quality

### Missing `==`/`hashCode` (Set/Map/contains unreliability)
- **Symptom** → `Set`/`Map`/`contains` operations on `Drink`, `Product`, or
  `Producer` were unreliable without value equality.
- **Evidence** → issue #323; fixed in `30a9a39` (PR #380, verified in
  `git log`). Fix arc is instructive, not a one-shot: keying equality on
  `product.id + festivalId` initially made *all* empty-id instances equal to
  each other, collapsing unrelated drinks into one bucket; a follow-up added
  an **empty-id → object-identity fallback** for `Product`, `Producer`,
  `Drink`, and `isSameBrewery`. Confirmed live in `lib/models/drink.dart`
  (equality/hash by `product.id + festivalId` with identity fallback).
- **Ordering dependency** → #323 deliberately waited on immutability (#366)
  landing first — "a hash based on mutable fields is incorrect" (hashing a
  field that can change after insertion breaks any hash-based collection).
- **Status** → fixed-in #380.
- **Lesson** → keyed equality needs an identity fallback for empty/missing
  keys, and hashing requires immutable fields — sequence the two fixes in
  that dependency order, don't do them in parallel.

### Availability status: fragile substring matching
- **Symptom** → a substring-matching cascade mis-bucketed "Some beer
  remaining" (~32% of one season's statuses, per the census below) as `low`;
  `notYetAvailable` was dead code; `'out'`/`'low'` false-matched inside
  `'about'`/`'below'`.
- **Evidence** → issue #348, backed by issue #349's ~900-drink census (which
  proved no ordinal availability field exists in the upstream data at all).
  Fixed by PR #360: exact-match status map, unknown text → `unknown` with the
  raw text surfaced to the UI rather than guessed at. Confirmed live in
  `lib/models/drink.dart`: `AvailabilityStatus` enum (plenty/good/low/
  veryLow/out/unknown) and an exact-match `_statusMap`. Vocabulary is
  explicitly NOT stable across festivals — the `_statusMap` carries an
  `arrived` entry (historical winter vocabulary per #348/#349 records; not
  reproduced in the current live feeds).
- **Status** → fixed-in #360.
- **Lesson** → mapping free text from an upstream feed to an enum needs exact
  matching plus explicit unknown-handling plus false-positive-guard tests —
  never assume the vocabulary is closed or stable across data drops.

### Defensive parsing of remotely-fetched files
- Issue #273 (priority:high) — hard casts in `Festival.fromJson` meant one
  malformed festival entry broke the *entire* festival list → PR #330
  (skip malformed entries, keep the rest).
- Archived todo M2 — `FestivalService` read `response.body` instead of
  `utf8.decode(response.bodyBytes)`, producing mojibake on non-ASCII
  festival names/descriptions.
- PR #381 `1260fc0` (verified) — `BeverageCategories` constants replace
  magic strings for category names.
- PR #365 — show the festival's name, not its raw ID, in the drink-detail
  app bar.
- **Status** → all fixed-in as cited.
- **Lesson** → validate-and-skip per item beats cast-and-crash the whole
  batch, every time an upstream feed is untouchable (see skill
  `change-control` for the "CAMRA feeds are untouchable" unwritten rule this
  reinforces).

---

## 10. Dead ends and rejected fixes (index)

Everything in this section was seriously attempted or seriously proposed,
then explicitly not taken. Do not re-propose these without new information.

| Dead end | What was tried/proposed | Why rejected | Evidence |
|---|---|---|---|
| Patrol + Firebase Test Lab | Full native Flutter E2E on real Android devices, 4-5 week/5-phase plan | Setup complexity (GCP service accounts, instrumented builds), cost for a pre-release app, 15 tests/day free-tier cap, widget tests already cover interactions | ADR 0005; `docs/planning/archive/patrol-firebase-testing/` (4 files, confirmed on disk) |
| `isBenignRestorationError()` | Downgrade every "Null check operator..." message on web release to non-fatal by string match | Dangerously broad — hides real regressions under the same message, not just the one it targeted | Issue #386, PR #408; verified removed (`grep` for it returns nothing) |
| `runtimeType` string-matching for network exceptions | Classify `dart:io` exceptions via `.runtimeType.toString()` name set | Fragile string-matching; also `import 'dart:io'` breaks web builds outright, forcing a conditional-import redesign anyway | Issue #324, PR #376 |
| Catalogue-decorated favourites (my-festival phase-1) | Derive `favoriteDrinks` as a filter over the loaded catalogue (`_drinks.where(...)`) | Inverts ownership: personal data can't be queried before the catalogue loads, causing the whole favourites-flash bug family; couldn't support multi-tasting/notes/photos shape | Superseded by #390 (data-layer redesign); planning doc removed in PR #394 | 
| `restorationScopeId: 'go-router'` | Proper fix for the router null-check crash (#386) by giving go_router its own restoration scope | Changes Android/iOS back-stack restoration behavior; needs manual mobile smoke-testing that wasn't done; the cheaper loading-builder fix (#408) was sufficient | Issue #386; verified no such override exists in `lib/` today |
| Migration code for UserDataStore unification | Writing a migrator from the old three-service key scheme to the new unified store | Pre-release, no users had saved data yet — a migration would have been pure unused ceremony | PR #395 commit message states this explicitly |

---

## 11. ADR rejected-alternatives tables

Full ADRs live in `docs/adr/000N-*.md`; index at `docs/adr/README.md`. Tables
below were re-read from the ADR text directly (not the discovery notes) to
avoid embellishing beyond what's actually decided.

### ADR 0001 — GitHub Actions caching strategy
**Decision**: cache only immutable downloads (pub-cache, npm), not generated/
build artifacts.

| Alternative | Verdict |
|---|---|
| Composite actions to reduce setup duplication | Deferred to a separate ADR (became ADR 0002) |
| Matrix strategy for parallel APK/AAB builds | Deferred to a separate ADR (became ADR 0003) |
| Skip tests in release workflows (avoid running twice) | Deferred — needs workflow dependencies, added later |
| Self-hosted runners (persistent cache, faster builds) | Rejected — infra overhead/security/cost not appropriate at this project's scale |

### ADR 0002 — Composite actions + test deduplication
**Decision**: one `setup-flutter-app` composite action; release workflows
trust CI's test run rather than re-running tests.

| Alternative | Verdict |
|---|---|
| Reusable workflows (`workflow_call`) | Rejected — more powerful but more complex, harder to debug, overkill for a simple setup task |
| Workflow dependencies (`workflow_run` gating releases on CI) | Rejected — `workflow_run` has quirks with tags; manual releases become harder |
| Keep the 7x duplicated setup "for clarity" | Rejected — this IS the right abstraction (Flutter setup is a cohesive unit); 7 copies across 4 files is excessive |

### ADR 0003 — Parallel build strategy
**Decision**: matrix-parallelise APK + AAB builds.

| Alternative | Verdict |
|---|---|
| Keep sequential builds | Rejected — matrix is a standard GHA feature, complexity is minimal, 32% faster releases justify it |
| Build both in one job, sequentially | Rejected — simplest but leaves available parallelism on the table |
| `workflow_call` reusable build workflow | Rejected — more complex than a matrix, overkill for only 2 build types |
| Build once in CI, reuse artifact in release | Rejected — complex artifact retention, couples release to CI workflow lifetime, artifacts expire |

### ADR 0004 — Path-based URL strategy
**Decision**: festival-scoped path URLs (`/{festivalId}/...`) with
`usePathUrlStrategy()`.

| Alternative | Verdict |
|---|---|
| Hash-based URLs (`/#/drink/123`) | Rejected — poor SEO, unprofessional appearance, not shareable on social media |
| Flat URLs with no festival scoping (`/drink/123`) | Rejected — can't distinguish the same drink ID across different festivals; can't share a link to "this year's" festival specifically |

Pre-release timing made this cheap: no existing shared URLs or search-engine
indexing to break. Known limitations accepted at decision time and tracked as
open todos, not bugs: detail routes lack festival-ID validation (H3); the
festival selector UI doesn't update the URL on switch (C3).

### ADR 0005 — E2E testing strategy
**Decision**: Playwright for URL/routing/ARIA smoke tests only.

| Alternative | Verdict |
|---|---|
| Patrol + Firebase Test Lab (native Flutter E2E) | Rejected — see §10 above |
| Flutter's own `integration_test` package | Deprioritised, not rejected — a valid option to revisit later |

Flutter web renders to `<canvas>`, so no browser-based tool can verify
rendered UI content — this is a structural limitation of the platform choice,
not a gap in the E2E tooling itself.

---

## 12. Still-open / deferred (check before assuming something is a fresh bug)

| Item | Where tracked | Status detail |
|---|---|---|
| Detail-route festival-ID validation | Archived todo H3 (`docs/todos.md:100-103`, cites `lib/router.dart:103-143`); ADR 0004 known-limitation | Accepted at ADR 0004 decision time; not yet implemented |
| Festival selector doesn't update URL on switch | Archived todo C3 (`docs/todos.md:57-60`, cites `lib/widgets/festival_menu_sheets.dart:188`) | Same ADR 0004 acceptance; not yet implemented |
| No way to navigate back from `/about` | Archived todo H6 (`docs/todos.md:136-139`, cites `lib/router.dart:28-31`, `lib/screens/about_screen.dart`) | Not yet implemented |
| Conditional-request (304) support in the Cloudflare Worker | `cloudflare-worker/worker.js` currently serves `festivals.json` with `Cache-Control: no-cache, must-revalidate` (line ~26) and proxies drink data with no `ETag`/`If-None-Match` handling of its own | No dedicated issue found in the shallow clone's history — candidate, not yet triaged; verify with `grep -n "ETag\|If-None-Match\|304" cloudflare-worker/*.js cloudflare-worker/*.ts` before assuming it's tracked |
| `restorationScopeId` proper fix for #386 | See §10 dead-ends | Deliberately deferred, not abandoned — would need manual Android/iOS smoke-testing before landing |
| Patrol/Firebase native E2E | ADR 0005 | Abandoned; reconsider only if the ADR's stated triggers fire |

---

## Cross-cutting lessons

1. **Latent-bug hygiene via reviews** — resilience reviews (#302 → #306/307/
   308/309) and data censuses (#349 → #348) file traps *before* they hit a
   user. This is a deliberate, repeatable process here, not luck.
2. **Async footguns dominate** — orphaned unawaited writes (#309/#419),
   post-frame-deferral flashes (#310/#397), `Future.wait([])` vacuous success
   (#308), double `DateTime.now()` (#410), poisoned future chains (#419),
   stale references after `copyWith`. If a bug in this codebase is subtle,
   check for one of these five shapes first.
3. **Broad suppression is dangerous** — `isBenignRestorationError` and
   `runtimeType` string-matching were both removed for being fragile/
   over-broad, even though each "worked" for its original case.
4. **Platform-conditional code needs discipline** — `dart:io` vs web,
   CI-vs-local minification offsets; conditional imports + source maps are
   the codified tools, not ad-hoc workarounds.
5. **"Unknown → production/success" defaults are landmines** — issue #269
   (unknown host → production analytics) and issue #308 (empty type list →
   success) are the same shape: an unhandled default silently means the
   dangerous thing.
6. **Ownership inversion is a recurring architecture smell** — personal data
   as a decoration on the loaded catalogue (#390) caused the entire
   favourites-flash family; making it a first-class store fixed several bugs
   at once and unblocked the controller refactor. Watch for the same
   decoration pattern anywhere a "derived" view is actually a hidden
   dependency.
7. **Resist wrong reviewer fixes** — the AGENTS.md AIP/Dart fact lists exist
   specifically because automated reviewers repeatedly proposed *incorrect*
   changes for the same handful of cases (§7 above). CI passing is ground
   truth; a review comment claiming otherwise is wrong until CI says
   otherwise.
8. **Sequence fixes by their real dependency order** — equality/hashing
   waited on immutability (#323 behind #366); controller extraction waited on
   the data-layer split (§1 decomposition series behind #390/#391/#393).
   Attempting the "later" fix first produces a worse, throwaway version of it.

---

## When NOT to use this skill

- **Live triage of something happening right now** (a test is red, a page is
  crashing, CI just failed) → use skill `debugging-playbook` for the
  symptom → discriminating-experiment → fix-pattern table. Come back here
  only once you suspect "this looks like it happened before."
- **"What does the code do today / what's the current invariant"** → use
  skill `architecture-contract` for the current, load-bearing design and its
  enforcing code locations. This skill is about history and *why*, not
  current shape.
- **"What's allowed / what gate does this change need"** → use skill
  `change-control`.

## Maintenance duty

**This file is the project's memory.** When a new investigation concludes —
whether it lands a fix, gets explicitly rejected, or is deliberately deferred
— append an entry here in the same Symptom → Root cause → Evidence → Status →
Lesson shape, under the right theme heading (add a new heading if none fits).
Do this as part of closing out the work, not as a follow-up task: an
investigation without an entry here is a battle someone else will refight.

If a dead end is discovered (a previously-rejected approach, or a fix that
gets reverted), add it to both its theme section AND the §10 dead-ends index
table.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree and `git log` on that
date: every SHA cited above (`e79734f`, `c353cfe`, `bb0bcf8`, `175257d`,
`1ef421b`, `f1a73b8`, `e180e6a`, `f0ed032`, `ffdb34b`, `d9af94d`, `be8d65f`,
`0656162`, `161bdd3`, `30a9a39`, `1fb41aa`, `1260fc0`, `fd50fc2`) was found in
`git log --oneline` (the shallow clone holds ~50 commits) with a matching
subject line. PR/issue numbers outside that window (e.g. #263, #266, #302,
#306-310, #323, #328, #339, #348-349, #356, #360, #362, #366, #376, #380-382,
#386, #390-399, #408-410, #419, #447) are cited as reported by the discovery
pass against GitHub and CHANGELOG.md — re-verify any of them with `gh issue
view <n>` or `gh pr view <n>` if you need the full discussion, since they
aren't independently checkable from local git history. ADR alternative
tables (§11) were re-read directly from `docs/adr/000{1,2,3,4,5}-*.md` rather
than trusted from secondhand notes — one embellishment (extra ADR 0004
alternatives not actually in the text) was caught and dropped during
authoring.

Re-verification one-liners:

```bash
# Confirm a cited commit still exists with the same subject
git log --oneline | grep -E "e79734f|c353cfe|bb0bcf8|175257d|1ef421b|f1a73b8"

# isBenignRestorationError should still be absent
grep -rn "isBenignRestorationError" lib/ test/

# restorationScopeId override should still be absent (dead end not adopted)
grep -rn "restorationScopeId" lib/

# The /  route builder fix for #386 is still in place
grep -n -B2 -A10 "path: '/'," lib/router.dart

# Availability status is still exact-match, not substring
grep -n "_statusMap\|AvailabilityStatus" lib/models/drink.dart

# Archived todos still list H3/C3/H6/M1/M2/M4
grep -n "^### H3\|^### C3\|^### H6\|^### M1\|^### M2\|^### M4" docs/todos.md

# ADR alternatives tables match the source docs
grep -n -A20 "Alternatives Considered" docs/adr/0001-github-actions-caching-strategy.md
grep -n -A20 "Alternatives Considered" docs/adr/0004-path-based-url-strategy.md

# Patrol/Firebase archive still present (confirms ADR 0005 dead end)
ls docs/planning/archive/patrol-firebase-testing/

# UserDataStore no-migration decision, straight from the commit message
git log -1 --format="%B" f0ed032

# Worker 304/conditional-request status (unresolved as of this writing)
grep -n "ETag\|If-None-Match\|304\|Cache-Control" cloudflare-worker/worker.js
```
