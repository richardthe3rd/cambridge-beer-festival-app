# Cambridge Beer Festival App - TODO List

**Code Review Date:** 2025-11-29
**Overall Code Quality Grade:** B+ (85/100)

---

## 🔴 HIGH PRIORITY (Must Fix Before Production)

### 1. Add HTTP Request Timeouts
**Severity:** High
**Location:** `lib/services/beer_api_service.dart:14`

**Issue:**
The app can hang indefinitely when network connections are slow or stalled. No timeout is configured for HTTP requests.

**Current Code:**
```dart
final response = await _client.get(Uri.parse(url));
// No timeout specified
```

**Proposed Solution:**
```dart
final response = await _client.get(Uri.parse(url))
  .timeout(const Duration(seconds: 30));
```

**Impact:**
- Users experience app freezing during poor network conditions
- Poor UX with no way to recover except app restart

---

### 2. Add Widget and UI Tests
**Severity:** High
**Files:** `test/` directory

**Issue:**
The app only has unit tests for models and services. No widget tests exist to validate UI behavior.

**Current State:**
- Only unit tests exist: `test/models_test.dart`, `test/services_test.dart`
- No widget tests
- No integration tests
- UI regressions won't be caught

**Screens Needing Tests:**
- `lib/screens/drinks_screen.dart`
- `lib/screens/drink_detail_screen.dart`
- `lib/screens/brewery_screen.dart`
- `lib/screens/festival_info_screen.dart`
- `lib/widgets/drink_card.dart`

**Test Coverage Needed:**
- Filter functionality
- Search functionality
- Sorting options
- Favorite toggling
- Rating drinks
- Festival switching
- Error states
- Loading states
- Empty states

**Impact:**
Cannot detect UI regressions automatically

---

### 3. Add Error Handling for URL Launches
**Severity:** High
**Location:** `lib/screens/festival_info_screen.dart:232, 242`

**Issue:**
URL launch operations fail silently with no user feedback.

**Current Code:**
```dart
if (await canLaunchUrl(url)) {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
// No else clause or error handling
```

**Problems:**
- Users click "Open in Maps" or "Visit Website" buttons
- Nothing happens if launching fails
- No visual feedback or error message

**Proposed Solution:**
```dart
try {
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error opening link: $e')),
    );
  }
}
```

**Impact:**
Poor UX when users can't determine if buttons work

---

### 4. Remove Localhost from Production CORS
**Severity:** High (Security)
**Location:** `cloudflare-worker/worker.js:20-25`

**Issue:**
Production Cloudflare Worker allows localhost origins in CORS configuration.

**Current Code:**
```javascript
const ALLOWED_ORIGINS = [
  'https://richardthe3rd.github.io',
  'http://localhost:8080',  // Should not be in production
  'http://localhost:3000',
  'http://127.0.0.1:8080',
];
```

**Security Concern:**
- Localhost origins should only be allowed in development
- Production deployment should not accept requests from localhost

**Proposed Solution:**
```javascript
const ALLOWED_ORIGINS = [
  'https://richardthe3rd.github.io',
  ...(ENVIRONMENT === 'development' ? [
    'http://localhost:8080',
    'http://localhost:3000',
    'http://127.0.0.1:8080',
  ] : []),
];
```

**Impact:**
Minor security concern, production should have stricter CORS

---

### 5. Add Integration Tests
**Severity:** High
**Files:** Need to create `integration_test/` directory

**Issue:**
No end-to-end integration tests exist to validate complete user journeys.

**Current State:**
- Unit tests exist for models and services
- No widget tests
- No integration tests
- Critical user paths not automatically validated

**User Flows to Test:**

1. **Browse to Detail Flow**
   - Launch app
   - See drinks list
   - Tap a drink
   - View drink details

2. **Search and Filter Flow**
   - Enter search query
   - Apply category filter
   - Change sort order
   - Verify results

3. **Favorites Flow**
   - Browse drinks
   - Add to favorites
   - Switch to Favorites tab
   - Verify favorite appears
   - Remove from favorites

4. **Festival Switching Flow**
   - Select different festival
   - Verify drinks reload
   - Verify favorites persist

5. **Brewery Details Flow**
   - Tap brewery name
   - See brewery screen
   - View all brewery drinks

6. **Error Recovery Flow**
   - Simulate network error
   - See error message
   - Tap retry
   - Verify recovery

**Implementation:**
Use Flutter's `integration_test` package

**Impact:**
Cannot validate that complete user journeys work correctly

---

## 🟡 MEDIUM PRIORITY (Should Fix Soon)

### 6. Add Accessibility Support
**Severity:** Medium (Critical for Public Apps)
**Files:** All screen and widget files

**Issue:**
The app has ZERO accessibility support. Screen readers won't work for visually impaired users.

**Current State:**
- No `Semantics` widgets used
- No `semanticLabel` properties set
- Interactive elements lack descriptions
- Compliance issue for accessibility standards

**Critical Widgets Needing Semantics:**
1. Filter buttons in DrinksScreen
2. Favorite buttons in DrinkCard
3. Navigation bar items
4. Search button/input
5. Sort dropdown
6. Festival selector
7. Action buttons (maps, website)

**Example Implementation:**
```dart
// Before
IconButton(
  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
  onPressed: () => toggleFavorite(),
)

// After
Semantics(
  label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
  button: true,
  child: IconButton(
    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
    onPressed: () => toggleFavorite(),
  ),
)
```

**Impact:**
- App unusable for screen reader users
- Legal/Compliance: May violate accessibility regulations

---

### 7. Use User-Friendly Error Messages
**Severity:** Medium
**Location:** `lib/providers/beer_provider.dart:102, 133, 167`

**Issue:**
Technical exception messages are shown directly to users, resulting in poor UX.

**Current Code:**
```dart
_error = e.toString(); // Shows "BeerApiException: ..." to users
```

**Problem:**
Users see messages like:
- "BeerApiException: Failed to fetch beer: 500"
- "Exception: Failed to load any drinks"

These are confusing and unprofessional.

**Proposed Solution:**
```dart
catch (e) {
  if (e is BeerApiException) {
    if (e.statusCode == 404) {
      _error = 'Festival data not found. Please try a different festival.';
    } else if (e.statusCode == 500) {
      _error = 'Server error. Please try again later.';
    } else {
      _error = 'Could not load drinks. Please check your connection.';
    }
  } else if (e is SocketException) {
    _error = 'No internet connection. Please check your network.';
  } else {
    _error = 'Something went wrong. Please try again.';
  }
}
```

**Impact:**
Poor user experience with confusing errors

---

### 8. Implement Retry Logic for Failed API Requests
**Severity:** Medium
**Location:** `lib/services/beer_api_service.dart`

**Issue:**
No automatic retry logic for API requests. Temporary network glitches require manual retry.

**Current Behavior:**
- Single API failure = complete failure
- Users must manually pull-to-refresh
- Temporary network issues cause unnecessary failures

**Proposed Solution:**
```dart
Future<T> _retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
  }
}
```

**Benefits:**
- Improved reliability on flaky networks
- Better UX - automatic recovery
- Reduces user frustration

**Configuration:**
- 3 attempts maximum
- 500ms, 1s, 2s backoff delays
- Only retry on transient errors (network, timeout)
- Don't retry on 4xx errors (client errors)

**Impact:**
Temporary network issues cause unnecessary failures

---

### 9. Add Keys to ListView Items
**Severity:** Medium
**Location:** `lib/main.dart:132-152`, `lib/screens/drinks_screen.dart:321-333`

**Issue:**
ListView.builder items lack keys, which can cause performance issues and animation glitches.

**Current Code:**
```dart
ListView.builder(
  itemCount: favorites.length,
  itemBuilder: (context, index) {
    final drink = favorites[index];
    return DrinkCard(  // Missing key parameter
      drink: drink,
      onTap: () => _navigateToDetail(context, drink),
    );
  },
)
```

**Problem:**
- Flutter can't efficiently identify which items changed
- Can cause wrong widgets to update when list changes
- Animations may glitch during reordering
- Favorites toggle might animate incorrectly

**Proposed Solution:**
```dart
ListView.builder(
  itemCount: favorites.length,
  itemBuilder: (context, index) {
    final drink = favorites[index];
    return DrinkCard(
      key: ValueKey(drink.id),  // Add unique key
      drink: drink,
      onTap: () => _navigateToDetail(context, drink),
    );
  },
)
```

**Impact:**
- Can cause visual glitches when favoriting/unfavoriting
- Affects performance with large lists

---

### 10. Add Firebase Crashlytics and Analytics
**Severity:** Medium
**Files:** New dependencies and configuration needed

**Issue:**
No crash reporting or analytics in the app. Cannot track production issues or user behavior.

**Current State:**
- No crash reporting
- No analytics
- No way to diagnose production issues
- No insights into user behavior

**Proposed Solution:**
Add Firebase:
1. **Firebase Crashlytics** - Automatic crash reporting
2. **Firebase Analytics** - User behavior tracking
3. **Firebase Performance** - Performance monitoring (optional)

**Implementation Steps:**
1. Add FlutterFire dependencies
2. Configure Firebase project
3. Add Firebase config files
4. Initialize in main.dart
5. Add custom event tracking

**Key Events to Track:**
- App launch
- Festival selection
- Search usage
- Filter usage
- Favorites added/removed
- Drink details viewed
- Brewery details viewed
- Ratings given

**Dependencies:**
```yaml
firebase_core: ^latest
firebase_crashlytics: ^latest
firebase_analytics: ^latest
```

**Impact:**
Cannot diagnose production issues or understand user behavior

---

### 11. Add Path Validation in Cloudflare Worker
**Severity:** Medium (Security)
**Location:** `cloudflare-worker/worker.js:81`

**Issue:**
No path sanitization before proxying requests.

**Current Code:**
```javascript
const upstreamUrl = UPSTREAM_URL + url.pathname + url.search;
```

**Problem:**
Potential for path traversal attacks

**Proposed Solution:**
Validate/whitelist acceptable paths before proxying

**Impact:**
Security vulnerability for path traversal

---

### 12. Add Client-Side Rate Limiting
**Severity:** Medium
**Location:** `lib/providers/beer_provider.dart`

**Issue:**
Multiple rapid API calls possible (e.g., fast festival switching).

**Problem:**
- Unnecessary API load
- Potential worker costs
- Poor UX during rapid changes

**Proposed Solution:**
Implement debouncing/throttling for API calls

**Impact:**
Unnecessary load on API and poor performance

---

### 13. Add Cloud Sync for Favorites/Ratings
**Severity:** Medium
**Location:** `lib/services/storage_service.dart`

**Issue:**
Favorites/ratings not synced across devices.

**Current Implementation:**
Uses SharedPreferences (local only), no cloud sync

**Problem:**
Users lose favorites when switching devices

**Proposed Solution:**
Consider Firebase/Supabase for user data sync

**Impact:**
Users lose data when switching devices

---

### 14. Improve Test Coverage
**Severity:** Medium
**Files:** Need tests for providers and screens

**Issue:**
Limited test coverage - only 41% test-to-code ratio.

**Files Missing Tests:**
- `lib/providers/beer_provider.dart` (315 LOC, no tests)
- `lib/screens/*.dart` (1,470 LOC, no tests)
- `lib/widgets/drink_card.dart` (197 LOC, no tests)

**Goal:**
Increase test coverage to 70%+

**Impact:**
Cannot catch bugs in untested code

---

### 15. Add Loading State for URL Operations
**Severity:** Medium
**Location:** `lib/screens/festival_info_screen.dart`

**Issue:**
URL launching operations have no loading indicators.

**Problem:**
Users don't know if button press was registered

**Proposed Solution:**
Add loading indicators during async operations

**Impact:**
Poor UX - unclear if action is processing

---

## 🟢 LOW PRIORITY (Nice to Have)

### 16. Add Method Documentation
**Severity:** Low
**Files:** Throughout codebase

**Issue:**
Missing DartDoc comments for complex methods.

**Examples:**
- `BeerProvider._applyFiltersAndSort()` - Complex filtering logic undocumented
- `Product.fromJson()` - No docs explaining type handling edge cases

**Impact:**
Harder for new developers to understand code

---

### 17. Add Screenshots to README
**Severity:** Low
**Location:** `README.md:21`

**Issue:**
README says "Coming soon" for screenshots.

**Impact:**
Users can't preview app before installation

---

### 18. Create CHANGELOG.md
**Severity:** Low
**Files:** Need to create `CHANGELOG.md`

**Issue:**
No CHANGELOG.md to track version history.

**Impact:**
Users/developers can't see what changed between versions

---

### 19. Move Hard-coded Fallback Data to Config
**Severity:** Low
**Location:** `lib/models/festival.dart:124-155`

**Issue:**
DefaultFestivals is hard-coded rather than in config.

**Problem:**
Requires code changes to update fallback festivals

**Proposed Solution:**
Move to JSON config file

**Impact:**
Minor maintainability issue

---

### 20. Document IndexedStack Memory Trade-off
**Severity:** Low
**Location:** `lib/main.dart:67`

**Issue:**
IndexedStack keeps both tabs in memory.

**Current Code:**
```dart
body: IndexedStack(
  index: _currentIndex,
  children: const [
    DrinksScreen(),
    FavoritesScreen(), // Always in memory even when not visible
  ],
),
```

**Note:**
This is by design for smooth navigation, but worth documenting the trade-off.

**Impact:**
Minor memory overhead (acceptable for UX)

---

### 21. Add Dark Mode Icon Variants for PWA
**Severity:** Low
**Location:** `web/manifest.json`

**Issue:**
PWA manifest doesn't specify dark mode icons.

**Impact:**
Icons may not look good in dark mode browsers

---

### 22. Validate Icon Assets Exist
**Severity:** Low
**Location:** `web/manifest.json`

**Issue:**
References icons (Icon-192.png, Icon-512.png) but existence not verified.

**Action:**
Ensure all referenced assets exist

---

### 23. Add Logging Framework
**Severity:** Low
**Files:** Throughout codebase

**Issue:**
No structured logging (using debugPrint or nothing).

**Problem:**
Harder to debug production issues

**Proposed Solution:**
Add logger package (e.g., `logger` or `flutter_logs`)

**Impact:**
Debugging production issues is difficult

---

### 24. Add Performance Monitoring
**Severity:** Low
**Files:** App-wide

**Issue:**
No frame rate or performance tracking.

**Problem:**
Can't identify performance regressions

**Proposed Solution:**
Add Firebase Performance or custom metrics

**Impact:**
Cannot track performance over time

---

### 25. Add Input Validation for Ratings
**Severity:** Low
**Location:** `lib/services/storage_service.dart:75`

**Issue:**
Rating not validated before clamping.

**Current Code:**
```dart
await _prefs.setInt(key, rating.clamp(1, 5));
```

**Note:**
Clamp is good, but should validate rating is reasonable before accepting

**Impact:**
Minor data integrity issue

---

## 📊 Summary

### By Severity
- **HIGH Priority:** 5 issues
- **MEDIUM Priority:** 10 issues
- **LOW Priority:** 15 issues
- **TOTAL:** 30 issues

### By Category
- **Testing:** 3 issues (High: 2, Medium: 1)
- **Accessibility:** 1 issue (Medium: 1)
- **Error Handling:** 3 issues (High: 2, Medium: 1)
- **Security:** 2 issues (High: 1, Medium: 1)
- **Performance:** 2 issues (Medium: 1, Low: 1)
- **UX:** 4 issues (High: 1, Medium: 2, Low: 1)
- **Documentation:** 3 issues (Low: 3)
- **Monitoring:** 2 issues (Medium: 1, Low: 2)
- **Configuration:** 3 issues (Medium: 1, Low: 2)
- **Features:** 7 issues (Medium: 3, Low: 4)

---

## 🎯 Recommended Implementation Order

### Phase 1: Critical Fixes (This Week)
1. ✅ Add HTTP request timeouts (#1)
2. ✅ Add error handling for URL launches (#3)
3. ✅ Remove localhost from production CORS (#4)
4. ✅ Use user-friendly error messages (#7)

### Phase 2: Testing & Accessibility (Next 2 Weeks)
5. ✅ Add widget tests for main screens (#2)
6. ✅ Add accessibility support (#6)
7. ✅ Add retry logic for API calls (#8)
8. ✅ Add keys to list items (#9)

### Phase 3: Monitoring & Polish (Next Month)
9. ✅ Add Firebase Crashlytics and Analytics (#10)
10. ✅ Add integration tests (#5)
11. ✅ Improve test coverage (#14)
12. ✅ Add path validation in worker (#11)

### Phase 4: Enhancements (Ongoing)
13. ✅ Add cloud sync for favorites (#13)
14. ✅ Add client-side rate limiting (#12)
15. ✅ Add logging framework (#23)
16. ✅ Documentation improvements (#16-18)

---

## 🏆 Code Quality Assessment

**Overall Grade: B+ (85/100)**

### Strengths
- ✅ Excellent architecture and code organization
- ✅ Clean separation of concerns
- ✅ Strong CI/CD pipeline
- ✅ Good security practices (no hardcoded secrets, HTTPS-only)
- ✅ Proper use of Provider state management
- ✅ Comprehensive model tests

### Areas for Improvement
- ⚠️ Missing accessibility features (critical compliance issue)
- ⚠️ Gaps in testing coverage (no widget/integration tests)
- ⚠️ Some UX edge cases need handling
- ⚠️ Production hardening (timeouts, retry logic, monitoring)

### Conclusion
The app is well-architected and follows Flutter best practices. The code is clean, organized, and maintainable. The main concerns are testing gaps, accessibility (major compliance issue), and UX edge cases. The app is production-ready for a v1.0 but needs HIGH priority issues addressed before widespread deployment.
