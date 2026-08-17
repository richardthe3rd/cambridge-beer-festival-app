---
name: architecture-contract
description: Load when you need to understand HOW the Cambridge Beer Festival app is built rather than how to run it — before adding a screen/model/service/sort option, before touching BeerProvider or any domain controller, before adding or changing a persisted field or SharedPreferences key, before deciding where new state or logic belongs, or when a review comment claims a layer boundary was crossed. Triggers — "where does this state live", "can a controller do IO", "is this the right place for this logic", "why is _setAllDrinks the only write path", "do I need a schema migration for this field", "what's the invariant this test is protecting", "why does the provider look like this", "is AGENTS.md's architecture section still accurate". Provides the UI→Provider→controllers→repositories→services→models layer contract, the 12 enforced invariants with file:line and the incident behind each, the storage/persistence contracts (the v2 check-in storage model per ADR 0006, schema versioning, PreferenceKeys registry, the two shipped one-time migrations), load-bearing design decisions with their rationale, and the known-weak points to stop you from re-discovering them the hard way.
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

**The app is released.** Current version is `2026.7.1+2026072401`
(`pubspec.yaml:4`), shipping to Cloudflare Pages and the Google Play
Internal track. Every fact below that says "no migration was needed" refers
to a pre-release decision. That era is over — see §3.

---

## 1. The layer contract

```
UI (lib/screens/, lib/widgets/)
   context.watch<BeerProvider>() in build(); context.read<BeerProvider>() in callbacks
   ↓ calls provider methods, never touches controllers/repositories/services directly
BeerProvider (lib/providers/beer_provider.dart, ChangeNotifier — 973 lines)
   OWNS: the six UI signals — the drinks four (_isLoading/_isRefreshing/
   _error/_refreshNotice) plus the festivals pair (_isFestivalsLoading/
   _festivalsError, consumed only by festival_menu_sheets.dart),
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
models/: Drink (= Product + Producer), Festival, LogEntry, UserDrinkState
   (a DERIVED view since v2 — see §3), MyFestivalEntry
```

### Who is allowed to do what

| Layer | May do | May NOT do |
|---|---|---|
| `domain/controllers/*` | Hold in-memory state, synchronous derivation (filter/sort/compare), synchronous mutation helpers that return the new value | `async`, network calls, `SharedPreferences` I/O (except `UserPreferencesController`), analytics, `notifyListeners()` |
| `domain/services/*` (`DrinkFilterService`, `DrinkSortService`) | Pure functions over lists of `Drink` | Any state, any I/O |
| `BeerProvider` | `await` repository calls, persist preferences, log analytics (always `unawaited`), call `notifyListeners()`, own the six loading/error signals | Contain filter/sort/comparison logic itself (delegate to controllers), write `_allDrinks` anywhere except `_setAllDrinks` |
| `domain/repositories/Api*Repository` | HTTP calls, cache reads/writes, return **persisted** state from mutators | Hold UI state, call `notifyListeners()` |
| `services/*` | Talk to the outside world (HTTP, SharedPreferences, Firebase) | Know about `Drink`/`Festival` business rules beyond parsing |

Controllers are pure and synchronous specifically so they can be unit-tested
without a Flutter binding or mocks — see the "extracted for testability"
rationale in §4.

### The `_setAllDrinks` rule — single catalogue write path

`_allDrinks` (the entire in-memory drinks catalogue) has exactly **one**
place it may be assigned: `_setAllDrinks` (`lib/providers/beer_provider.dart:796-801`).

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
`_replaceDrink` (`beer_provider.dart:806-820`, mutates by `id + festivalId`,
bumps `_personalStateRevision`, calls `_filter.recompute()`).

### The #410/#447 rule — repositories return persisted state, controllers don't recompute it

Every personal-state mutator (`toggleFavorite`, `setRating`, `toggleTasted`,
`beer_provider.dart:820-958`) follows this exact shape:

```dart
final newState = _personalState.apply(
  drink.id,
  await _drinkRepository!.toggleFavorite(currentFestival.id, drink.id),
);
_replaceDrink(drink, drink.copyWith(userState: newState));
```

The repository (`ApiDrinkRepository`, `lib/domain/repositories/api_drink_repository.dart:150-278`)
computes the mutation *once*, calls `clock.now()` *once*, persists it, and
**returns exactly what it wrote** (or `null` if the record pruned to empty —
see invariant 7). `UserDrinkStateController.apply()` (`user_drink_state_controller.dart:104-110`)
just stores that value directly — it does not re-derive it.

This exists because of issue #410 (closed by PR #447, `fd50fc2`): the
original code ran the *same* mutation twice — once in the repository with
one `DateTime.now()`, once in the controller with a second, microseconds
later `DateTime.now()` — so `updatedAt` diverged between disk and memory.
(Both layers now call `clock.now()` rather than `DateTime.now()` — see §4's
clock-injection row — but the one-timestamp-per-mutation rule is unchanged.)
Harmless for booleans; a real bug the moment a feature needs to match a
tasting event by its timestamp (multi-tasting, `addTasting`/`removeTasting`
— tracked in #315). **When you add a new personal-state mutator, always
follow this shape**: repository computes + persists + returns; controller
stores what it's given via `apply()`, never recomputes.

---

## 2. The 12 enforced invariants

Every row below is enforced by specific code — if you're touching a nearby
line, read the invariant first.

| # | Invariant | Enforcing code | Incident it fixed |
|---|---|---|---|
| 1 | `_error` / `_refreshNotice` are never both non-null | `_refreshDrinksFromNetwork` — success clears both (`beer_provider.dart:546-547`); failure-with-cached-data sets notice, clears error (`563-564`); failure-without-data sets error, clears drinks (`566-567`) | Design invariant from the SWR feature (PR #302); a UI that showed both a banner and a full error screen simultaneously would be a display bug |
| 2 | Null vs. empty-`Set` — filter fields are always `{}`, never `null` | `DrinkFilterController` fields initialised to `{}` (`drink_filter_controller.dart:62-63,67-68`); getters return `Set.unmodifiable(...)` | AGENTS.md-documented convention — empty set means "no filter active", `null` would be an ambiguous third state |
| 3 | Multi-toggle filters are `enum` + `Set<EnumValue>`, not parallel bools | `DrinkVisibilityFilter` (availableOnly/notTasted/veganOnly), persisted as `.name` string list via `UserPreferencesController.persistVisibilityFilters` (`user_preferences_controller.dart:73`) | Avoids the N-parallel-booleans anti-pattern; adding a 4th visibility filter is one enum value, not a new field everywhere |
| 4 | Analytics calls are always `unawaited(...)`, never logged for trivial values | `beer_provider.dart` e.g. lines 613, 621, 635, 644, 751/754, 775, 796, 458, 510-516; blank search explicitly skipped (`639-645`) | PR #332 (non-blocking analytics), PR #375 (stop logging expected-offline partial failures as errors) |
| 5 | Every interactive element has a `Semantics` wrapper with a real label | `overflow_menu.dart:15`, `star_rating.dart:47-49`, `breadcrumb_bar.dart:63,108,125`, `widget_builders.dart:47`, `main.dart` bottom nav | WCAG 2.1 AA / ADA / Section 508 — see skill `ui-and-accessibility` for the full pattern catalog |
| 6 | Stable identity for list lookups = `id + festivalId`, never `indexOf`/object identity | `Drink.==`/`hashCode` (`drink.dart:312-323`, empty-id → identity fallback), `_replaceDrink` matches by `d.id == old.id && d.festivalId == old.festivalId` (`beer_provider.dart:727`) | Issue #323 (missing `==`/`hashCode`) + PR #366 (immutable `Drink`, `copyWith`) — after `copyWith` the old instance is a stale snapshot no longer in the list |
| 7 | Empty personal-state records are pruned, not stored as empty JSON | `UserDrinkState.isEmpty` (`user_drink_state.dart:82`) drives the v2 prune paths in `SharedPreferencesUserDataStore` (want-to-try key and detail record removed rather than written empty); repository mutators return `null` when pruned (`api_drink_repository.dart:150-278`) | Keeps SharedPreferences from accumulating dead keys for every drink a user ever glanced at |
| 8 | The drinks catalogue has exactly one write path | `_setAllDrinks` (`beer_provider.dart:796-801`) | See §1 above |
| 9 | Stale network responses are discarded via a monotonic token | `_drinksLoadToken`, checked at `beer_provider.dart:470, 515, 544, 559, 583` | Issue #266, fixed by PR #275 — a slow in-flight `loadDrinks()` from festival A was overwriting festival B's just-loaded data after a rapid switch |
| 10 | A persisted-record payload newer than the running build is rejected, not mis-parsed | `SharedPreferencesUserDataStore.migrate` (`user_data_store.dart:604-616`) throws `FormatException` when `version > currentSchemaVersion`; `_decodeVersioned` (`:358`) catches it and treats the record as absent, **data on disk is left untouched** | Forward-compatibility fail-safe designed in from the start (no incident yet — this is the "don't create the incident" invariant, see §3) |
| 11 | A 404 from a beverage-type endpoint preserves the existing cache instead of wiping it | `BeerApiService.fetchDrinksByType` — a 404 lands in **neither** `drinksByType` nor `failedTypes` (`beer_api_service.dart:46-48,63-91`); `DrinkCacheService.merge` only overwrites types present in the fresh map (`cache_service.dart:49-62`) | A transient 404 mid-deploy (e.g. `cider.json` momentarily missing) must not blank out yesterday's cached cider list |
| 12 | A **collection** selected off the provider is observed by *identity*, never by `==` | `Selector` + `shouldRebuild: (prev, next) => !identical(prev, next)` in `festival_info_screen.dart:48`, `brewery_screen.dart:89`, `style_screen.dart:79`, `drink_detail_screen.dart:213`, `drinks_screen.dart:254` | Issue #564 (PR #570) and issue #568 (PR #575) — four screens hit this independently. See the note below for why `context.select` cannot do this |

**Invariant 12 in full, because it has caught four screens and reads as a
non-bug every time.** `context.select` does *not* compare with `identical`
or with `==` directly — it compares with `package:collection`'s
`DeepCollectionEquality` (`provider-6.1.5+1/lib/src/inherited_provider.dart:297`).
For a `List` or `Set`, that falls through to each **element's** own `==`. And
every model here deliberately overrides `==` to be id-scoped:

| Model | `==` compares | Where |
|---|---|---|
| `Drink` | `product.id` + `festivalId` | `drink.dart:321-326` |
| `Product` | `id` | `drink.dart:221-224` |
| `Producer` | `id` | `drink.dart:58-61` |
| `Festival` | `id` | `festival.dart:152-155` |

(Each falls back to `identical` when the id is empty, so unidentifiable
objects don't collapse together — that's invariant 6.)

Combine the two and you get a silent, type-safe, compiles-fine bug: a
selector on `p.drinks` or `p.allDrinks` **cannot observe a change to any
field that isn't part of the id**. A rating, favourite, tasted flag or note
changes `userState` only, so the new list compares deep-equal to the old one
and the rebuild is dropped — even though the controller genuinely assigned a
fresh list. The UI shows stale data with nothing in the logs.

What makes it survive review and testing:

- Changes that alter the collection's **length** work fine —
  `DeepCollectionEquality` compares lengths first. So search, category/style
  filters and favourites-only all behave, and a rebuild test whose control
  case uses `setSearchQuery` passes while the bug is live. That is exactly
  how #568 hid behind a green guard.
- It is not a list-identity problem, so "we assign a fresh list" reasoning
  (true, and stated in the code) does not fix it.

The fix is always `Selector` with an identity `shouldRebuild`, never a
revision counter. `Selector` subscribes independently of its host's `build()`,
so it can be scoped to just the subtree that consumes the collection —
`drinks_screen.dart:248-266` wraps only the list sliver rather than
re-indenting the whole method. A `Selector` may sit in a `slivers:` list as
long as its builder returns a sliver: it is a component element that proxies
its child's render object.

**When writing the test for this, the control case must change a
non-id field and keep the length fixed** (e.g. `setRating`), and assert the
rendered result, not just a build counter. A length-changing control case
proves nothing here.

Also load-bearing but not in the original count, because it's a
*process* invariant rather than a code invariant: **`PreferenceKeys` values
are pinned by a test** (`test/constants/preference_keys_test.dart`) — see §3.

---

## 3. Storage contracts

### UserDataStore layout and schema versioning (v2, ADR 0006)

**This section was rewritten for v2. If you are carrying a mental model of
"one `user_state_` blob per drink", that is v1 and it is gone.**

`SharedPreferencesUserDataStore` (`lib/services/user_data_store.dart`, 616
lines) stores **three independent key families**, not one blob:

| Key | Shape | Holds |
|---|---|---|
| `log_entry_{festivalId}_{id}` | JSON record | One check-in (a real, dated event). `PreferenceKeys.logEntryPrefix` |
| `want_to_try_{festivalId}` | `StringList` | The festival's want-to-try drink IDs. `PreferenceKeys.wantToTryPrefix` |
| `drink_detail_{festivalId}_{drinkId}` | JSON record | Drink-level rating, notes, photo IDs. `PreferenceKeys.drinkDetailPrefix` |

`DrinkDetail` is a record typedef local to the store
(`user_data_store.dart:15`), not a model class.

**`UserDrinkState` is now a derived view, not the stored record.** The store
composes it on `read`/`readAll` from the three families above. Its class doc
still describes it as a "unified per-drink-per-festival user state record"
— that wording predates v2; it is a projection now.

The decision behind this shape is **ADR 0006 — The Check-in as the Primary
My Festival Entity** (`docs/adr/0006-check-in-as-primary-my-festival-entity.md`),
**including its 2026-07-05 amendment**: rating and notes are *drink-level and
independent of the tasting timeline* (a user can rate a drink without
recording that they drank it, and clearing the tasting log never wipes a
rating). The ADR body's original "drink-level values are derived from the
most recent tasting" text is superseded — read the Amendments section, not
just the Decision section. `wouldRecommend` remains a reserved **per-pour**
field.

Entry and detail payloads each carry a `version` field (`schemaKey`);
**`currentSchemaVersion = 2`** (`user_data_store.dart:99`). Prune rules
differ by family and are deliberate: the want-to-try key and each detail
record are removed when they carry no signal, but **entries are pruned only
by explicit delete — a check-in is a real event and is never garbage
collected.**

### The two one-time migrations

Both run from `BeerProvider.initialize()` before any repository is
constructed, and both are gated by their own flag key so they do not rescan
on every launch.

| Migration | Method | Flag key | Does |
|---|---|---|---|
| pre-#391 → v1 | `migrateLegacyData()` (`:385`) | `personal_state_migration_v1` | Folds the three old key schemes (`favorites_`, `ratings_`, `tasting_log_`) into unified v1 blobs |
| v1 → v2 | `migrateToLogEntries()` (`:504`) | `my_festival_migration_v2` | Explodes each `user_state_` blob into log entries + a want-to-try membership + a detail record, then deletes the blob |

`migrateToLogEntries` is the reference shape for a **real, shipped**
migration in this repo, and its properties are worth copying verbatim:

- **Deterministic ids** — entry ids are UUID v5 over
  (festival, drink, timestamp, ordinal), so re-processing a blob overwrites
  rather than duplicates.
- **Crash-safe ordering** — the source blob is deleted only *after* its v2
  records are written; the completion flag is set only *after* every blob is
  processed. A crash mid-run resumes cleanly on the next launch.
- **Quarantine, don't destroy** — a blob that is unparseable, or whose
  schema is newer than this build, is left on disk and skipped.

`migrate()` (`user_data_store.dart:604-616`) is now specifically the **v1
blob** upgrade step used by `migrateToLogEntries`, not the read path for
current records:

```dart
@visibleForTesting
static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
  final version = (raw[schemaKey] as num?)?.toInt() ?? 1;
  if (version > currentSchemaVersion) {
    throw FormatException(...); // newer than this build — fail safe
  }
  return raw; // v1 and v2 blob payloads share UserDrinkState's field shape
}
```

Live v2 reads go through `_decodeVersioned` (`:358`), which applies the same
newer-than-this-build rejection to entry and detail payloads.

Two rules this design still encodes:

1. **Single upgrade point per family.** A schema change goes in the decode
   path as a new version branch — never inline at a call site.
2. **Forward-compat fail-safe.** A payload versioned higher than the running
   build cannot be safely downgraded, so it is rejected on read and **the
   stored bytes are left untouched**. A user who downgrades temporarily
   loses *visibility* of that record but never loses the data — which
   matters because the app auto-updates at different cadences per platform
   (Play staged rollout vs. instant web deploy).

### Additive vs. breaking field changes

**Additive nullable field, same schema version — no migration needed.**
Issue #417 (open at time of writing) is the reference pattern: adding
`wouldRecommend: bool?` to `UserDrinkState` for a future crowd-rating
feature. Its own description states the rule precisely:

> `currentSchemaVersion` stays at 1 — this is a purely additive field;
> `fromJson` already returns `null` for absent keys. No migration needed.

(That issue was written against v1; read "stays at 1" as "does not need a
bump". The reasoning is unchanged at v2 — `wouldRecommend` is now a
per-pour field on the entry payload, per ADR 0006's amendment.)

This works because `UserDrinkState.fromJson` (`user_drink_state.dart:130`)
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
justification no longer holds: the app is at `2026.7.1` on the Play
Internal track and Cloudflare Pages production. Any schema change from here
that isn't purely additive (see above) needs a real `migrate()` branch and
a round-trip test — do not repeat the "no users" shortcut.

### PreferenceKeys registry, pinning test, and the "add a preference" checklist

Every SharedPreferences key in the app is a named constant in
`lib/constants/preference_keys.dart` (109 lines, 16 keys) — themeMode,
visibilityFilters, hideUnavailableLegacy, excludedAllergens,
userStatePrefix (legacy v1, read-only), logEntryPrefix, wantToTryPrefix,
drinkDetailPrefix, favoritesLegacy, ratingsLegacy, tastingLogLegacyPrefix,
legacyMigrationComplete, logEntryMigrationComplete, selectedFestivalId,
drinksCachePrefix, festivalsCache. **No inline string key literals are permitted** — a
mistyped key string reads back `null` silently and the user's data is
gone with no error.

`test/constants/preference_keys_test.dart` pins every value verbatim
(`expect(PreferenceKeys.themeMode, 'themeMode')`, etc.) plus a second test
asserting all 16 are pairwise unique. **This test failing is not a bug in
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
| Time is read through `package:clock`, never `DateTime.now()` | Issue #530 / PR #560. Every staleness, retry and timestamp path calls `clock.now()`; tests drive time with `withClock(Clock.fixed(...), ...)` instead of poking provider fields. This deleted the three `@visibleForTesting` **setters** on `BeerProvider` (`lastDrinksRefresh`, `lastDrinksRefreshAttempt`, `lastFestivalsRefreshAttempt`) that existed only so tests could wind the clock back — the getters remain for assertions. `package:clock` was already transitive; promoting it to a direct dependency changed no version resolution. Caveat worth knowing: `clock.now()` reads a **zone** variable, so the "pure" controllers now have one ambient input. That is the standard Dart idiom and strictly better than `DateTime.now()`, but they are no longer referentially transparent in the strict sense. |
| `UserDataStore` is a versioned interface, not a concrete `SharedPreferences` call scattered through the app | Class doc, `user_data_store.dart:9-15`: "today a `SharedPreferencesUserDataStore` (local-first), later a synced store (vision Phase 3) with the local store as the offline cache." The interface boundary is where cloud sync (D1 + v1alpha API) will plug in without touching controllers or the provider. |
| Personal state (favourites/ratings/tastings) is catalogue-independent (#390) | `DrinkRepository.getPersonalEntries` doc (`drink_repository.dart:56-65`): "the caller can enumerate a user's favourites, ratings, and tasting history purely from the personal-data store, before (or without) the drink catalogue being fetched." Fixed the favourites-flash bug family (#310/#397) as a side effect, because the My Festival list stopped being `_allDrinks.where(...)` (whichever festival happened to be loaded) and became its own festival-scoped query. |
| Stale-while-revalidate (SWR) with two independent per-type caches | `cache_service.dart:8-19` class doc: render last-good data instantly, refresh in background, keep cache on failure. Per-*type* (not per-festival) caching specifically so a flaky `cider.json` fetch can't wipe out a good `beer.json` cache — see invariant 11. |
| The `/` route must have a `builder`, not just a `redirect` | `router.dart:76-83` comment, citing issue #386: a redirect-only route that stays put (because the provider hasn't initialized yet) leaves go_router with an empty `pages` list and no `onGenerateRoute`, which crashes with "Null check operator used on a null value" in **release** builds only. The minimal `CircularProgressIndicator` builder at `router.dart:84-85` is the fix; removing it reintroduces a release-only crash invisible in debug/tests. |
| `navigateToRoute()` pushes on every platform (no web/mobile branch since #470) | `navigation_helpers.dart:237-239` is now just `context.push(path)`. It used to branch to `context.go()` on web because `push` from inside a `ShellRoute` didn't update the browser URL bar; enabling `GoRouter.optionURLReflectsImperativeAPIs` (`router.dart`) fixed that, and `go` was disposing the calling screen and losing its scroll position (#470, PR #478). The one-line helper is kept deliberately: it is the only place that rationale is recorded, and the single seam if that flag ever has to come back off. Always use it for drill-down navigation (drink detail, brewery) rather than calling `context.go`/`context.push` directly. |
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
- **URL fragments in the *post-init* redirect** (`main.dart`'s
  `_handlePostInitRedirect`) are still dropped — it rebuilds the path from
  `segments` + query only. The router's own invalid-festival redirect no
  longer loses them: `_redirectToCurrentFestival` (`router.dart`) carries
  query and fragment across verbatim, and `test/router_test.dart`'s "URL
  fragments survive the invalid-festival redirect" pins that. The old
  lossy-behaviour test and its TODO are gone.
- **Flutter web renders to `<canvas>`**, so Playwright (the only E2E tool
  in use, per ADR 0005) can never assert on rendered UI content — a route
  can return HTTP 200 and still be showing an error state underneath.
  Accepted tradeoff; see `docs/adr/0005-e2e-testing-strategy.md` and skill
  `validation-and-qa` for what E2E actually covers here.
- ~~`_replaceDrink` mutates `_allDrinks` in place~~ — **fixed**, #564 / PR
  #570. `_replaceDrink` (`beer_provider.dart:836`) now builds a fresh list, and
  both assignment sites store `List.unmodifiable(...)`, so invariant 8 is
  enforced by the type system rather than by convention. The three screens'
  `(catalogueRevision, personalStateRevision)` tuples are gone. The counters
  themselves remain — `myFestivalEntries` still memoises against them. Note the
  wrapper is a **copy**, not a view: `_allDrinks` and the controllers' source
  are separate objects with the same contents, which is why `_replaceDrink`
  re-points the filter controller via `setSource` rather than `recompute()`.
  Fixing this exposed invariant 12 (see §2) — replacing the list was necessary
  but not sufficient, because `Drink.==` hid the change from `context.select`.
- **#523's first-named root cause is still open.** Its summary opens with "the
  provider flattens all four back into a single notification channel" — that is
  unchanged (28 `notifyListeners()` sites, one channel). Narrowing the
  *consumer* side to `context.select` suppresses the rebuild but not the
  wake-up: every selector still re-evaluates on every notification. Splitting
  the channel is a separate, larger question and has no issue open for it —
  file one before starting, don't treat it as covered by #523.
  The residue **is** now done: #563 / PR #569 removed the last bare
  `context.watch<BeerProvider>()` and the four `BeerProvider` constructor
  fields, which unblocked #533 / PR #571. One deliberate `context.watch`
  remains, in `FestivalSelectorSheet` (`festival_menu_sheets.dart:72`):
  `sortedFestivals` rebuilds a fresh list on every call, so a selector on it
  would fire on every notification anyway and suppress nothing. Don't "fix" it.
- **AGENTS.md architecture doc drift** — see the callout at the top of this
  file. `FavoritesService`/`RatingsService`/`TastingLogService` are gone;
  `UserDataStore` is reality.
- **The screen class is `MyFestivalScreen` but its route is still
  `/:festivalId/favorites`.** PR #448 renamed the underlying
  model (`FavoriteDrinkEntry` → `MyFestivalEntry`) and generalised
  `favoriteDrinks` → `myFestivalEntries`, and the class has since been renamed
  to match its file, but the URL path (`/:festivalId/favorites`) is unchanged
  **on purpose** — URLs are a public contract (see skill `change-control`'s
  unwritten rule #1). Don't be surprised the class and route disagree; don't rename
  the class without checking every import, and never rename the route.
- **The `/v1alpha` catalogue API is contract-only** (issue #432/PR #433):
  proto + generated OpenAPI + a read-only worker endpoint exist, but there
  is no production server backing MyFestival sync yet — D1 is unprovisioned
  and its binding is commented out in `cloudflare-worker/wrangler.toml`. See
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

Written 2026-07-02. **Revised 2026-08-17** against commit `36b3a3e`
(post-#575): added invariant 12 (collections are observed by identity, never
`==`) with the `DeepCollectionEquality` / id-scoped-`==` interaction behind
it; retired the two known-weak points that #563/#564 closed (PRs #569, #570,
#571, #575) and rewrote the re-verification commands that asserted those gaps
were still open; narrowed #523's remaining open item to the notification
channel alone. Line:line citations were re-checked for the sections touched,
**not** file-wide — treat other citations in this document as of the
2026-08-16 revision. Previously **revised 2026-08-16** against commit
`8fc3a5b` (post-#561), re-reading every cited file. Changes in that revision: §3 was
rewritten for the **v2 storage model** (ADR 0006) — `currentSchemaVersion`
is 2, not 1; the single `user_state_` blob is replaced by three key families;
`UserDrinkState` is a derived view; there are now two shipped one-time
migrations. Also updated: `package:clock` injection (§4), the six-not-four UI
signals (§1), PreferenceKeys 12 → 16, the released version, two new
known-weak points (#563, #564), and every shifted file:line citation.

Original verification (2026-07-02, commit `517e613`): issue numbers #390,
#410, #417 confirmed live via the GitHub API. Line counts at the 2026-08-16
revision, confirmed with `wc -l`: `beer_provider.dart` 973, `drink.dart` 356,
`festival.dart` 365, `user_drink_state.dart` 188, `log_entry.dart` 175,
`user_data_store.dart` 616, `drink_filter_controller.dart` 387,
`festival_controller.dart` 207, `user_drink_state_controller.dart` 146,
`preference_keys.dart` 109.

Re-verification commands (run these if this document feels stale):

```bash
# Confirm the doc-drift claim and single-write-path invariant still hold
grep -n "class FestivalStorageService" lib/services/storage_service.dart
grep -n "_setAllDrinks" lib/providers/beer_provider.dart

# Confirm the schema version and the v2 key families haven't moved on again
grep -n "currentSchemaVersion =" lib/services/user_data_store.dart   # expect 2
grep -n "_entryPrefix\|_wantToTryPrefix\|_detailPrefix\|_legacyPrefix" lib/services/user_data_store.dart
grep -n "Future<void> migrateLegacyData\|Future<void> migrateToLogEntries" lib/services/user_data_store.dart

# Confirm the catalogue is still replaced, not mutated (#564 stayed fixed)
grep -n "_allDrinks\[idx\] = updated" lib/providers/beer_provider.dart   # expect NO match
grep -rn "catalogueRevision, p.personalStateRevision" lib/screens/       # expect 0
grep -n "_allDrinks = List.unmodifiable" lib/providers/beer_provider.dart # expect 2 (both write sites)

# Confirm invariant 12 is still enforced at every collection-selecting screen
grep -rn "shouldRebuild: (prev, next) => !identical" lib/screens/        # expect 5
grep -rn "context.select<BeerProvider, List<" lib/                       # expect NO match — a hit is invariant 12 regressing

# Confirm #523's residue (#563) stayed fixed
grep -rn "final BeerProvider provider;" lib/widgets/                     # expect 0
grep -rn "= context.watch<BeerProvider>()" lib/                          # expect only festival_menu_sheets (deliberate)

# Confirm PreferenceKeys count and the pinning test still agree
grep -c "static const" lib/constants/preference_keys.dart
grep -c "expect(PreferenceKeys" test/constants/preference_keys_test.dart

# Confirm the release version (invalidates "no users, no migration" reasoning)
grep "^version:" pubspec.yaml

# Confirm known-weak-points are still open (re-check state, not just existence)
gh issue view 432 --json state,title 2>/dev/null || echo "use mcp__github__issue_read method=get issue_number=432 instead"

# Confirm the router redirect still preserves query + fragment
grep -n "hasFragment\|hasQuery" lib/router.dart
```

If any of these disagree with the text above, the code has moved on —
update this file, don't patch around the discrepancy elsewhere.
