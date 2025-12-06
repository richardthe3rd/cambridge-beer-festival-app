# Cambridge Beer Festival App - TODO List

**Last Updated:** 2025-12-04
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

---

## 🔴 HIGH PRIORITY

### 1. Remove Localhost from Production CORS
**Status:** ❌ Not Started
**Location:** `cloudflare-worker/worker.js:22-28`

**Issue:**
Production Cloudflare Worker still allows localhost origins:
```javascript
const ALLOWED_ORIGINS = [
  'https://richardthe3rd.github.io',
  'https://cambeerfestival.app',
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

### 20. Document IndexedStack Memory Trade-off
**Location:** `lib/main.dart:67`
IndexedStack keeps both tabs in memory by design - worth documenting the UX trade-off.

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

### 25. Add Input Validation for Ratings
**Location:** `lib/services/storage_service.dart:75`
Rating values should be validated before clamping.

---

## 📊 Summary

### By Priority
- **HIGH Priority:** 3 issues
- **MEDIUM Priority:** 10 issues
- **LOW Priority:** 11 issues
- **TOTAL:** 24 issues

### Completed Recently
- 9 items from previous review

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
