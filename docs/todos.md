# Cambridge Beer Festival App - TODO List

**Last Updated:** 2026-02-06
**Overall Status:** Production-ready with improvements needed

---

## ✅ Recently Completed

- **ListView keys** - Added ValueKey to all DrinkCard items for better performance
- **HTTP request timeouts** - Added 30s timeouts to all API calls
- **Error handling for URL launches** - Proper user feedback when links fail
- **User-friendly error messages** - No more technical exceptions shown to users
- **Accessibility support** - 21+ Semantics widgets added across UI
- **Widget tests** - Added tests for screens, cards, and main app
- **Firebase Crashlytics & Analytics** - Full monitoring and crash reporting
- **SliverAppBar with collapsing** - Mobile-optimized scrolling on DrinksScreen
- **Icon asset validation** - Verified all PWA manifest icons exist and are valid
- **IndexedStack documentation** - Documented memory trade-off for state preservation
- **Rating input validation** - Added validation to reject invalid ratings (must be 1-5)
- **GitHub URL constant extraction** - Moved to `lib/constants.dart` as `kGithubUrl` (TODO #27)
- **RegExp pattern caching** - Cached hashtag sanitization regex for better performance (TODO #28)
- **Error logging in URL launcher** - Added debugPrint to catch block for better debugging (TODO #29)

---

## 🔴 CRITICAL (Bugs)

### C1. `dart:io` Import Breaks Web Builds
**Status:** ❌ Not Started
**Location:** `lib/providers/beer_provider.dart:2`

**Issue:**
`BeerProvider` imports `dart:io` to catch `SocketException` (line 364). `dart:io` is not available on web, the primary target platform. This causes a compile error or runtime crash on web builds. The `SocketException` catch clause is dead code on web.

**Solution:**
Remove the `dart:io` import and `SocketException` catch clause, or use a conditional import.

---

### C2. Sequential API Fetching Causes Slow Load Times
**Status:** ❌ Not Started
**Location:** `lib/services/beer_api_service.dart:48-56`

**Issue:**
`fetchAllDrinks` fetches each beverage type sequentially in a `for` loop with `await`. With 7 beverage types and a 30-second timeout each, worst-case is 3.5 minutes. Even in the happy path, 7 sequential HTTP requests make the initial load ~7x slower than necessary.

**Solution:**
Use `Future.wait` to parallelize the HTTP requests.

---

### C3. Festival Selector Doesn't Update URL
**Status:** ❌ Not Started
**Location:** `lib/widgets/festival_menu_sheets.dart:188`

**Issue:**
When selecting a festival via the browser sheet, `provider.setFestival(festival)` is called but the URL is never updated to `/${festival.id}`. The user stays on the old festival's URL path while viewing drinks from the newly selected festival. This breaks deep-linking, bookmarking, and the browser back button.

**Solution:**
After `provider.setFestival(festival)`, navigate to `/${festival.id}` using GoRouter.

---

## 🔴 HIGH PRIORITY

### 1. Add Integration Tests
**Status:** ❌ Not Started
**Files:** Need to create `integration_test/` directory

**Issue:**
No end-to-end integration tests exist to validate complete user journeys.

**User Flows to Test:**
1. Browse to detail flow
2. Search and filter flow
3. Favorites flow (add/remove/view)
4. Festival switching flow
5. Brewery details flow
6. Error recovery flow

**Implementation:**
Use Flutter's `integration_test` package

---

### 2. Add Path Validation in Cloudflare Worker
**Status:** ❌ Not Started
**Location:** `cloudflare-worker/worker.js`

**Issue:**
No path sanitization before proxying requests. Validate/whitelist acceptable paths.

---

### H3. Festival Validation Missing on Detail Routes
**Status:** ❌ Not Started
**Location:** `lib/router.dart:103-143`

**Issue:**
The `/:festivalId` main route validates the festival ID and switches festivals, but detail routes (`/:festivalId/drink/:id`, `/:festivalId/brewery/:id`, etc.) have no validation or festival switching. Deep-linking to `/invalid-fest/drink/abc` bypasses validation entirely and leads to broken state. Documented as a known limitation at `lib/main.dart:146-149`.

**Solution:**
Add festival ID validation to all route builders, or extract validation into a shared redirect.

---

### H4. Mutable Drink State Mutated Without Rollback
**Status:** ❌ Not Started
**Location:** `lib/providers/beer_provider.dart:462,494,509`

**Issue:**
`toggleFavorite`, `setRating`, and `toggleTasted` mutate `Drink` object fields in place after the repository call. If the repository call throws, in-memory state diverges from persisted state with no rollback. Widgets holding a reference to the drink also see the mutation before `notifyListeners()` is called.

**Solution:**
Use optimistic update with rollback on error, or rebuild the drink list from the repository after mutation.

---

### H5. "Clear Filters" Button Only Clears Category
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:460`

**Issue:**
When no drinks match the active filters, the empty state "Clear Filters" button only calls `provider.setCategory(null)`. Style filters and search query remain active, so the user may still see zero results after clicking.

**Solution:**
Clear all filters: category, styles, and search query.

---

### H6. No Way to Navigate Back from About Screen
**Status:** ❌ Not Started
**Location:** `lib/router.dart:28-31`, `lib/screens/about_screen.dart`

**Issue:**
The About screen (`/about`) is a global route outside the ShellRoute. If a user deep-links to `/about`, there is no back navigation -- no leading button, no bottom nav bar. The only way back is the browser back button.

**Solution:**
Add a home/back button to the About screen AppBar, or include it within the shell route.

---

### H7. Favorites Screen Doesn't Respond to Festival Switches
**Status:** ❌ Not Started
**Location:** `lib/main.dart:354-401`

**Issue:**
`FavoritesScreen` displays `provider.favoriteDrinks` from `_allDrinks` (the currently loaded festival). If a user navigates to `/cbf2024/favorites` while `cbf2025` drinks are loaded, they see `cbf2025` favorites on a page claiming to show `cbf2024`.

**Solution:**
Ensure festival switch completes before rendering, or filter favorites by the URL's `festivalId`.

---

## 🟡 MEDIUM PRIORITY

### 3. Implement Retry Logic for Failed API Requests
**Status:** ❌ Not Started
**Location:** `lib/services/beer_api_service.dart`

**Issue:**
No automatic retry for temporary network glitches. Users must manually pull-to-refresh.

**Solution:**
Add exponential backoff retry (3 attempts: 500ms, 1s, 2s) for transient errors only.

---

### 4. Add Cloud Sync for Favorites/Ratings
**Status:** ❌ Not Started
**Location:** `lib/services/storage_service.dart`

**Issue:**
Favorites/ratings stored locally only. Users lose data when switching devices.

**Solution:**
Consider Firebase Firestore or Supabase for cross-device sync.

---

### 5. Improve Test Coverage
**Status:** 🟡 In Progress
**Current:** ~45% test-to-code ratio
**Goal:** 70%+

**Files Still Missing Tests:**
- Some provider edge cases
- Additional screen states (loading, empty, error)
- Widget interaction flows

---

### M1. `getTastedDrinkIds` Matches Keys from Other Festivals
**Status:** ❌ Not Started
**Location:** `lib/services/tasting_log_service.dart:56-59`

**Issue:**
The prefix `tasting_log_cbf2025` also matches keys for a hypothetical festival `cbf20250`. The prefix should include the trailing `_` separator (i.e., `tasting_log_cbf2025_`). Same issue in `clearFestivalLog` at line 69.

---

### M2. `FestivalService` Doesn't Decode UTF-8
**Status:** ❌ Not Started
**Location:** `lib/services/festival_service.dart:79`

**Issue:**
`BeerApiService.fetchDrinks` correctly uses `utf8.decode(response.bodyBytes)` to handle non-ASCII characters, but `FestivalService.fetchFestivals` uses `response.body` directly. Festival names or descriptions with non-ASCII characters will display as mojibake.

---

### M3. Drink Detail App Bar Shows Raw Festival ID
**Status:** ❌ Not Started
**Location:** `lib/screens/drink_detail_screen.dart:118`

**Issue:**
The app bar subtitle shows `${provider.currentFestival.id} > ${drink.breweryName}` (e.g., "cbf2025 > Brewery Name"). Every other screen uses `provider.currentFestival.name`. Exposes internal identifiers to users.

---

### M4. No Debouncing on Search Input
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:106`

**Issue:**
Every keystroke triggers `setSearchQuery`, which applies all filters, creates new lists, calls `notifyListeners()`, and fires an analytics event. With hundreds of drinks, this causes jank during fast typing and spams analytics.

**Solution:**
Add a debounce (e.g., 300ms) before applying the search query.

---

### M5. Filter Button Screen Reader Hint Is Misleading
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:555`

**Issue:**
`_FilterButton` semantic hint says "Double tap to clear filter" when active, but tapping opens the filter selection bottom sheet rather than clearing the filter. Misleading for screen reader users.

---

### M6. Availability Toggle Label Is Ambiguous
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:640-641`

**Issue:**
When active (unavailable drinks hidden), the label says "Show unavailable". It's unclear whether this describes the current state or the action the button performs. Combined with the icon toggle, users can't distinguish current state from desired action.

---

### M7. `_handlePostInitRedirect` May Use Context After Disposal
**Status:** ❌ Not Started
**Location:** `lib/main.dart:204`

**Issue:**
In the error handler, `context.read<BeerProvider>()` is called inside a catch block. If an exception is thrown between the `mounted` check (line 156) and the catch block, context may be used on an unmounted widget.

---

### 6. Apply SliverAppBar to FavoritesScreen
**Status:** ❌ Not Started
**Location:** `lib/main.dart:99-150`

**Issue:**
FavoritesScreen uses standard AppBar, not optimized for mobile like DrinksScreen.

**Solution:**
Apply same SliverAppBar pattern as DrinksScreen for consistency.

---

## 📱 MOBILE UI OPTIMIZATION

**Note:** These items should be validated with user testing and analytics before implementation. Only proceed if users report actual pain points.

---

### 9. Implement Collapsible Festival Info Banner
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:247-319`

**Issue:**
Festival info banner takes up 40-50px of vertical space and cannot be dismissed.

**Solution:**
Allow user to dismiss/minimize the banner or move to AppBar expanded state.

**Impact:** Saves 40-50px on mobile

---

### 10. Consolidate Style Filter Controls
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:1004-1102`

**Issue:**
Style filter chips wrap vertically and can consume 80+ pixels on mobile.

**Recommended Solution:**
Horizontal scrolling for style chips.

**Impact:** Saves 40-80px on mobile

---

### 11. Reduce Mobile Card Density
**Status:** ❌ Not Started
**Location:** `lib/widgets/drink_card.dart`

**Issue:**
Drink cards use generous padding optimal for tablets but wasteful on mobile.

**Solution:**
Use responsive padding based on screen size (`MediaQuery.of(context).size.width < 600`).

**Impact:** Saves 20-30px per card

---

### 12. Move Search to FloatingActionButton or AppBar
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:83-130`

**Issue:**
Search button takes up space in bottom controls row on mobile.

**Solution:**
Move to AppBar actions or use FAB pattern.

---

### 13. Smart Default Filters for Mobile
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:126-128`

**Issue:**
Style chips shown by default, consuming space even when not actively filtering.

**Solution:**
Hide style chips by default on mobile (<600dp width), show count in filter button instead.

**Impact:** Saves 36-80px on mobile by default

---

## 🟢 LOW PRIORITY (Nice to Have)

### 7. Add Screenshots to README
**Location:** `README.md:21`
README still says "Coming soon" for screenshots.

---

### 8. Create CHANGELOG.md
**Files:** Need to create `CHANGELOG.md`
No version history tracking for users/developers.

---

### 9. Add Performance Monitoring
**Files:** App-wide
Consider Firebase Performance or custom metrics for tracking performance regressions.

---

### 10. Convert async void methods to Future<void>
**Status:** ❌ Not Started
**Location:** Multiple files with URL launch methods
**Files:**
- `lib/screens/about_screen.dart:497, 505` (_openGitHub, _openIssues)
- `lib/screens/festival_info_screen.dart:249, 260, 270` (_openMaps, _openWebsite, _openGitHub)

**Issue:**
Methods declared as `void _method() async` are a Dart lint violation. Async void methods are hard to track and can cause subtle bugs.

**Solution:**
Change return type to `Future<void>`.

**Impact:** Code quality, prevents potential issues with error tracking and method cancellation
**Estimated time:** 5 minutes

---

### 11. Extract Hardcoded Status Badge Colors
**Status:** ❌ Not Started
**Location:**
- `lib/screens/drinks_screen.dart:255, 295, 315, 1354, 1360, 1363` (6+ occurrences)
- `lib/screens/festival_info_screen.dart:88, 94` (ACTIVE badge)

**Issue:**
Status badges (LIVE, SOON, RECENT, PAST, ACTIVE) use hardcoded colors:
- `Color(0xFF4CAF50)`, `Color(0xFF2E7D32)` (green - light/dark)
- `Color(0xFF2196F3)` (blue)
- `Color(0xFFFF9800)`, `Color(0xFFEF6C00)` (orange - light/dark)
- `Color(0xFF9E9E9E)`, `Color(0xFF616161)` (gray - light/dark)
- `Colors.green`, `Colors.white`

These should be theme-aware for proper dark mode support.

**Solution:**
Extract to constants or theme extension, use theme-based text colors with proper contrast.

**Impact:** Better dark mode support, easier maintenance, reduced code duplication
**Estimated time:** 15 minutes

---

### 12. Add Semantics to Status Badge Labels
**Status:** ❌ Not Started
**Location:**
- `lib/screens/drinks_screen.dart:247-325` (festival banner badges)
- `lib/screens/drinks_screen.dart:1343-1388` (_buildStatusBadge method)

**Issue:**
Status badges (LIVE, SOON, RECENT, PAST) display as simple containers without semantic labels. Screen readers cannot announce festival status.

**Solution:**
Wrap badges in Semantics widgets:
```dart
Semantics(
  label: 'Festival status: Live',
  child: Container(...),
)
```

**Impact:** Better accessibility for screen reader users
**Estimated time:** 15 minutes

---

### 13. Validate Festival ID Before Using in URLs
**Status:** ❌ Not Started
**Location:** `lib/screens/drink_detail_screen.dart:136`

**Issue:**
Festival ID is used directly in hashtag generation without validation. An empty or null festival ID should be handled explicitly.

**Solution:**
Add explicit validation before using festival ID in hashtags.

**Impact:** Defensive programming, prevents edge case issues
**Estimated time:** 5 minutes

---

## ⏸️ DEFERRED (Needs Validation Before Implementation)

These items have been deferred pending further analysis or user feedback.

### D1. Remove Localhost from Production CORS
**Original:** #1
**Reason for deferral:** Only necessary if the same Cloudflare Worker code is deployed to all environments. Needs environment architecture review first.

---

### D2. Add Client-Side Rate Limiting
**Original:** #5
**Reason for deferral:** Needs analytics to confirm users actually experience this issue. Server-side rate limiting may already handle this.

---

### D3. Add Method Documentation
**Original:** #16
**Reason for deferral:** Only document complex private methods if logic is non-obvious. Most method names are self-documenting.

---

### D4. Add Dark Mode Icon Variants for PWA
**Original:** #21
**Reason for deferral:** Very low user impact. Most PWA launchers don't use adaptive icons. Only pursue if updating PWA assets for other reasons.

---

### D5. Add DartDoc Comments to Private Widget Classes
**Original:** #31
**Reason for deferral:** Private widgets with clear names (`_FilterButton`, `_SearchButton`) are self-documenting. Only add docs if purpose isn't obvious from name.

---

### D6. Eliminate Version Extraction Duplication in Release Workflows
**Original:** #10
**Reason for deferral:** Workflows function correctly. Only refactor if actively maintaining release processes.

---

## 📊 Summary

### By Priority
- **CRITICAL (Bugs):** 3 issues (C1-C3)
- **HIGH Priority:** 7 issues (1-2 original + H3-H7 from review)
- **MEDIUM Priority:** 11 issues (3-6 original + M1-M7 from review)
- **MOBILE UI (conditional on user feedback):** 5 issues
- **LOW Priority:** 7 issues
- **ACTIVE TOTAL:** 33 issues
- **DEFERRED:** 6 issues (see Deferred section)

### Recently Completed
- 14 items from previous review

### Recently Archived (Not Worth Doing)
- **#8:** Add Loading State for URL Operations (instant feedback, loading state unnecessary)
- **#19:** Move Hard-coded Fallback Data to Config (code is safer than config)
- **#23:** Add Logging Framework (debugPrint sufficient, Firebase Crashlytics for production)
- **#33:** Extract Magic Numbers (single-use values, over-engineering)
- **#34:** Rating Removal UX (current tap-same-star works fine)

### Key Wins
✅ Testing infrastructure in place
✅ Accessibility implemented
✅ Monitoring and crash reporting active
✅ Mobile UI optimizations started
✅ ListView performance optimization with keys

### Next Focus
Fix CRITICAL bugs first (C1-C3), then HIGH priority items (H3-H7, #1-2), then mobile UX improvements.

---

## 🏆 Code Quality

**Overall Grade: A- (90/100)**

### Strengths
- ✅ Excellent architecture and code organization
- ✅ Strong testing coverage with unit and widget tests
- ✅ Production monitoring with Firebase Crashlytics/Analytics
- ✅ Accessibility support implemented
- ✅ Clean separation of concerns with Provider state management
- ✅ Robust CI/CD pipeline

### Areas for Improvement
- ⚠️ Missing integration tests for end-to-end validation
- ⚠️ Some production hardening needed (CORS, retry logic, rate limiting)
- ⚠️ Mobile UI could be more space-efficient

### Conclusion
The app is well-architected, tested, and production-ready. Recent improvements in testing, accessibility, and monitoring have significantly increased quality. Remaining work is primarily polish and optimization.
