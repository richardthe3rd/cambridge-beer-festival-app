---
name: ui-and-accessibility
description: Load BEFORE touching any file under lib/screens/, lib/widgets/, lib/main.dart, or lib/app_theme.dart — any visual change, new screen, restyle, "make this look nicer," redesign, new widget, colour/theme change, or accessibility fix. Triggers — "redesign the drinks screen", "add a badge to the drink card", "restyle this", "add Semantics", "make it accessible", "update the golden", "change the bottom nav", "add a route", "per-festival theme", "My Festival status badges". Provides the UI-change discipline that prevents this project's costliest historical failure mode (sweeping redesigns), a shared-widget reuse table, the WCAG 2.1 AA Semantics catalogue, the screen patterns that must never regress (festival-flash guard, four-signal loading/error UI, navigateToRoute), and My Festival's visual-design constraints.
---

# UI and Accessibility

This skill has two jobs, in priority order:

1. **Stop UI changes from becoming redesigns.** This is not a style preference —
   it is the single costliest failure mode in this project's history (maintainer-confirmed).
2. **Give you the accessibility and widget-pattern catalogue** so new UI meets the
   bar this project already holds, without re-deriving it from scratch.

If you are only changing `lib/domain/`, `lib/providers/`, or `lib/services/` with
no visible UI change, see skill `architecture-contract` instead — this skill
does not apply. If you're only fixing/writing tests, see `validation-and-qa`. If
you're implementing the My Festival campaign end-to-end, see `my-festival-campaign`
for sequencing — come back here for the visual/accessibility rules it must follow.

---

## Part 1 — UI-change discipline (read this first, every time)

### Why this section exists

The project's principal engineer built this app largely solo, now with AI agents
doing most of the typing. A sweeping visual redesign — restyle *and* restructure
several screens in one pass — produces a diff too large for one human to review
carefully, and too large for an agent to verify against the accessibility bar
without missing something. Past redesigns cost more engineering time than any
other category of change in this repo's history. The rules below exist because
that failure mode is expensive and it has already happened.

### The hard rules

1. **One widget or one screen per PR.** Do not restyle `DrinksScreen` and
   `DrinkCard` and `FestivalHeader` in the same change. If a task seems to need
   all three, split it into sequential PRs — each independently reviewable and
   revertible.

2. **Restyle OR restructure — never both in the same change.**
   - *Restyle* = colours, spacing, typography, icons, chip shapes — the widget
     tree shape is unchanged.
   - *Restructure* = changing which widgets exist, how they nest, or what data
     flows into them.
   - Mixing the two means a visual regression and a logic regression look
     identical in the diff — you cannot `git revert` one without the other, and
     a reviewer cannot separate "this looks different" from "this broke."

3. **Never rename or move a route path.** URLs are a public contract — see
   skill `change-control` for the full unwritten-rules list. Concretely for UI
   work: the "My Festival" rename (issue #414) renames the **nav label and
   icon**, not the route. The route stays `/:festivalId/favorites`
   (`lib/router.dart:111`, `FavoritesScreen` class in
   `lib/screens/my_festival_screen.dart`) even though the tab text changes to
   "My Festival." A visual/branding rename is never a licence to touch
   `router.dart` path strings.

4. **Prefer extending an existing widget over creating a parallel one.** Before
   writing a new widget, check the reuse table below — this project has a
   deliberately small shared-component set (`HeroInfoCard`, `InfoChip`,
   `SectionHeader`, `BottomActionBar`/`ActionButton`, `BreadcrumbBar`,
   `buildOverflowMenu`, the filter sheets). A second widget that does 90% of
   what an existing one does is scope creep and a maintenance burden for a
   solo maintainer.

5. **Every visual change updates goldens DELIBERATELY — never blind-regenerate.**
   This repo has exactly 4 golden files, all under `test/goldens/`:
   `drink_detail_screen_long_name_light.png`, `drink_detail_screen_medium_name_light.png`,
   `style_screen_with_description_dark.png`, `style_screen_with_description_light.png`.
   If your change touches `DrinkDetailScreen` or `StyleScreen`, run
   ```bash
   ./bin/mise run goldens:update test/screens/drink_detail_screen_screenshot_test.dart
   # or the relevant _screenshot_test.dart file
   ```
   then **open the resulting PNG and look at it** — confirm the pixel diff is the
   change you intended and nothing else moved. Do not run a bare
   `goldens:update` with no file argument as a reflex "fix the failing test"
   move; that regenerates every golden and silently launders any unintended
   visual drift into the baseline. See skill `validation-and-qa` for the full
   golden-update protocol and how CI checks these.

6. **Keep the shell/transition structure intact.** `router.dart` nests two
   `ShellRoute`s: an outer one wrapping every route in `ProviderInitializer`
   (`lib/main.dart`), and an inner one wrapping only `/:festivalId` and
   `/:festivalId/favorites` in `BeerFestivalHome` (adds the bottom
   `NavigationBar`). Both of those routes use `NoTransitionPage` deliberately —
   switching tabs should not animate like a page push. Do not add page
   transitions to these two routes, and do not move a route between the outer
   and inner shell without checking whether it needs the bottom nav (detail
   routes — drink/brewery/style/info — deliberately sit outside the inner
   shell so they get no bottom nav, per `docs/code/ui-components.md`).

7. **Check both light and dark themes before calling a visual change done.**
   `lib/app_theme.dart:buildAppTheme(Brightness)` branches on brightness for
   `primary`, `AppBarTheme`, and `navigationBarTheme.indicatorColor` — a colour
   that looks fine in light mode can have broken contrast in dark mode. Two of
   the four golden tests exist specifically to catch this
   (`style_screen_with_description_dark.png` / `_light.png`).

### A worked example of the rule in action

Adding a status badge to `DrinkCard` for My Festival (planned, see Part 6) is a
**restyle** — it adds a small icon/badge to an existing widget without changing
what the card contains or how it's laid out elsewhere. That is one PR, scoped
to `lib/widgets/drink_card.dart` (+ its test), with goldens reviewed if
`DrinkDetailScreen`'s card rendering is affected. It is explicitly **not** a
licence to also reflow the card's internal `Row`/`Column` structure, change its
elevation, or touch `drinks_screen.dart`'s list layout in the same PR.

---

## Part 2 — Widget standards

Verified against `docs/code/widget-standards.md` and the actual widget files
under `lib/widgets/` on 2026-07-02.

### Checklist (every new/changed widget)

- [ ] `const` constructor, `const` used wherever the compiler allows it
- [ ] Single quotes for string literals
- [ ] `child`/`children` last among named parameters
- [ ] `final` for local variables
- [ ] Tappable elements have a `Key` findable via `find.byKey(const ValueKey('...'))`
      in tests — e.g. `lib/screens/drinks_screen.dart:356` and
      `lib/screens/my_festival_screen.dart:70` both key drink-card list items on
      `ValueKey(drink.id)`
- [ ] Content text (drink name, brewery, notes) uses `SelectableText`, not
      `Text` — UI labels/nav/button text stay as plain `Text`
      (`docs/code/widget-standards.md`); see `lib/widgets/hero_info_card.dart`'s
      `HeroInfoRow` for the pattern
- [ ] `Semantics` wraps only the interactive element, not a whole decorative row
      (see Part 3)
- [ ] Text with unbounded width has explicit `overflow`/`maxLines`

### Shared-component reuse table

Check this before writing a new widget. All paths relative to `lib/widgets/`
unless noted.

| Need | Use | File | Notes |
|---|---|---|---|
| Prominent "key facts" card at top of a detail screen (style, availability, ABV) | `HeroInfoCard` + `HeroInfoRow` | `hero_info_card.dart` | Rows take an icon + `SelectableText`; optional `semanticLabel` collapses icon+text into one announcement |
| Small metadata pill (style, dispense, bar location) | `InfoChip` | `info_chip.dart` | Optional `onTap` makes it a `Semantics(button: true)` link |
| Section title with underline on a detail screen | `SectionHeader` | `section_header.dart` | `showSeparator` toggles the underline |
| Sticky bottom row of actions (tasting log, rate, favourite, share) | `BottomActionBar` + `ActionButton` | `bottom_action_bar.dart` | `ActionButton.isActive` drives colour + `FontWeight`; `semanticLabel` overrides the visible label for screen readers |
| Back-navigation header on a detail screen (drink/brewery/style) | `BreadcrumbBar` | `breadcrumb_bar.dart` | Only the `IconButton` gets `Semantics`, never the text row — see the "BAD" example in `docs/code/widget-standards.md`. 28px icon → 48×48 touch target. Text segments only become tappable/underlined when a callback is provided |
| Three-dot menu for festival switch / settings / about | `buildOverflowMenu(context)` | `overflow_menu.dart` | A function, not a widget class — `docs/code/ui-components.md` documents where to include it (Drinks, My Festival screen) and where not to (detail screens, About, modals) |
| Modal filter pickers (category, style, sort, visibility) | `showCategoryFilter` / `showStyleFilter` / `showSortOptions` / `showVisibilityFilter` | `drink_filter_sheets.dart` | All route through the private `_showSheet` helper (`isScrollControlled: true`) and share `_SheetHandle` — add a new filter type by adding a sheet class + show-function here, not a bespoke `showModalBottomSheet` call elsewhere |
| Star rating display or picker | `StarRating` | `star_rating.dart` | `isEditable` toggles read-only vs tap-to-rate; semantic `value` is always `'$rating out of 5 stars'` |
| Availability / category / rating pills on a drink card | `_AvailabilityChip` / `_RatingChip` / `_CategoryChip` / `_StyleChip` | `drink_card.dart` | Private to `drink_card.dart` — extend `DrinkCard` itself rather than exporting these |

If your need isn't in this table and isn't a one-off, check the sibling widget
files anyway (`drink_list_section.dart`, `drinks_filter_controls.dart`,
`festival_banner.dart`, `festival_header.dart`, `festival_menu_sheets.dart`,
`availability_badge.dart`, `environment_badge.dart`) before writing something
new — this project keeps its component set deliberately small (rule 4 above).

---

## Part 3 — Accessibility catalogue (WCAG 2.1 AA)

This project treats accessibility as mandatory, not optional (AGENTS.md,
`docs/code/accessibility.md`). Standards: WCAG 2.1 Level AA, ADA, Section 508.

### High-priority files (touch these carefully; each already has Semantics coverage to preserve)

`lib/widgets/drink_card.dart`, `lib/screens/drinks_screen.dart`,
`lib/screens/festival_info_screen.dart`, `lib/main.dart`,
`lib/widgets/star_rating.dart`, `lib/widgets/bottom_action_bar.dart`,
`lib/widgets/breadcrumb_bar.dart`, `lib/widgets/overflow_menu.dart`,
`lib/widgets/info_chip.dart`, `lib/widgets/festival_menu_sheets.dart`,
`lib/widgets/environment_badge.dart`, `lib/screens/about_screen.dart`,
`lib/screens/drink_detail_screen.dart`.

### Verified snippet patterns

**Toggle button (favourite / bookmark)** — label changes with state, `toggled`
carries the on/off state to assistive tech:
```dart
Semantics(
  label: isFavourite ? 'Remove from favourites' : 'Add to favourites',
  button: true,
  toggled: isFavourite,
  hint: 'Double tap to toggle',
  child: IconButton(
    icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
    onPressed: () => toggleFavorite(),
  ),
)
```

**Filter chip** — `value` announces selection state independently of the visible chip:
```dart
Semantics(
  label: 'Filter by $styleName',
  value: isSelected ? 'Selected' : 'Not selected',
  button: true,
  selected: isSelected,
  child: FilterChip(
    label: Text(styleName),
    selected: isSelected,
    onSelected: (value) => _toggleStyle(styleName),
  ),
)
```

**Tappable card / list row** — one Semantics wrapper, not one per child `Text`:
```dart
Semantics(
  label: '${drink.name}, ${drink.abv}% ABV, by ${drink.breweryName}',
  hint: 'Double tap for details',
  button: true,
  child: InkWell(onTap: () => navigateToDetail(drink), child: DrinkCard(drink: drink)),
)
```

**Star rating** — matches the live implementation in `star_rating.dart:47-61`
exactly (parent announces the summary, each star is independently labelled):
```dart
Semantics(
  label: isEditable ? 'Rate this drink' : 'Rating',
  value: '$ratingValue out of 5 stars',
  hint: isEditable ? 'Tap a star to rate from 1 to 5. Tap again to clear rating.' : null,
  enabled: isEditable,
  child: Row(
    children: List.generate(5, (i) => Semantics(
      label: 'Star ${i + 1}',
      button: isEditable,
      selected: rating != null && i + 1 <= rating!,
      child: GestureDetector(/* ... */),
    )),
  ),
)
```

**Decorative icon inside an otherwise-labelled control** — wrap it in
`ExcludeSemantics` so it isn't announced twice (see `overflow_menu.dart:28`):
```dart
ExcludeSemantics(child: Icon(Icons.festival, color: menuContentColor))
```

### Rules that apply everywhere

- Every interactive element gets a `Semantics` wrapper with a meaningful
  `label` describing the *action*, not the icon (`'Add to favourites'`, not
  `'Heart icon'`).
- Touch targets: 24×24 px minimum (WCAG AA); this project's icon buttons
  generally exceed that (`BreadcrumbBar`'s back button is 28px icon → 48×48
  effective target).
- Colour contrast 4.5:1 for text; never rely on colour alone to convey state
  (relevant to My Festival badges — see Part 6).
- Don't wrap a whole `Row` containing both a button and plain text in one
  `Semantics(button: true)` — only the actually-tappable part gets the
  wrapper (`docs/code/widget-standards.md`'s BAD example).

### The duplicate-semantics-node gotcha

Some Flutter widgets (`FilledButton.icon`, `ElevatedButton.icon`) synthesise
their own semantics node from their visible text label. If you *also* wrap
that button in an explicit `Semantics(label: '...')` with the same text, two
nodes with that label now exist in the tree, and
`expect(find.bySemanticsLabel('...'), findsOneWidget)` fails. Fix: use
`findsWidgets` instead of `findsOneWidget`, or switch to the widget-predicate
strategy. Full detail on all three semantics-testing strategies (widget
predicate, rendered tree via `tester.ensureSemantics()`, node-properties
inspection) lives in skill `validation-and-qa` — this skill owns *what* the
label should be; that skill owns *how to assert it in a test*.

---

## Part 4 — Screen patterns that must be preserved

These are invariants, not suggestions — each exists because of a specific,
citable bug. Breaking one silently reintroduces a fixed defect.

### 1. Festival-flash guard (REQUIRED in any festival-scoped screen)

`lib/screens/my_festival_screen.dart:15` (inside `FavoritesScreen.build`):
```dart
final provider = context.watch<BeerProvider>();
if (provider.currentFestival.id != festivalId) {
  return buildLoadingScaffold();
}
```
`festivalId` is the route's path parameter, not `provider.currentFestival.id`.
This exists because `_festivalScopeRedirect` (`lib/router.dart:24-42`) defers
the actual festival switch to a post-frame callback and returns `null` — so
without this guard, the first frame after a cross-festival deep link or
festival switch renders the **previous** festival's data for one frame
(issue #397, following the broader #310 family; fixed in PR #409). Any new
festival-scoped screen — including the eventual My Festival Phase-1 screen
(issue #414, which explicitly says "inherit the fix from #397... build this in
from day one") — must carry this guard from its first commit, not as a
follow-up fix.

### 2. Four-signal loading/error UI

`BeerProvider` exposes four mutually-exclusive-by-construction signals;
`DrinksScreen` (`lib/screens/drinks_screen.dart`) is the reference
implementation of how each maps to UI:

| Field | Getter | Widget | Condition (verified `drinks_screen.dart` line) |
|---|---|---|---|
| `_isLoading` | `isLoading` | Full-screen `CircularProgressIndicator` | `provider.isLoading && provider.drinks.isEmpty` (~263) |
| `_isRefreshing` | `isRefreshing` | `LinearProgressIndicator(minHeight: 2)` at top | `provider.isRefreshing && hasData` (~251) |
| `_refreshNotice` (non-null) | `refreshNotice` | Dismissible banner | `provider.refreshNotice != null && hasData` (~209) |
| `_error` (non-null) | `error` | Full error view + Retry | `provider.error != null && provider.drinks.isEmpty` (~279) |

`_error` and `_refreshNotice` are never both non-null at once (enforced in
`beer_provider.dart`'s `_refreshDrinksFromNetwork`). When adding a new screen
that reads from `BeerProvider`, reuse this same four-branch structure — don't
invent a fifth loading state or collapse two of these into one.

### 3. `navigateToRoute` + typed path builders

`lib/utils/navigation_helpers.dart:234` — `navigateToRoute(context, path)`
picks `context.go(path)` on web and `context.push(path)` on mobile, because
`push` from inside a `ShellRoute` doesn't update the browser URL bar on web,
while `push` is preferred on mobile to preserve the native back stack. Use it
for any drill-down navigation to content (drink detail, brewery, style). For
root/tab navigation that replaces the stack (bottom nav taps, "go home"), call
`context.go()` directly instead — that's a deliberate exception, not an
inconsistency.

Always build paths with the typed helpers in the same file — never
interpolate a raw string:
```dart
navigateToRoute(context, buildDrinkDetailPath(festivalId, category, drinkId));
navigateToRoute(context, buildBreweryPath(festivalId, breweryId));
navigateToRoute(context, buildStylePath(festivalId, style)); // lowercases + encodes
```
Available builders (`lib/utils/navigation_helpers.dart`): `buildFestivalPath`,
`buildFestivalHome`, `buildDrinksPath`, `buildFavoritesPath`,
`buildFestivalInfoPath`, `buildDrinkDetailPath`, `buildBreweryPath`,
`buildStylePath`, `buildCategoryPath`. Each asserts non-empty required
arguments in debug mode and URL-encodes user-provided segments.

### 4. Post-frame analytics in `initState`

Screens that log an analytics event on open must defer it past the first
frame, matching `lib/screens/drink_detail_screen.dart:30-37`:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final provider = context.read<BeerProvider>();
    unawaited(provider.analyticsService.logDrinkViewed(drink));
  });
}
```
Calling `context.read<BeerProvider>()` directly inside `initState` (before the
first frame) is a common source of provider-not-ready errors; the post-frame
callback sidesteps it. Always `unawaited(...)` the log call itself — analytics
must never block or fail the UI (see skill `architecture-contract` for the
broader analytics invariant).

### 5. Search debounce (300ms)

`lib/screens/drinks_screen.dart:23-28` debounces the search field so every
keystroke doesn't re-run the full filter + analytics pipeline:
```dart
Timer? _searchDebounceTimer;
// ...
_searchDebounceTimer?.cancel();
_searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
  provider.setSearchQuery(query);
});
```
Cancel the timer in `dispose()` and on any early-exit path (e.g. clear
button) — `drinks_screen.dart` cancels it at three call sites, not just
`dispose()`. Reuse this exact pattern for any new free-text search field
rather than inventing a new debounce mechanism.

---

## Part 5 — Theming

`lib/app_theme.dart`:
- `appSeedColor = Color(0xFF2B3170)` — CBF 2026 poster navy. Single hardcoded
  seed today; there is no per-festival or per-user theme switching in code.
- `buildAppTheme(Brightness brightness)` builds `ColorScheme.fromSeed(...)`
  from that one seed, with light/dark overrides for `primary` (light: seed
  navy; dark: a lighter `0xFF8FA3E8`) and for `AppBarTheme`/
  `navigationBarTheme.indicatorColor`.
- `buildAppTextTheme(ColorScheme)` pairs **Playfair Display** (display/
  headline/titleLarge — the serif "poster" voice) with **Nunito Sans** (body/
  label/titleMedium-and-below), both via `google_fonts`.
- `MaterialApp` in `lib/main.dart` consumes `buildAppTheme(Brightness.light)`
  / `buildAppTheme(Brightness.dark)` directly; `BeerProvider.themeMode`
  controls which one is active (system/light/dark), not the seed colour.

**Per-festival theming is issue #40 — OPEN, a candidate, not implemented.**
It proposes giving `Festival` a `seedColor` field (sourced from each year's
poster palette) so the theme could shift when `setFestival()` is called, plus
optionally a user-facing theme picker. Neither exists in code today — do not
build against an assumed `Festival.seedColor` field. If you pick this up,
start from the issue's own open questions (server-controlled vs hardcoded
seed per festival; user picker vs automatic; light-only vs light+dark) rather
than re-deriving them.

---

## Part 6 — My Festival UI specifics (the live workstream)

This is the project's current highest-priority live UI work (issues
#411→#415; see skill `my-festival-campaign` for sequencing across the whole
campaign, including the non-UI cloud-sync half). This section covers only the
**visual/accessibility design intent**, sourced from
`docs/planning/my-festival/vision.md` (status: vision doc, dated May 2026) and
issue #414 (open as of 2026-07-02).

### Planned status badges on drink cards

Design intent, not yet implemented in `lib/widgets/drink_card.dart`:

| State | Badge |
|---|---|
| Want to Try | Grey circle outline icon (○) |
| Tasted (once) | Green checkmark (✓) |
| Tasted (multiple) | Green checkmark + count badge (✓ 3×) |

### Design constraints (from vision.md — treat as binding once this is built)

- Subtle, clean — badges must not clutter the card (this is a **restyle**
  constraint per Part 1: adding a badge to `DrinkCard` should not become an
  excuse to re-lay-out the card).
- WCAG AA colour contrast on the badge itself.
- 24×24 px minimum touch target if the badge is itself tappable.
- `Semantics` label on every badge state (state-aware, following the toggle
  pattern in Part 3 — e.g. `'Marked as tasted, 3 times'` rather than just an
  icon).

### Rejected alternatives (do not propose these again — already litigated in vision.md)

- **Colour-coded card backgrounds** per state — rejected for accessibility
  issues and visual clutter.
- **Opacity fade** for tasted items — rejected because faded items read as
  "disabled" and become harder to read, which is the opposite of the intent
  (a tasted drink is still fully relevant information).

### Section-membership + layout (informs any list/screen work, not just badges)

Per vision.md: a drink appears in **Tasted** whenever `tastingEvents.isNotEmpty`;
it appears in **Want to Try** only when `wantToTry == true AND
tastingEvents.isEmpty` — membership is derived from `UserDrinkState`, never
stored as a separate flag. The planned My Festival screen (issue #414) is a
single scrollable screen with two sections (Want to Try alphabetical list on
top; Tasted grouped-by-day reverse-chronological timeline on bottom),
separated by a visual divider, both equally reachable. Placeholder rows are
required for `entry.drink == null` (catalogue not yet hydrated — see
`MyFestivalEntry.isCatalogueLoaded`, `lib/models/my_festival_entry.dart`).
This is forward-looking design intent for a not-yet-built screen — verify
against the current state of `lib/screens/my_festival_screen.dart` and issue
#414's status before treating any of it as already implemented.

---

## When NOT to use this skill

- **Pure logic/provider/domain changes with no visible UI change** (filter
  logic, sort logic, repository/service code, controller state) — see skill
  `architecture-contract`.
- **Test mechanics** — golden update commands, semantics-testing strategy
  selection, mock generation, TDD workflow — see skill `validation-and-qa`.
  This skill tells you *what* a label/badge/layout should be; that skill tells
  you *how to write the test that proves it*.
- **My Festival / cloud-sync sequencing, phase gating, or campaign-level
  decisions** — see skill `my-festival-campaign`. This skill only owns the
  visual-design constraints that campaign must respect (Part 6).
- **Route/URL contract questions, change classification, or "am I allowed to
  do this at all"** — see skill `change-control`.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at that date: read in
full — `docs/code/accessibility.md`, `docs/code/widget-standards.md`,
`docs/code/ui-components.md`, `docs/code/navigation.md`,
`docs/planning/my-festival/vision.md`, `lib/router.dart`, `lib/app_theme.dart`,
`lib/utils/navigation_helpers.dart`, every file in `lib/widgets/` named in the
reuse table, `lib/screens/my_festival_screen.dart`,
`lib/screens/drinks_screen.dart`, `lib/screens/drink_detail_screen.dart`. GitHub
issues #414, #397, #40 fetched and read directly (not inferred from a digest)
to confirm status, labels, and exact wording.

Re-verification commands for facts likely to drift:

```bash
# Golden file count/names — Part 1, rule 5
ls /home/user/cambridge-beer-festival-app/test/goldens/

# Festival-flash guard still present — Part 4.1
grep -n "currentFestival.id != festivalId" lib/screens/my_festival_screen.dart

# Route path for the My Festival / Favorites screen hasn't moved — Part 1, rule 3
grep -n "favorites" lib/router.dart

# Four-signal condition lines haven't shifted — Part 4.2 (line numbers are approximate, re-grep if stale)
grep -n "isLoading\|isRefreshing\|refreshNotice\|provider.error" lib/screens/drinks_screen.dart

# Search debounce constant — Part 4.5
grep -n "Duration(milliseconds" lib/screens/drinks_screen.dart

# Theme seed / per-festival theming status — Part 5 (check issue state, not just body)
gh issue view 414 --repo richardthe3rd/cambridge-beer-festival-app
gh issue view 40 --repo richardthe3rd/cambridge-beer-festival-app

# Shared widget set hasn't grown/shrunk — Part 2 reuse table
ls lib/widgets/
```

If `docs/code/accessibility.md`, `docs/code/widget-standards.md`, or
`docs/code/ui-components.md` are edited, re-diff this skill's Parts 2–3
against them — they were the primary sources and this skill inlines their
load-bearing content rather than just linking to it.
