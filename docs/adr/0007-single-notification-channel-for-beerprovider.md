# ADR 0007: Keep One Notification Channel for BeerProvider

**Status**: Accepted

**Date**: 2026-08-31

**Deciders**: Maintainer (richardthe3rd)

**Context**: `BeerProvider` is the only `ChangeNotifier` in `lib/`. It fronts
four well-separated, deliberately Flutter-free controllers
(`DrinkFilterController`, `FestivalController`, `UserDrinkStateController`,
`UserPreferencesController`) and flattens them into a single notification
channel with 28 `notifyListeners()` call sites. Issue #556 asked whether to
stop flattening — to split into four providers under a `MultiProvider` so a
theme change has no channel on which to reach the drinks list. Issue #577
carried the technical remainder of the same question, and explicitly gated it:
*measure first, and if the total is small against a frame budget, close this and
record the number so nobody re-opens it on intuition.* This ADR is that
measurement and that decision.

---

## The question actually being decided

Not "is one god object tidy" — it is **a purity/observability trade**.

The four controllers are pure by design. Each one's class doc states the
contract:

> All mutators are synchronous and side-effect free; callers are responsible
> for persisting and broadcasting changes.

`BeerProvider` performs persistence, analytics and `notifyListeners()` around
every controller call. The whole staged decomposition (#357 → #388 → #396 →
#398 → #399 → #402 → #403) was built behind that property, because pure logic
unit-tests without a Flutter binding, mocks, or `async`.

Making the controllers independently observable means one of:

- **push the cross-cutting concerns down into them** — `ChangeNotifier` comes
  from `package:flutter/foundation.dart`, so this costs the Flutter-free
  domain layer outright; or
- **introduce a coordinator** that owns them while widgets subscribe to the
  controllers directly — keeps purity, adds a layer.

Either is a real architectural cost. The question is whether the coupling it
buys out of is costing more.

## What was already bought

Issue #523 narrowed every consumer to `context.select`. That work is complete:
46 `context.select` sites, and exactly one deliberate bare
`context.watch<BeerProvider>()` left, in `FestivalSelectorSheet`
(`festival_menu_sheets.dart:72`), where `sortedFestivals` builds a fresh list
per call so a selector would suppress nothing.

That bought the **rebuild** saving, which is the expensive half. Eight
`test/*_rebuild_test.dart` files pin it with negative+control pairs, and
`DrinkCard.debugBuildCount` / `DrinkDetailScreen.debugBuildCount` count real
`build()` calls rather than a proxy.

What it did not buy is the **wake-up**: every mounted selector still
re-evaluates its selector function on every notification, whichever concern
changed. That residue is what #556 and #577 are about, and it had never been
measured.

## Method

A throwaway probe (deliberately not committed — see
[Consequences](#consequences)) against `test/support/app_harness.dart`'s real
`BeerProvider` over mocked repositories, with a 500-drink catalogue shaped like
a real feed (7 categories, 72 styles, 120 breweries) rather than
`createSampleDrinks`'s all-identical drinks, which would understate every facet
getter. Medians of 9 samples × 200 iterations, 3 warmup rounds.

To reproduce: write a probe under `test/`, build the catalogue as above, attach
a counting listener to `harness.provider` for part 1, and time the getters with
a median-of-samples helper for part 2. Run with
`./bin/mise run test test/<probe>.dart`.

**Caveat, stated up front**: debug-mode Dart VM widget test with asserts on,
not a dart2js release profile. The error direction is conservative — release is
faster — so these are upper bounds.

## The measurement

### 1. Notification volume — 28 call sites are not 28 fires

| Action | Notifications |
|---|---|
| Any filter/sort/search action (`setSearchQuery`, `toggleCategory`, `toggleStyle`, `setSort`, `setShowFavoritesOnly`, `setVisibilityFilter`, `setAllergenFilter`, and the `clear*` pair) | **1** |
| Any personal-state write (`toggleFavorite`, `setRating`, `toggleTasted`, `addTasting`, `setUserNotes`) | **1** |
| `setThemeMode` | **1** |
| Catalogue load (`loadDrinks`, `setFestival`) | **2** — the loading-state flip, then the data |
| **A 17-action session end to end** | **20** |

This is the number that decides the issue. The channel is not chatty: it fires
once per thing the user did.

### 2. Cost of one wake-up, 500-drink catalogue

Warm (the steady state for a burst of selectors re-running after one
notification — `DrinkFilterController._scopeCache` memoises the per-facet
scope):

| Read | 500 drinks | 50 drinks |
|---|---|---|
| **`DrinksScreen`'s entire 15-selector `build()` set** | **715–930 ns** | **315–800 ns** |
| `hasAvailableStyles` | 235 ns | 125 ns |
| `visibilityFilters.length` | 270 ns | 50 ns |
| `selectedCategories.length` | 195 ns | 45 ns |
| `myFestivalEntries` | 170 ns | 135 ns |
| `excludedAllergens.length` | 150 ns | 50 ns |
| `drinks` / `allDrinks` | 55 / 30 ns | 25 / 25 ns |

Cold — a real wake-up follows a mutation, so the scope cache is empty and the
first facet-touching selector rebuilds it. Isolated against a baseline of the
mutation on its own:

| 500 drinks | Median |
|---|---|
| `setSearchQuery` alone (baseline) | 344,810 ns |
| baseline + `hasAvailableStyles` | 342,915 ns |
| baseline + all 15 `DrinksScreen` selectors | 343,845 ns |

**The selector set is indistinguishable from zero** — nominally *below* the
baseline, i.e. inside the noise. Cold `hasAvailableStyles` reuses the scope the
re-filter has just built.

### 3. The arithmetic

20 notifications × ~930 ns ≈ **19 µs for an entire session** — about **0.1% of
a single 16 ms frame**, spread across the whole session. #577's remaining cost
is roughly three orders of magnitude below where it could matter.

### 4. #577's named worst case no longer exists

#577 called out `drinks_screen.dart:159`, `availableStyles.isNotEmpty`, which
walks the scoped list, maps, builds a `Set` and merges `_selectedStyles` to
answer a boolean. Two changes landed after it was filed:

- `hasAvailableStyles` (`drink_filter_controller.dart:113`) — a short-circuiting
  equivalent, now what the screen reads at `drinks_screen.dart:160`:
  **62,795 ns → 235 ns, a 267× reduction**;
- `DrinkFilterController._scopeCache` (`:74`) memoises the per-facet scope, so
  the facet getters share one scoped pass.

The genuinely expensive getters that remain — `stylesByCategory` (299,230 ns),
`availableStyles` (62,795 ns), `availableAllergens` (31,990 ns),
`styleCountsMap` (30,635 ns), `categoryCountsMap` (18,820 ns) — **are on no
selector path at all.** They are read inside the `Consumer`-wrapped modal
sheets (`drink_filter_sheets.dart:44,228`), which build only while a sheet is
open. They never participate in a wake-up.

---

## Decision

**Do not split `BeerProvider`.** Keep one `ChangeNotifier` fronting four pure,
Flutter-free controllers, and keep `context.select` as the discipline on the
consumer side.

The measured wake-up cost does not justify either horn of the purity trade. The
expensive half of the problem was already bought by #523 at a fraction of the
risk, and the residue is noise.

Concretely, this ADR settles:

- #556 — **closed as decided**, not deferred. Selector discipline plus pure
  controllers is judged sufficient.
- #577 — **closed**, per its own instruction to close and record the number if
  the total came back small.

**If it ever does hurt, the first lever is not the split.** Memoise the
expensive derived getters against `catalogueRevision`, exactly as
`myFestivalEntries` already does (`beer_provider.dart:186-189`). That is proven
in-repo, needs no architecture decision, and is reversible.

### What would overturn this

State plainly, so the question is reopened on evidence rather than intuition:

1. **A profile — release build, real device — showing selector evaluation in a
   frame budget.** These numbers are debug-VM upper bounds; a release
   measurement that contradicts them wins.
2. **An action that starts firing a burst.** The arithmetic rests on one
   notification per action.
   `test/beer_provider_notification_count_test.dart` goes red if that changes.
3. **A facet getter moving onto a selector path.** The expensive ones are
   currently behind `Consumer`s in modal sheets. Putting `stylesByCategory`
   (299 µs) behind a `context.select` would put ~300 µs into every wake-up on
   its own — and *then* the getter-memoisation lever applies, still not the
   split.

Growth in `BeerProvider`'s public surface is explicitly **not** a trigger. It is
68 members and rose during #523 (the revision counters), because it is the union
of four controllers' public surfaces — not accumulated cruft, and not something
tidying reduces.

## Consequences

**Easier**

- The domain layer stays Flutter-free and unit-testable without a widget
  binding — the property the entire #357→#403 decomposition was staged behind.
- Invariant 8 (one catalogue write path, `_setAllDrinks`) and invariant 12
  (collections observed by identity) stay trivially true. A split would have
  had to preserve both across four notifiers with write paths that cross
  concerns — `_replaceDrink` touches personal state *and* re-points the filter
  controller.
- The question stops being perennially reopened. That was #556's stated goal.

**Harder**

- Selector discipline remains a tax on every new consumer. A new screen that
  opens `build()` with a bare `context.watch<BeerProvider>()` re-acquires the
  full rebuild cost, and nothing in the type system stops it. The
  `test/*_rebuild_test.dart` guards are the enforcement; skill
  `architecture-contract` §2 invariant 12 is the written rule.
- Equality traps stay live. `Festival.==` is id-scoped and `Drink.==` is
  id+festivalId-scoped, so selecting a whole object or collection can be blind
  to an in-place change. A per-controller split would have dissolved these by
  removing the need to slice; instead they stay documented.
- `BeerProvider` stays large and stays the single injection point.

**Neutral**

- `test/beer_provider_notification_count_test.dart` is added as the guard on
  trigger 2. The timings are **not** asserted — wall-clock thresholds are flaky
  in CI, and the repo's precedent (#477, `navigation_stack_rebuild_test.dart`)
  is to commit the deterministic guard and record the timings in prose.

## Alternatives considered

| Alternative | Why not |
|---|---|
| **Split into four providers under `MultiProvider`** (#556's proposal) | Cleanest conceptually. Rejected on cost/benefit, not on principle: the benefit measured at ~19 µs per session, against a large mechanical diff over every call site of every delegating member, plus the purity trade above. #556 itself flagged this as "exactly the shape of sweeping change AGENTS.md warns has burned this repo before." |
| **Controllers become `ChangeNotifier`s** | The direct route to the same end, and the one #577 warns against starting from. Costs the Flutter-free domain layer outright — `ChangeNotifier` is a `package:flutter/foundation.dart` type. |
| **A coordinator owning the controllers, widgets subscribing directly** | Keeps purity, and is the strongest version of the split. Still moves every call site, and adds a layer to buy back a cost measured at noise. |
| **Per-concern `ValueNotifier`/`Listenable` exposed by `BeerProvider`** | Middle option from #577: keeps the domain pure, keeps the change inside the provider layer. Cheaper than a split, but still restructures the notification architecture for no measured gain. This is the option to revisit first if trigger 1 or 3 fires and getter memoisation proves insufficient. |
| **One channel plus a change mask so selectors can bail cheaply** | Smallest change of the four. Rejected: adds a hand-maintained enum that will drift out of sync with the 28 call sites, and buys ~930 ns. |
| **Memoise the expensive derived getters against a revision counter** | Not rejected — **held in reserve.** Needs no architecture decision, so it does not belong in an ADR as a decision. Named above as the first lever if the picture changes. |

## References

- Issue [#556](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/556) — the decision this ADR records
- Issue [#577](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/577) — the notification-channel remainder, and the "measure before building anything" gate
- Issue [#523](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/523) — the selector narrowing (PRs #550, #553, #554, #557, #559, #569, #570, #571, #575)
- Issue [#477](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/477) — the navigation-depth probe, and the precedent for committing counts rather than timings
- Issue [#350](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/350) and the #357→#403 chain — the controller decomposition whose purity this ADR preserves
- Skill `architecture-contract` §1–2 — the layer contract and the 12 enforced invariants
