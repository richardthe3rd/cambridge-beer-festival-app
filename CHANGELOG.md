
## [2026.7.1] - 2026-07-24

### Features

- **drink-detail**: Inline autosaving notes and undo for tasting delete (#488)
- Search result excerpts/highlighting and My Festival notes (#492)
- **my-festival**: Card the list rows and enrich Want to Try (#494)



## [2026.7.0] - 2026-07-18

### Bug Fixes

- **router**: Add loading builder to root route to prevent null-check crash (#408)
- **favorites**: Show loading state while festival switches (#409)
- **cache**: Serialise DrinkCacheService writes to prevent race (#419)
- **repository**: Return UserDrinkState from mutators to eliminate dual DateTime.now() (#447)
- **drink-detail**: Make the tasting SnackBar dismissible and less cramped (#475)
- **router**: Push detail routes instead of replacing to preserve scroll position (#478)
- **drinks**: Make drink card text areas tappable (#483)

### Documentation

- Remove stale planning docs and fix dangling links (#394)
- **my-festival**: Resolve timeline vs unified-list contradiction; split photos into separate milestone (#418)
- **api**: Publish MyFestival OpenAPI spec via Redoc at /api-docs/ (#428)
- **agents**: Promote cross-cutting guidance from skill commands (#444)
- **skills**: Fix MCP method references and dedupe shared guidance (#452)
- **skills**: Add change-control and debugging-playbook skills (#456)
- **agents**: Dedup AGENTS.md into a spine + skill router (#458)
- **adr**: Propose the check-in as the primary My Festival entity (#459)
- **adr**: Mark ADR 0006 Accepted (#460)
- **readme**: Refresh features, fix accuracy nits, strengthen story (#464)
- **design**: Capture the design-language lessons from the detail redesign (#473)

### Features

- **favourites**: Query favourites from the personal-state store, independent of the catalogue (#396)
- **domain**: Extract personal-state management into UserDrinkStateController (#398)
- **domain**: Extract FestivalController from BeerProvider (#402)
- **domain**: Extract UserPreferencesController from BeerProvider (#403)
- **proto**: Myfestival v1alpha API contract, OpenAPI generation, and client codegen (#425)
- **worker**: Add /v1alpha Review API on D1 (#426)
- **proto**: Consolidate DrinkEntry sync contract (v1alpha) (#429)
- **api**: Add read-only festival catalogue API (#433)
- **my-festival**: Add tasting-log and notes mutators through the stack (#455)
- **my-festival**: My Festival screen with want-to-try and tasted sections (#457)
- **my-festival**: Migrate to LogEntry check-in model (schema v2) (#463)
- **my-festival**: Detail-screen multi-tasting, timestamps and notes (#466)
- **drink-detail**: Reorder layout and add Similar Drinks carousel (#468)
- **drinks**: Redesign the drink detail screen around a "one job per surface" layout (#472)
- **detail**: Collapse app bar title to the drink on scroll (#482)
- **web**: Set route-aware browser tab titles (#484)
- **navigation**: Add one-tap return to drinks list from detail screens (#485)

### Refactoring

- **drinks**: Split DrinksScreen into focused widget files (#388)
- **storage**: Unify personal state into a versioned UserDataStore (#395)
- Simplify controllers and eliminate parallel switch and boilerplate (#399)
- **models**: Rename FavoriteDrinkEntry→MyFestivalEntry; generalise to myFestivalEntries; extract FavoritesScreen (#448)
- **widgets**: Extract FactsStrip from DrinkHeroPanel (#474)



## [2026.6.0] - 2026-06-05

### Bug Fixes

- **screens**: Show festival name instead of ID in drink detail app bar (#365)
- **models**: Make Drink user-state fields immutable with copyWith (#366)
- **analytics**: Filter connectivity failures from partial-fetch log (#375)
- **connectivity**: Replace runtimeType string-matching with conditional imports (#376)
- **provider**: Don't update lastDrinksRefresh when festival has no types (#382)
- **models**: Add == and hashCode to Drink, Product, and Producer (#380)

### Documentation

- **agents**: Add parallel subagent/worktree workflow rules (#368)
- **agents**: Clarify worktree PRs target main, not the session branch (#374)

### Features

- **claude**: Add ship-issues workflow commands and tighten agent docs (#378)
- **models**: Introduce BeverageCategories constants, replace magic strings (#381)

### Refactoring

- **models**: Add Drink-level accessors to remove feature envy in screens (#367)
- **screens**: Extract DetailHeader widget, deduplicate sort label logic (#377)



## [2026.5.9] - 2026-05-31

### Bug Fixes

- Style screen title casing and google_fonts crash reporting (#295)
- **router**: Handle illegal percent encoding in style route (#300)
- **ci**: Replace report-lcov action with codecov for coverage gating (#303)
- **analytics**: Prevent Cloudflare Pages preview hosts from logging to production (#327)
- **search**: Debounce search input to avoid per-keystroke filtering (#328)
- **festivals**: Skip malformed festival entries instead of crashing (#330)
- **screens**: Return Future from async URL launch handlers (#331)
- **provider**: Make festival/error analytics non-blocking in BeerProvider (#332)
- Dispose http.Client instances owned by repositories (#334)
- **provider**: Rate-limit refreshIfStale retries after failed network calls (#336)
- Prevent `"null"` identifier collisions from malformed drink JSON (#339)
- **provider**: Refresh current festival reference on registry update (#362)
- **models**: Replace fragile substring matching with exact-match status map (#360)

### Documentation

- Add badges, Play Store link, and fix README accuracy (#297)
- Move issue tracking to GitHub, archive todos.md (#316)
- **agents**: Add implicit patterns subsection to Code Style (#325)
- **agents**: Add session startup section for toolchain pre-warming (#333)
- **my-festival**: Add product vision document (#359)

### Features

- **offline**: Cache drinks & festivals for instant stale-while-revalidate startup (#302)
- **android**: Configure App Links to open shared drink URLs in the app (#363)

### Refactoring

- Extract inline shell tasks to mise-tasks file-tasks; add shellcheck + shfmt (#299)
- **storage**: Centralize SharedPreferences keys in PreferenceKeys (#356)
- **provider**: Extract DrinkFilterController from BeerProvider (#357)



## [2026.5.8] - 2026-05-17

### Bug Fixes

- **release**: Ensure unique Android Play version codes for same-day releases (#293)



## [2026.5.7] - 2026-05-17

### Bug Fixes

- **og**: Map 'foreign beer' category to international-beer API endpoint (#290)
- **router**: Update browser URL when navigating to drink detail on web (#289)



## [2026.5.6] - 2026-05-17

### Bug Fixes

- **sharing**: Extract producers array from wrapped API response in fetchDrinkData (#286)



## [2026.5.5] - 2026-05-17

### Bug Fixes

- Remove stale 180s timeout note from task table
- Address Copilot review comments on PR #259
- **release**: Address Copilot review comments on PR #260
- **release**: Release.yml owns GitHub Release; android uploads assets
- **release**: Address second round of Copilot review comments
- **release**: Address reviewer comments on automated release PR
- **release**: Address second-round Copilot review comments
- **release**: Fail loudly if release notes extraction produces empty output
- **release**: Fix broken deploy chain caused by GITHUB_TOKEN cascade limitation
- **release**: Address final Copilot review comments
- **release**: Remove labels from create-pull-request — label did not exist
- **provider**: Discard stale drinks responses on rapid festival switch (#263)
- **mise**: Add bash shebang to analyze and test task scripts (#274)
- **routing**: Deep links and browser refresh load wrong festival data (#275)
- **release**: Remove GITHUB_REPO from git-cliff action env (#276)
- **ci**: Don't trigger Android build on functions-only changes (#282)

### Documentation

- **agents**: Document conventional commits requirement for PR titles
- **agents**: Clarify that CI rejects non-conforming PR titles
- Fix factual errors and outdated references in AGENTS.md and CLAUDE.md
- Trim copilot-instructions.md — remove content covered by AGENTS.md
- Replace duplicated AGENTS.md content in CLAUDE.md with @AGENTS.md import
- Move all agent-useful content into AGENTS.md, CLAUDE.md becomes @AGENTS.md
- Restructure AGENTS.md — project context first, remove redundancy
- Fix three issues in AGENTS.md
- Demote TEST_LOG to a footnote, not the primary example
- **release**: Update release process to reflect workflow_dispatch deploy trigger

### Features

- **mise**: Add check, goldens:update tasks; add timeout to test task
- **mise**: Capture test/analyze output via mktemp + tee pattern
- **release**: Automate release via PR model
- **release**: Add workflow_dispatch to release-pr.yml for manual testing
- **sharing**: Include deep link URL in drink share message (#279)
- **sharing**: Add Cloudflare Pages Function for drink OG previews (#280)



## [2026.5.5] - 2026-05-17

### Bug Fixes

- Remove stale 180s timeout note from task table
- Address Copilot review comments on PR #259
- **release**: Address Copilot review comments on PR #260
- **release**: Release.yml owns GitHub Release; android uploads assets
- **release**: Address second round of Copilot review comments
- **release**: Address reviewer comments on automated release PR
- **release**: Address second-round Copilot review comments
- **release**: Fail loudly if release notes extraction produces empty output
- **release**: Fix broken deploy chain caused by GITHUB_TOKEN cascade limitation
- **release**: Address final Copilot review comments
- **release**: Remove labels from create-pull-request — label did not exist
- **provider**: Discard stale drinks responses on rapid festival switch (#263)
- **mise**: Add bash shebang to analyze and test task scripts (#274)
- **routing**: Deep links and browser refresh load wrong festival data (#275)
- **release**: Remove GITHUB_REPO from git-cliff action env (#276)
- **ci**: Don't trigger Android build on functions-only changes (#282)

### Documentation

- **agents**: Document conventional commits requirement for PR titles
- **agents**: Clarify that CI rejects non-conforming PR titles
- Fix factual errors and outdated references in AGENTS.md and CLAUDE.md
- Trim copilot-instructions.md — remove content covered by AGENTS.md
- Replace duplicated AGENTS.md content in CLAUDE.md with @AGENTS.md import
- Move all agent-useful content into AGENTS.md, CLAUDE.md becomes @AGENTS.md
- Restructure AGENTS.md — project context first, remove redundancy
- Fix three issues in AGENTS.md
- Demote TEST_LOG to a footnote, not the primary example
- **release**: Update release process to reflect workflow_dispatch deploy trigger

### Features

- **mise**: Add check, goldens:update tasks; add timeout to test task
- **mise**: Capture test/analyze output via mktemp + tee pattern
- **release**: Automate release via PR model
- **release**: Add workflow_dispatch to release-pr.yml for manual testing
- **sharing**: Include deep link URL in drink share message (#279)
- **sharing**: Add Cloudflare Pages Function for drink OG previews (#280)


