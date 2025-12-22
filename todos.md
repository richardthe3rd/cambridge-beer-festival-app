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
- **HIGH Priority:** 2 issues
- **MEDIUM Priority:** 4 issues
- **MOBILE UI (conditional on user feedback):** 5 issues
- **LOW Priority:** 7 issues
- **ACTIVE TOTAL:** 18 issues
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
