# Cambridge Beer Festival App - TODO List

**Last Updated:** 2025-12-21
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

## 🔴 HIGH PRIORITY

### 1. Remove Localhost from Production CORS
**Status:** ❌ Not Started
**Location:** `cloudflare-worker/worker.js:27-35`

**Issue:**
Production Cloudflare Worker still allows localhost origins:
```javascript
const ALLOWED_ORIGINS = [
  'https://richardthe3rd.github.io',
  'https://cambeerfestival.app',
  'https://staging.cambeerfestival.app',
  'https://tunnel.cambeerfestival.app',
  'http://localhost:8080',      // Should not be in production
  'http://localhost:3000',
  'http://127.0.0.1:8080',
];
```

**Solution:**
Use environment-based configuration or remove localhost origins from production deployment.

---

### 2. Add Integration Tests
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

### 3. Add Path Validation in Cloudflare Worker
**Status:** ❌ Not Started
**Location:** `cloudflare-worker/worker.js`

**Issue:**
No path sanitization before proxying requests. Validate/whitelist acceptable paths.

---

## 🟡 MEDIUM PRIORITY

### 4. Implement Retry Logic for Failed API Requests
**Status:** ❌ Not Started
**Location:** `lib/services/beer_api_service.dart`

**Issue:**
No automatic retry for temporary network glitches. Users must manually pull-to-refresh.

**Solution:**
Add exponential backoff retry (3 attempts: 500ms, 1s, 2s) for transient errors only.

---

### 5. Add Client-Side Rate Limiting
**Status:** ❌ Not Started
**Location:** `lib/providers/beer_provider.dart`

**Issue:**
Multiple rapid API calls possible (e.g., fast festival switching).

**Solution:**
Implement debouncing/throttling for API calls.

---

### 6. Add Cloud Sync for Favorites/Ratings
**Status:** ❌ Not Started
**Location:** `lib/services/storage_service.dart`

**Issue:**
Favorites/ratings stored locally only. Users lose data when switching devices.

**Solution:**
Consider Firebase Firestore or Supabase for cross-device sync.

---

### 7. Improve Test Coverage
**Status:** 🟡 In Progress
**Current:** ~45% test-to-code ratio
**Goal:** 70%+

**Files Still Missing Tests:**
- Some provider edge cases
- Additional screen states (loading, empty, error)
- Widget interaction flows

---

### 8. Add Loading State for URL Operations
**Status:** ❌ Not Started
**Location:** `lib/screens/festival_info_screen.dart`

**Issue:**
URL launching operations have no loading indicators. Users don't know if button press registered.

---

### 9. Apply SliverAppBar to FavoritesScreen
**Status:** ❌ Not Started
**Location:** `lib/main.dart:99-150`

**Issue:**
FavoritesScreen uses standard AppBar, not optimized for mobile like DrinksScreen.

**Solution:**
Apply same SliverAppBar pattern as DrinksScreen for consistency.

---

### 10. Eliminate Version Extraction Duplication in Release Workflows
**Status:** ❌ Not Started
**Location:** `.github/workflows/release-android.yml`, `.github/workflows/release-web.yml`

**Issue:**
Both release workflows have duplicate version extraction steps:
- "Get git version info" (uses `scripts/get_version_info.sh`) - extracts git metadata for build
- "Get version from tag" (inline bash) - extracts version for artifact naming and GitHub releases

For tag push triggers, both steps calculate the same version from different sources.

**Recommended Solutions:**
- **Option 1:** Enhance `scripts/get_version_info.sh` to accept workflow_dispatch version parameter as input
- **Option 2:** Reorder steps to use "Get version from tag" output for all version needs, keep git script only for commit/branch/timestamp metadata

**Impact:**
Simplified workflow logic, single source of truth for version information.

---

## 📱 MOBILE UI OPTIMIZATION

### 11. Implement Collapsible Festival Info Banner
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:247-319`

**Issue:**
Festival info banner takes up 40-50px of vertical space and cannot be dismissed.

**Solution:**
Allow user to dismiss/minimize the banner or move to AppBar expanded state.

**Impact:** Saves 40-50px on mobile

---

### 12. Consolidate Style Filter Controls
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:1004-1102`

**Issue:**
Style filter chips wrap vertically and can consume 80+ pixels on mobile.

**Recommended Solution:**
Horizontal scrolling for style chips.

**Impact:** Saves 40-80px on mobile

---

### 13. Reduce Mobile Card Density
**Status:** ❌ Not Started
**Location:** `lib/widgets/drink_card.dart`

**Issue:**
Drink cards use generous padding optimal for tablets but wasteful on mobile.

**Solution:**
Use responsive padding based on screen size (`MediaQuery.of(context).size.width < 600`).

**Impact:** Saves 20-30px per card

---

### 14. Move Search to FloatingActionButton or AppBar
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:83-130`

**Issue:**
Search button takes up space in bottom controls row on mobile.

**Solution:**
Move to AppBar actions or use FAB pattern.

---

### 15. Smart Default Filters for Mobile
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart:126-128`

**Issue:**
Style chips shown by default, consuming space even when not actively filtering.

**Solution:**
Hide style chips by default on mobile (<600dp width), show count in filter button instead.

**Impact:** Saves 36-80px on mobile by default

---

## 🟢 LOW PRIORITY (Nice to Have)

### 16. Add Method Documentation
**Files:** Throughout codebase
Missing DartDoc comments for complex methods (e.g., `BeerProvider._applyFiltersAndSort()`).

---

### 17. Add Screenshots to README
**Location:** `README.md:21`
README still says "Coming soon" for screenshots.

---

### 18. Create CHANGELOG.md
**Files:** Need to create `CHANGELOG.md`
No version history tracking for users/developers.

---

### 19. Move Hard-coded Fallback Data to Config
**Location:** `lib/models/festival.dart:124-155`
DefaultFestivals is hard-coded rather than in config file.

---

### 21. Add Dark Mode Icon Variants for PWA
**Location:** `web/manifest.json`
PWA manifest doesn't specify dark mode icons.

---

### 23. Add Logging Framework
**Files:** Throughout codebase
Consider adding structured logging (e.g., `logger` package) instead of debugPrint.

---

### 24. Add Performance Monitoring
**Files:** App-wide
Consider Firebase Performance or custom metrics for tracking performance regressions.

---

### 25. Convert async void methods to Future<void>
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

### 26. Extract Hardcoded Status Badge Colors
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

### 30. Add Semantics to Status Badge Labels
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

### 31. Add DartDoc Comments to Private Widget Classes
**Status:** ❌ Not Started
**Location:** `lib/screens/drinks_screen.dart` (lines 560, 613, 691, 777, 865, 996, 1178)

**Issue:**
The following private widget classes lack DartDoc comments:
- `_FilterButton` (line 560)
- `_SearchButton` (line 613)
- `_CategoryFilterSheet` (line 691)
- `_SortOptionsSheet` (line 777)
- `_StyleFilterSheet` (line 865)
- `_FestivalSelectorSheet` (line 996)
- `_FestivalCard` (line 1178)

**Solution:**
Add brief DartDoc comments explaining each widget's purpose.

**Impact:** Improves code maintainability, better IDE support
**Estimated time:** 15 minutes

---

### 32. Validate Festival ID Before Using in URLs
**Status:** ❌ Not Started
**Location:** `lib/screens/drink_detail_screen.dart:136`

**Issue:**
Festival ID is used directly in hashtag generation without validation. An empty or null festival ID should be handled explicitly.

**Solution:**
Add explicit validation before using festival ID in hashtags.

**Impact:** Defensive programming, prevents edge case issues
**Estimated time:** 5 minutes

---

### 33. Extract Magic Numbers in Spacing to Named Constants
**Status:** ❌ Not Started
**Location:** `lib/screens/about_screen.dart:548-549` (width: 32, height: 4)

**Issue:**
The bottom sheet divider has magic numbers `width: 32, height: 4` that could be extracted to constants for consistency.

**Solution:**
Define constants like `_kDividerWidth = 32.0` and `_kDividerHeight = 4.0`.

**Impact:** Improves maintainability, makes spacing intent clearer
**Estimated time:** 5 minutes

---

### 34. Consider Rating Removal UX Improvement
**Status:** ❌ Not Started
**Location:** `lib/widgets/star_rating.dart:64-70`

**Issue:**
Ratings are removed by tapping the same star again. While documented in the semantic hint, this may not be obvious to all users.

**Solution:**
Consider adding a separate "Clear" or "X" button to explicitly remove ratings.

**Impact:** Better UX clarity for rating removal
**Estimated time:** 20 minutes

---

## 📊 Summary

### By Priority
- **HIGH Priority:** 3 issues
- **MEDIUM Priority:** 10 issues
- **LOW Priority:** 16 issues (includes code quality items)
- **TOTAL:** 29 issues

### Completed Recently
- 14 items from previous review

### Key Wins
✅ Testing infrastructure in place
✅ Accessibility implemented
✅ Monitoring and crash reporting active
✅ Mobile UI optimizations started
✅ ListView performance optimization with keys

### Next Focus
Focus on HIGH priority items (#1-3), then mobile UX improvements (#10-14) for better user experience on phones.

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
