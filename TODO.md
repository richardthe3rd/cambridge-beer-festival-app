# Project TODO

Bugs and usability issues identified during code review (2026-02-06).

## Bugs

### Critical

- [ ] **`dart:io` import breaks web builds** (`lib/providers/beer_provider.dart:2`)
  `BeerProvider` imports `dart:io` to catch `SocketException` (line 364). `dart:io` is not available on web, the primary target platform. This will cause a compile error or runtime crash on web builds. The `SocketException` catch clause is dead code on web anyway.

- [ ] **Sequential API fetching causes slow load times** (`lib/services/beer_api_service.dart:48-56`)
  `fetchAllDrinks` fetches each beverage type sequentially in a `for` loop with `await`. With 7 beverage types and a 30-second timeout each, worst-case load time is 3.5 minutes. Even in the happy path, 7 sequential HTTP requests could be parallelized with `Future.wait`, making the initial load ~7x faster.

### High

- [ ] **Festival selector doesn't update URL** (`lib/widgets/festival_menu_sheets.dart:188`)
  When selecting a festival via the browser sheet, `provider.setFestival(festival)` is called but the URL is never updated to `/${festival.id}`. The user stays on the old festival's URL path (e.g., `/cbf2024`) while viewing drinks from the newly selected festival. This breaks deep-linking, bookmarking, and the browser back button.

- [ ] **Festival validation missing on detail routes** (`lib/router.dart:103-143`)
  The `/:festivalId` main route validates the festival ID and switches festivals, but detail routes (`/:festivalId/drink/:id`, `/:festivalId/brewery/:id`, `/:festivalId/style/:name`, `/:festivalId/info`) have no validation or festival switching. Deep-linking to `/invalid-fest/drink/abc` bypasses validation entirely and leads to broken state. Documented as a known limitation at `lib/main.dart:146-149`.

- [ ] **Mutable `Drink` state mutated directly without rollback** (`lib/providers/beer_provider.dart:462,494,509`)
  `toggleFavorite`, `setRating`, and `toggleTasted` mutate the `Drink` object's fields (`isFavorite`, `rating`, `isTasted`) in place after the repository call succeeds. If the repository call throws, the in-memory state diverges from persisted state. There is no rollback on error. Also, widgets holding a reference to the drink see the mutation before `notifyListeners()` is called.

### Medium

- [ ] **`getTastedDrinkIds` matches keys from other festivals** (`lib/services/tasting_log_service.dart:56-59`)
  The prefix `tasting_log_cbf2025` also matches keys for a hypothetical festival `cbf20250`. The prefix should include the trailing `_` separator (i.e., `tasting_log_cbf2025_`). Same issue in `clearFestivalLog` at line 69.

- [ ] **`FestivalService.fetchFestivals` doesn't decode UTF-8** (`lib/services/festival_service.dart:79`)
  `BeerApiService.fetchDrinks` correctly uses `utf8.decode(response.bodyBytes)` to handle non-ASCII characters, but `FestivalService.fetchFestivals` uses `response.body` directly. Festival names or descriptions with non-ASCII characters will display as mojibake.

- [ ] **`_handlePostInitRedirect` may use context after disposal** (`lib/main.dart:204`)
  In the error handler, `context.read<BeerProvider>()` is called inside a catch block. If an exception is thrown between the `mounted` check (line 156) and the catch block (line 198), context may be used on an unmounted widget.

## Usability Issues

### High

- [ ] **No way to navigate back from About screen**
  The About screen (`/about`) is a global route outside the ShellRoute with ProviderInitializer. If a user deep-links to `/about`, there is no back navigation -- no leading button, no bottom nav bar. The only way back is the browser back button or manually editing the URL.

- [ ] **"Clear Filters" button only clears category, not styles or search** (`lib/screens/drinks_screen.dart:460`)
  When no drinks match the active filters, the empty state "Clear Filters" button only calls `provider.setCategory(null)`. If style filters or a search query are also active, those remain and the user may still see zero results after clicking.

- [ ] **Favorites screen doesn't respond to festival switches** (`lib/main.dart:354-401`)
  `FavoritesScreen` displays `provider.favoriteDrinks` which returns favorites from `_allDrinks` (the currently loaded festival). If a user navigates to `/cbf2024/favorites` while `cbf2025` drinks are loaded, they see `cbf2025` favorites on a page labeled as `cbf2024`. The `festivalId` URL parameter is not used for filtering.

### Medium

- [ ] **Drink detail app bar shows raw festival ID** (`lib/screens/drink_detail_screen.dart:118`)
  The app bar subtitle shows `${provider.currentFestival.id} > ${drink.breweryName}` (e.g., "cbf2025 > Brewery Name"). Every other screen uses `provider.currentFestival.name`. This exposes internal identifiers to users.

- [ ] **No debouncing on search input** (`lib/screens/drinks_screen.dart:106`)
  Every keystroke triggers `setSearchQuery`, which applies all filters, creates new lists, calls `notifyListeners()`, and fires an analytics event. With hundreds of drinks, this causes jank during fast typing and spams analytics.

- [ ] **Filter button screen reader hint is misleading** (`lib/screens/drinks_screen.dart:555`)
  `_FilterButton` semantic hint says "Double tap to clear filter" when active, but tapping opens the filter selection bottom sheet rather than clearing the filter. Misleading for screen reader users.

- [ ] **Availability toggle label is ambiguous** (`lib/screens/drinks_screen.dart:640-641`)
  When active (unavailable drinks hidden), the label says "Show unavailable". It's unclear whether this describes the current state or the action the button performs. Combined with the icon toggle, users can't distinguish current state from desired action.
