
## [2026.7.0] - 2026-07-02

### Bug Fixes

- **router**: Add loading builder to root route to prevent null-check crash (#408)
- **favorites**: Show loading state while festival switches (#409)
- **cache**: Serialise DrinkCacheService writes to prevent race (#419)
- **repository**: Return UserDrinkState from mutators to eliminate dual DateTime.now() (#447)

### Documentation

- Remove stale planning docs and fix dangling links (#394)
- **my-festival**: Resolve timeline vs unified-list contradiction; split photos into separate milestone (#418)
- **api**: Publish MyFestival OpenAPI spec via Redoc at /api-docs/ (#428)
- **agents**: Promote cross-cutting guidance from skill commands (#444)
- **skills**: Fix MCP method references and dedupe shared guidance (#452)

### Features

- **favourites**: Query favourites from the personal-state store, independent of the catalogue (#396)
- **domain**: Extract personal-state management into UserDrinkStateController (#398)
- **domain**: Extract FestivalController from BeerProvider (#402)
- **domain**: Extract UserPreferencesController from BeerProvider (#403)
- **proto**: Myfestival v1alpha API contract, OpenAPI generation, and client codegen (#425)
- **worker**: Add /v1alpha Review API on D1 (#426)
- **proto**: Consolidate DrinkEntry sync contract (v1alpha) (#429)
- **api**: Add read-only festival catalogue API (#433)

### Refactoring

- **drinks**: Split DrinksScreen into focused widget files (#388)
- **storage**: Unify personal state into a versioned UserDataStore (#395)
- Simplify controllers and eliminate parallel switch and boilerplate (#399)
- **models**: Rename FavoriteDrinkEntry→MyFestivalEntry; generalise to myFestivalEntries; extract FavoritesScreen (#448)


