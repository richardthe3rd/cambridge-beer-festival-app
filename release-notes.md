
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


