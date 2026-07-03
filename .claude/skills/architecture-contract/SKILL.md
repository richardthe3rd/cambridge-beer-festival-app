---
name: architecture-contract
description: Load when you need to understand HOW the Cambridge Beer Festival app is built rather than how to run it — before adding a screen/model/service/sort option, before touching BeerProvider or any domain controller, before adding or changing a persisted field or SharedPreferences key, before deciding where new state or logic belongs, or when a review comment claims a layer boundary was crossed. Triggers — "where does this state live", "can a controller do IO", "is this the right place for this logic", "why is _setAllDrinks the only write path", "do I need a schema migration for this field", "what's the invariant this test is protecting", "why does the provider look like this", "is AGENTS.md's architecture section still accurate". Provides the UI→Provider→controllers→repositories→services→models layer contract, the 11 enforced invariants with file:line and the incident behind each, the storage/persistence contracts (UserDataStore versioning, PreferenceKeys registry, legacy migration), load-bearing design decisions with their rationale, and the known-weak points to stop you from re-discovering them the hard way.
---

# Architecture Contract

This is the map of how the app is *built*, not how to run it (see `run-and-operate`)
or how to fix a specific bug (see `debugging-playbook` / `failure-archaeology`).
Read this before adding code to `lib/providers/`, `lib/domain/`, `lib/services/`,
or `lib/models/`, or before trusting a review comment that claims a layer
boundary was crossed.

**Known doc drift**: AGENTS.md's Architecture section still lists
`FavoritesService`, `RatingsService`, `TastingLogService` as separate
services. **These do not exist in the code.** They were unified into
`UserDataStore` (`lib/services/user_data_store.dart`) by issue #391 / PR
#395 (`f0ed032`). `lib/services/storage_service.dart` now contains only
`FestivalStorageService`. Trust this document and the code over that
paragraph of AGENTS.md.

**The app is released.** Current version is `2026.6.0+2026060500`
(`pubspec.yaml:4`), shipping to Cloudflare Pages and the Google Play
Internal track. Every fact below that says "no migration was needed" refers
to a pre-release decision. That era is over — see §3.

---

## 1. The layer contract

```
UI (lib/screens/, lib/widgets/)
   context.watch<BeerProvider>() in build(); context.read<BeerProvider>() in callbacks
   ↓ calls provider methods, never touches controllers/repositories/services directly
BeerProvider (lib/providers/beer_provider.dart, ChangeNotifier — 816 lines)
   OWNS: the four UI signals (_isLoading/_isRefreshing/_error/_refreshNotice),
   persistence (calls repos + SharedPreferences), analytics (unawaited),
   notifyListeners(), and orchestration between controllers/repositories.
   ↓ feeds loaded data in, reads derived views out
domain/controllers/  (pure, synchronous, NO Flutter / IO / async / analytics):
   DrinkFilterController, UserDrinkStateController, FestivalController,
   UserPreferencesController (the one exception: talks to SharedPreferences,
   nothing else)
   ↓ use
domain/services/: DrinkFilterService, DrinkSortService (also pure)
   ↓
domain/repositories/ interfaces: DrinkRepository, FestivalRepository
   impls: ApiDrinkRepository, ApiFestivalRepository — THIS is where IO happens
   ↓
services/: BeerApiService (HTTP), DrinkCacheService, UserDataStore
   (SharedPreferencesUserDataStore), FestivalService, FestivalCacheService,
   FestivalStorageService, AnalyticsService, EnvironmentService,
   connectivity_io/web.dart
   ↓
models/: Drink (= Product + Producer), Festival, UserDrinkState,
   MyFestivalEntry
```

### Who is allowed to do what

| Layer | May do | May NOT do |
|---|---|---|
| `domain/controllers/*` | Hold in-memory state, synchronous derivation (filter/sort/compare), synchronous mutation helpers that return the new value | `async`, network calls, `SharedPreferences` I/O (except `UserPreferencesController`), analytics, `notifyListeners()` |
| `domain/services/*` (`DrinkFilterService`, `DrinkSortService`) | Pure functions over lists of `Drink` | Any state, any I/O |
| `BeerProvider` | `await` repository calls, persist preferences, log analytics (always `unawaited`), call `notifyListeners()`, own the four loading/error signals | Contain filter/sort/comparison logic itself (delegate to controllers), write `_allDrinks` anywhere except `_setAllDrinks` |
| `domain/repositories/Api*Repository` | HTTP calls, cache reads/writes, return **persisted** state from mutators | Hold UI state, call `notifyListeners()` |
| `services/*` | Talk to the outside world (HTTP, SharedPreferences, Firebase) | Know about `Drink`/`Festival` business rules beyond parsing |

Controllers are pure and synchronous specifically so they can be unit-tested
without a Flutter binding or mocks — see the "extracted for testability"
rationale in §4.

### The `_setAllDrinks` rule — single catalogue write path

`_allDrinks` (the entire in-memory drinks catalogue) has exactly **one**
place it may be assigned: `_setAllDrinks` (`lib/providers/beer_provider.dart:715-720`).

```dart
void _setAllDrinks(List<Drink> drinks) {
  _allDrinks = drinks;
  _catalogueRevision++;
  _filter.setSource(drinks);
  _personalState.setSource(drinks);
}
```

Every call site that loads or clears the catalogue (`loadDrinks`,
`setFestival`, `_refreshDrinksFromNetwork`) goes through this method. This
guarantees `_allDrinks`, `_filter`, and `_personalState` can never drift out
of sync with each other, and `_catalogueRevision` (used to invalidate the
memoised `myFestivalEntries`, see below) always reflects reality. If you
ever see `_allDrinks = ...` written anywhere else, that is a bug — either
route it through `_setAllDrinks`, or (for a single-drink update) through
`_replaceDrink` (`beer_provider.dart:725-736`, mutates by `id + festivalId`,
bumps `_personalStateRevision`, calls `_filter.recompute()`).

### The #410/#447 rule — repositories return persisted state, controllers don't recompute it

Every personal-state mutator (`toggleFavorite`, `setRating`, `toggleTasted`,
`beer_provider.dart:739-800`) follows this exact shape:

```dart
final newState = _personalState.apply(
  drink.id,
  await _drinkRepository!.toggleFavorite(currentFestival.id, drink.id),
);
_replaceDrink(drink, drink.copyWith(userState: newState));
```

The repository (`ApiDrinkRepository`, `lib/domain/repositories/api_drink_repository.dart:128-200`)
computes the mutation *once*, calls `DateTime.now()` *once*, persists it, and
**returns exactly what it wrote** (or `null` if the record pruned to empty —
see invariant 7). `UserDrinkStateController.apply()` (`user_drink_state_controller.dart:102-108`)
just stores that value directly — it does not re-derive it.

This exists because of issue #410 (closed by PR #447, `fd50fc2`): the
original code ran the *same* mutation twice — once in the repository with
one `DateTime.now()`, once in the controller with a second, microseconds
later `DateTime.now()` — so `updatedAt` diverged between disk and memory.
Harmless for booleans; a real bug the moment a feature needs to match a
tasting event by its timestamp (multi-tasting, `addTasting`/`removeTasting`
— tracked in #315). **When you add a new personal-state mutator, always
follow this shape**: repository computes + persists + returns; controller
stores what it's given via `apply()`, never recomputes.

---

## 2. The 11 enforced invariants

Every row below is enforced by specific code — if you're touching a nearby
line, read the invariant first.

| # | Invariant | Enforcing code | Incident it fixed |
|---|---|---|---|
| 1 | `_error` / `_refreshNotice` are never both non-null | `_refreshDrinksFromNetwork` — success clears both (`beer_provider.dart:482-483`); failure-with-cached-data sets notice, clears error (`497-500`); failure-without-data sets error, clears drinks (`501-503`) | Design invariant from the SWR feature (PR #302); a UI that showed both a banner and a full error screen simultaneously would be a display bug |
| 2 | Null vs. empty-`Set` — filter fields are always `{}`, never `null` | `DrinkFilterController` fields initialised to `{}` (`drink_filter_controller.dart:31,35-36`); getters return `Set.unmodifiable(...)` | AGENTS.md-documented convention — empty set means "no filter active", `null` would be an ambiguous third state |
| 3 | Multi-toggle filters are `enum` + `Set<EnumValue>`, not parallel bools | `DrinkVisibilityFilter` (availableOnly/notTasted/veganOnly), persisted as `.name` string list via `UserPreferencesController.persistVisibilityFilters` (`user_preferences_controller.dart:73`) | Avoids the N-parallel-booleans anti-pattern; adding a 4th visibility filter is one enum value, not a new field everywhere |
| 4 | Analytics calls are always `unawaited(...)`, never logged for trivial values | `beer_provider.dart` e.g. lines 613, 621, 635, 644, 751/754, 775, 796, 458, 510-516; blank search explicitly skipped (`639-645`) | PR #332 (non-blocking analytics), PR #375 (stop logging expected-offline partial failures as errors) |
| 5 | Every interactive element has a `Semantics` wrapper with a real label | `overflow_menu.dart:15`, `star_rating.dart:47-49`, `breadcrumb_bar.dart:63,108,125`, `widget_builders.dart:47`, `main.dart` bottom nav | WCAG 2.1 AA / ADA / Section 508 — see skill `ui-and-accessibility` for the full pattern catalog |
| 6 | Stable identity for list lookups = `id + festivalId`, never `indexOf`/object identity | `Drink.==`/`hashCode` (`drink.dart:312-323`, empty-id → identity fallback), `_replaceDrink` matches by `d.id == old.id && d.festivalId == old.festivalId` (`beer_provider.dart:727`) | Issue #323 (missing `==`/`hashCode`) + PR #366 (immutable `Drink`, `copyWith`) — after `copyWith` the old instance is a stale snapshot no longer in the list |
| 7 | Empty personal-state records are pruned, not stored as empty JSON | `UserDrinkState.isEmpty` (`user_drink_state.dart:69-74`) drives `SharedPreferencesUserDataStore.write` (`user_data_store.dart:73-80`, removes the key rather than writing `{}`); repository mutators return `null` when pruned (`api_drink_repository.dart:138,165,177,199`) | Keeps SharedPreferences from accumulating dead keys for every drink a user ever glanced at |
| 8 | The drinks catalogue has exactly one write path | `_setAllDrinks` (`beer_provider.dart:715-720`) | See §1 above |
| 9 | Stale network responses are discarded via a monotonic token | `_drinksLoadToken`, checked at `beer_provider.dart:406, 451, 480, 495, 519` | Issue #266, fixed by PR #275 — a slow in-flight `loadDrinks()` from festival A was overwriting festival B's just-loaded data after a rapid switch |
| 10 | A persisted-record payload newer than the running build is rejected, not mis-parsed | `SharedPreferencesUserDataStore.migrate` (`user_data_store.dart:213-228`) throws `FormatException` when `version > currentSchemaVersion`; `_decode` catches it and treats the record as absent, **data on disk is left untouched** | Forward-compatibility fail-safe designed in from the start (no incident yet — this is the "don't create the incident" invariant, see §3) |
| 11 | A 404 from a beverage-type endpoint preserves the existing cache instead of wiping it | `BeerApiService.fetchDrinksByType` — a 404 lands in **neither** `drinksByType` nor `failedTypes` (`beer_api_service.dart:46-48,63-91`); `DrinkCacheService.merge` only overwrites types present in the fresh map (`cache_service.dart:49-62`) | A transient 404 mid-deploy (e.g. `cider.json` momentarily missing) must not blank out yesterday's cached cider list |

Also load-bearing but not in the original "11" count, because it's a
*process* invariant rather than a code invariant: **`PreferenceKeys` values
are pinned by a test** (`test/constants/preference_keys_test.dart`) — see §3.

---

## 3. Storage contracts

### UserDataStore schema versioning

`SharedPreferencesUserDataStore` (`lib/services/user_data_store.dart`)
stores one JSON blob per drink-per-festival under key
`user_state_{festivalId}_{drinkId}` (`PreferenceKeys.userStatePrefix`).
Every write stamps a `version` field (`schemaKey`, currently
`currentSchemaVersion = 1`). Every read routes through
`migrate()` — a `@visibleForTesting static` pure function
(`user_data_store.dart:213-228`) — **before** `UserDrinkState.fromJson`:

```dart
@visibleForTesting
static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
  final version = (raw[schemaKey] as num?)?.toInt() ?? 1;
  if (version > currentSchemaVersion) {
    throw FormatException(...); // newer than this build — fail safe
  }
  return raw; // v1 is current; no transforms yet
}
```

Two rules this design encodes:

1. **Single upgrade point.** When the schema needs to change, the change
   goes in `migrate()` as a new `if (version < N)` branch — never inline at
   a call site. This is the only place that has ever needed to exist, so
   far, because v1 is still the only version shipped.
2. **Forward-compat fail-safe.** A payload with a version number higher
   than the running build's `currentSchemaVersion` cannot be safely
   downgraded, so `migrate` throws; `_decode` (`user_data_store.dart:196-204`)
   catches it and treats the record as absent — **the stored bytes on disk
   are never touched**, so a user who downgrades the app temporarily loses
   *visibility* of that field but never loses the data. This matters now
   that the app auto-updates across platforms at different cadences (Play
   staged rollout vs. instant web deploy).

### Additive vs. breaking field changes

**Additive nullable field, same schema version — no migration needed.**
Issue #417 (open at time of writing) is the reference pattern: adding
`wouldRecommend: bool?` to `UserDrinkState` for a future crowd-rating
feature. Its own description states the rule precisely:

> `currentSchemaVersion` stays at 1 — this is a purely additive field;
> `fromJson` already returns `null` for absent keys. No migration needed.

This works because `UserDrinkState.fromJson` (`user_drink_state.dart:117-141`)
already treats every field defensively (`json['x'] as T? ?? default`), so an
old stored record simply parses the new field as `null` — indistinguishable
from "not yet answered." Follow this pattern for any new **optional**
signal field. It stops applying the moment you need to:
- change the *meaning* of an existing field,
- make a field non-nullable,
- reshape a field's type (e.g. `int rating` → `List<int> ratings`),
- or remove a field that older-still-installed clients might read.
Any of those is a real migration: bump `currentSchemaVersion`, add a
branch in `migrate()`, and write a test that feeds the old-shape JSON
through `migrate()` and asserts the upgraded shape.

**"No users yet, no migration" is retired.** The historical unification of
`FavoritesService`/`RatingsService`/`TastingLogService` into `UserDataStore`
(#391, #395) deliberately shipped **no migration code** because the app was
pre-release with zero installed users holding old-format data. That
justification no longer holds: the app is at `2026.6.0` on the Play
Internal track and Cloudflare Pages production. Any schema change from here
that isn't purely additive (see above) needs a real `migrate()` branch and
a round-trip test — do not repeat the "no users" shortcut.

### PreferenceKeys registry, pinning test, and the "add a preference" checklist

Every SharedPreferences key in the app is a named constant in
`lib/constants/preference_keys.dart` (79 lines, 12 keys) — themeMode,
visibilityFilters, hideUnavailableLegacy, excludedAllergens,
userStatePrefix, legacyMigrationComplete, favoritesLegacy, ratingsLegacy,
tastingLogLegacyPrefix, selectedFestivalId, drinksCachePrefix,
festivalsCache. **No inline string key literals are permitted** — a
mistyped key string reads back `null` silently and the user's data is
gone with no error.

`test/constants/preference_keys_test.dart` pins every value verbatim
(`expect(PreferenceKeys.themeMode, 'themeMode')`, etc.) plus a second test
asserting all 12 are pairwise unique. **This test failing is not a bug in
the test** — it means you changed (or collided) an on-disk key, which is a
data-loss event for existing installs. Either revert the constant or write
a migration that reads the old key before deleting it (see
`migrateLegacyData()` below for the template).

Checklist for adding a new preference (from AGENTS.md, verified against
the code):
1. Add the key to `PreferenceKeys` and add its expected literal to
   `test/constants/preference_keys_test.dart` in the same commit.
2. Add read/write to the appropriate controller/service
   (`UserPreferencesController` for theme/visibility/allergens,
   `SharedPreferencesUserDataStore` for per-drink personal fields, or a new
   service if it's neither).
3. Load it in `BeerProvider.initialize()` if it needs to be available at
   startup.
4. If you are *changing* an existing key's value rather than adding a new
   key, treat it as a migration, not a rename — the pinning test exists to
   force this to be a deliberate decision.

### Legacy migration flag (worked example of a real migration)

`PreferenceKeys.legacyMigrationComplete` (`'personal_state_migration_v1'`)
gates `SharedPreferencesUserDataStore.migrateLegacyData()`
(`user_data_store.dart:118-189`) — the one-time fold of the three pre-#391
key schemes (`favorites_{festivalId}`, `ratings_{festivalId}_{drinkId}`,
`tasting_log_{festivalId}|{drinkId}`) into unified `UserDrinkState` records,
run once from `BeerProvider.initialize()` (`beer_provider.dart:260-263`)
before any repository is constructed. It **merges** into any record
already present rather than overwriting (so a user who somehow has both
old- and new-format data doesn't lose either), then deletes the old keys.
The flag deliberately does **not** share the `user_state_` prefix, so it
cannot collide with a per-drink record key. This is the reference shape for
any future real migration: idempotent, merge-not-overwrite, delete the
source only after a successful write, gate with a flag so the scan doesn't
run on every launch.

---

## 4. Load-bearing design decisions (with the why)

| Decision | Why (from code/docs, not guesswork) |
|---|---|
| Pure, synchronous domain controllers; `BeerProvider` owns persistence + notify | Documented in each controller's class doc (e.g. `festival_controller.dart:5-14`, `drink_filter_controller.dart:6-16`): pure logic can be unit-tested without a Flutter binding, mocks, or `async`. The whole `BeerProvider` decomposition (#357→#388→#396→#398→#399→#402→#403) was staged specifically behind this property. |
| `UserDataStore` is a versioned interface, not a concrete `SharedPreferences` call scattered through the app | Class doc, `user_data_store.dart:9-15`: "today a `SharedPreferencesUserDataStore` (local-first), later a synced store (vision Phase 3) with the local store as the offline cache." The interface boundary is where cloud sync (D1 + v1alpha API) will plug in without touching controllers or the provider. |
| Personal state (favourites/ratings/tastings) is catalogue-independent (#390) | `DrinkRepository.getPersonalEntries` doc (`drink_repository.dart:56-65`): "the caller can enumerate a user's favourites, ratings, and tasting history purely from the personal-data store, before (or without) the drink catalogue being fetched." Fixed the favourites-flash bug family (#310/#397) as a side effect, because the My Festival list stopped being `_allDrinks.where(...)` (whichever festival happened to be loaded) and became its own festival-scoped query. |
| Stale-while-revalidate (SWR) with two independent per-type caches | `cache_service.dart:8-19` class doc: render last-good data instantly, refresh in background, keep cache on failure. Per-*type* (not per-festival) caching specifically so a flaky `cider.json` fetch can't wipe out a good `beer.json` cache — see invariant 11. |
| The `/` route must have a `builder`, not just a `redirect` | `router.dart:76-83` comment, citing issue #386: a redirect-only route that stays put (because the provider hasn't initialized yet) leaves go_router with an empty `pages` list and no `onGenerateRoute`, which crashes with "Null check operator used on a null value" in **release** builds only. The minimal `CircularProgressIndicator` builder at `router.dart:84-85` is the fix; removing it reintroduces a release-only crash invisible in debug/tests. |
| `navigateToRoute()` branches `context.go()` (web) vs `context.push()` (mobile) | `navigation_helpers.dart:228-240`: `push` from inside a `ShellRoute` doesn't update the browser URL bar on web, but `push` is preferred on mobile to preserve the native back-stack. Always use this helper for drill-down navigation (drink detail, brewery) rather than calling `context.go`/`context.push` directly — see AGENTS.md's Navigation pattern. |
| Analytics only fires in production | `AnalyticsService._isAnalyticsEnabled = isProduction()` (`analytics_service.dart:21`); `EnvironmentService.isProduction()`/`isProductionHost()` (`environment_service.dart`). Fixed issue #269: unknown hostnames used to default to "production", polluting real analytics with staging/preview traffic; now unknown → NOT production (under-count is the safe failure direction). `logError` is the one exception — it runs in **every** environment so Crashlytics still sees staging crashes. |
| `DefaultFestivals` hard-coded fallback | `models/festival.dart:262+` — four literal `Festival` objects (`cbf2026` active, `cbf2025`, `cbfw2025`, `cbf2024`) used only when both the network *and* the festival cache are unavailable (`FestivalController.currentFestival` getter, `festival_controller.dart:41-47`, and `BeerProvider.loadDrinks`, `beer_provider.dart:391-398`). This is a last-resort constant, not a data source to keep in sync with `data/festivals.json` — do not add new festivals here expecting them to appear in the switcher; that's the registry's job. |

---

## 5. Known-weak points (state plainly, don't paper over)

These are real, currently-open gaps. Don't rediscover them as "bugs you
found" — they're tracked.

- **Detail routes don't validate the festival ID against the drink's own
  festival scope.** Documented as a known limitation in ADR 0004
  (`docs/adr/0004-path-based-url-strategy.md:64`) and archived todo H3
  (`docs/todos.md:100-111`, historical reference only, do not add new items
  there). A `/wrong-festival/drink/beer/123` link is not currently rejected
  at the route level.
- **The festival selector UI doesn't update the URL when switching
  festivals** — ADR 0004 (line 65), archived todo C3
  (`docs/todos.md:57-68`).
- **No way to navigate back from the `/about` deep link** — archived todo
  H6 (`docs/todos.md:136-147`).
- **URL fragments are lost during the post-init redirect.** Explicitly
  marked with a `TODO` in `test/router_test.dart:666`: "Fix this by
  preserving `currentUri.fragment` in redirect URL construction." The test
  at lines 655-664 documents the current (lossy) behaviour as a known
  limitation, not a passing spec for correct behaviour.
- **Flutter web renders to `<canvas>`**, so Playwright (the only E2E tool
  in use, per ADR 0005) can never assert on rendered UI content — a route
  can return HTTP 200 and still be showing an error state underneath.
  Accepted tradeoff; see `docs/adr/0005-e2e-testing-strategy.md` and skill
  `validation-and-qa` for what E2E actually covers here.
- **AGENTS.md architecture doc drift** — see the callout at the top of this
  file. `FavoritesService`/`RatingsService`/`TastingLogService` are gone;
  `UserDataStore` is reality.
- **The class is called `FavoritesScreen` but the file is
  `lib/screens/my_festival_screen.dart`.** PR #448 renamed the underlying
  model (`FavoriteDrinkEntry` → `MyFestivalEntry`) and generalised
  `favoriteDrinks` → `myFestivalEntries`, but the screen class name and its
  URL path (`/:festivalId/favorites`) are unchanged **on purpose** — URLs
  are a public contract (see skill `change-control`'s unwritten rule #1).
  Don't be surprised the class name and file name disagree; don't rename
  the class without checking every import, and never rename the route.
- **The `/v1alpha` catalogue API is contract-only** (issue #432/PR #433):
  proto + generated OpenAPI + a read-only worker endpoint exist, but there
  is no production server backing MyFestival sync yet — D1 has a
  placeholder `database_id` (`cloudflare-worker/wrangler.toml:26`). See
  `run-and-operate` for the provisioning gap and `api-contract` for the
  proto surface itself.

---

## 6. Rules for extending

These restate and ground AGENTS.md's checklists against the actual code —
verify against AGENTS.md too, since it may have drifted further by the time
you read this.

**Adding a screen**: `lib/screens/new_screen.dart` → export from
`lib/screens/screens.dart` → add a `GoRoute` in `lib/router.dart`. If it's
festival-scoped, give it a `redirect: (context, state) =>
_festivalScopeRedirect(...)` like every other `/:festivalId/...` route
(`router.dart:93-183`) — this is what makes deep links and invalid-festival
redirects work uniformly. Every route needs a real `builder` (see §4's `/`
route rationale) — never a redirect-only route.

**Adding a model**: `lib/models/new_model.dart` with `fromJson`/`toJson`,
defensive parsing per field (variant types — see AGENTS.md's JSON Parsing
Pattern, confirmed live in `Product.fromJson`, `drink.dart:95-171`), export
from `lib/models/models.dart`, tests covering all type variants + null/
missing/wrong-type.

**Adding a service**: `lib/services/new_service.dart`, export from
`lib/services/services.dart`, constructor-injected (no singletons — see
`BeerProvider`'s constructor, `beer_provider.dart:88-100`, which accepts
every dependency as an optional named parameter for tests to override).

**Adding a sort option**: enum value in `DrinkSort`
(`lib/domain/models/drink_sort.dart`) → case in `DrinkSortService`
(`lib/domain/services/drink_sort_service.dart`) → dropdown entry in
`drinks_screen.dart`. Sorting is pure and lives entirely in the domain
service — never add sort logic to `BeerProvider` or a widget.

**Where does a new personal-state field go?** `UserDrinkState`
(`lib/models/user_drink_state.dart`) — add the field to the constructor,
`copyWith` (use the `_sentinel` pattern if the field is nullable and needs
explicit-clear semantics, see `rating`/`notes` at lines 83-93), `toJson`/
`fromJson`, `isEmpty` (decide whether this field alone should keep a record
alive — most new optional signal fields should **not** count toward
`isEmpty` if they represent low-commitment interactions, but this is a
per-field product decision, not a mechanical rule), `==`/`hashCode`, and
`toString`. Then read §3's additive-field rule to confirm you don't need a
schema bump. Do **not** add a new top-level `PreferenceKeys` entry for it —
it lives inside the existing per-drink JSON blob under `userStatePrefix`.

**Adding a new drink-visibility toggle**: add a value to
`DrinkVisibilityFilter`, not a new boolean field — see invariant 3.

**Adding a new mutator that touches personal state** (e.g. a future
`addTasting`/`removeTasting`, tracked in #315): follow the §1 #410/#447
shape exactly — repository computes, persists, and returns the value;
`UserDrinkStateController.apply()` just stores it. Do not call
`DateTime.now()` in more than one layer for the same conceptual mutation.

---

## When NOT to use this skill

- **Running, building, deploying, or provisioning anything** (dev server,
  web/Android builds, Cloudflare Pages/Worker deploys, D1 setup, festival
  data updates) → skill `run-and-operate`.
- **"Why did this break" / bug investigation / historical incidents** →
  skill `debugging-playbook` (symptom → triage) or `failure-archaeology`
  (the full chronicle with root causes and rejected fixes). This skill
  states *current* invariants and *why they exist*; those skills cover the
  process of finding a *new* bug or confirming an old one is really fixed.
- **UI/widget patterns, semantics label wording, golden test workflow,
  festival-flash guard usage** → skill `ui-and-accessibility`. This skill
  only states *that* invariant 5 (Semantics) and the festival-flash pattern
  exist and where they're enforced, not the full pattern catalog.
- **Change classification, CI gates, the Do-Not-Modify list, unwritten
  discipline rules (URL contract, free-tier-only, festival freeze)** →
  skill `change-control`.
- **Proto/AIP API design questions, worker implementation patterns** →
  skill `api-contract`.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at commit `517e613`
(the tip at time of writing) by direct file reads. Every file:line citation
above was opened and read in full; issue numbers #390, #410, #417 were
confirmed live via the GitHub API (title, body, state). Line counts:
`beer_provider.dart` 816, `drink.dart` 348, `festival.dart` 354,
`user_drink_state.dart` 175, `drink_filter_controller.dart` 241,
`festival_controller.dart` 206, `user_drink_state_controller.dart` 144 —
all confirmed with `wc -l` against the actual files.

Re-verification commands (run these if this document feels stale):

```bash
# Confirm the doc-drift claim and single-write-path invariant still hold
grep -n "class FestivalStorageService" lib/services/storage_service.dart
grep -n "_setAllDrinks" lib/providers/beer_provider.dart

# Confirm the schema version and migrate() shape haven't changed
grep -n "currentSchemaVersion\|static Map<String, dynamic> migrate" lib/services/user_data_store.dart

# Confirm PreferenceKeys count and the pinning test still agree
grep -c "static const" lib/constants/preference_keys.dart
grep -c "expect(PreferenceKeys" test/constants/preference_keys_test.dart

# Confirm the release version (invalidates "no users, no migration" reasoning)
grep "^version:" pubspec.yaml

# Confirm known-weak-points are still open (re-check state, not just existence)
gh issue view 432 --json state,title 2>/dev/null || echo "use mcp__github__issue_read method=get issue_number=432 instead"

# Re-read the fragment-loss TODO to confirm it hasn't been fixed
sed -n '650,667p' test/router_test.dart
```

If any of these disagree with the text above, the code has moved on —
update this file, don't patch around the discrepancy elsewhere.
