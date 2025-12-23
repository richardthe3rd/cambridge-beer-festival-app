# Implementation Decisions for Festival Features

This document presents key architectural and design decisions as multiple-choice questions. Each includes pros/cons and a recommendation with rationale.

---

## Phase 1: Festival Linking Decisions

### Decision 1.1: Invalid Festival ID Handling

**Question:** When a user navigates to an invalid festival ID (e.g., `/invalid-fest/drinks`), what should happen?

**Options:**

**A) Redirect to current/default festival with same path**
- Example: `/invalid-fest/drinks` → `/cbf2025/drinks`
- ✅ Pros: User stays on the page they wanted, just with valid festival
- ✅ Pros: Seamless experience, no disruption
- ❌ Cons: Silent failure - user might not notice
- ❌ Cons: Confusing if user intentionally tried to access old festival

**B) Show error page with link to festival list**
- Example: "Festival 'invalid-fest' not found. View available festivals."
- ✅ Pros: Clear feedback about the problem
- ✅ Pros: Opportunity to show all available festivals
- ❌ Cons: Disruptive user experience
- ❌ Cons: Requires creating error page

**C) Redirect to root (home page) of current festival**
- Example: `/invalid-fest/drinks` → `/cbf2025`
- ✅ Pros: Safe fallback to known-good state
- ✅ Pros: Simple to implement
- ❌ Cons: User loses intended path (drinks, brewery, etc.)
- ❌ Cons: Confusing - ends up on home when they wanted drinks

**D) Show 404 page**
- Example: Standard Flutter error route
- ✅ Pros: Standard web behavior
- ✅ Pros: Clear that something is wrong
- ❌ Cons: Doesn't help user recover
- ❌ Cons: Poor mobile app experience

**RECOMMENDATION: Option A (Redirect to current festival, preserve path)**

**Why:**
- Best user experience - they get the content they wanted
- Mobile-first design - seamless, no error states
- Old festival URLs will gracefully redirect to current festival
- Can add optional toast notification: "Showing drinks for current festival"

**Implementation:**
```dart
// In router.dart redirect
redirect: (context, state) {
  final festivalId = state.pathParameters['festivalId'];
  final provider = context.read<BeerProvider>();

  if (!provider.isValidFestival(festivalId)) {
    final currentId = provider.currentFestival?.id ?? 'cbf2025';
    final newPath = state.uri.path.replaceFirst(
      '/$festivalId',
      '/$currentId'
    );
    return newPath;
  }
  return null; // No redirect needed
}
```

---

### Decision 1.2: Breadcrumb Display Style

**Question:** How should breadcrumbs be displayed on detail screens?

**Options:**

**A) Compact horizontal bar (Material breadcrumb style)**
- Example: `Home > Beer > Oakham Ales > Citra`
- ✅ Pros: Standard web pattern, familiar to users
- ✅ Pros: Space-efficient
- ❌ Cons: Can overflow on small screens
- ❌ Cons: Small touch targets

**B) Large back button + context text**
- Example: `← Beer / Oakham Ales` (large back arrow, small context text)
- ✅ Pros: Large touch target (mobile-friendly)
- ✅ Pros: Clear back action
- ❌ Cons: Less context visible
- ❌ Cons: Can't jump to intermediate levels

**C) Chip-style breadcrumbs**
- Example: `[Home] > [Beer] > [Oakham Ales] > Citra` (chips for clickable items)
- ✅ Pros: Clear affordance (chips = clickable)
- ✅ Pros: Large touch targets
- ❌ Cons: Takes more vertical space
- ❌ Cons: Can look cluttered

**D) Dropdown menu + back button**
- Example: Back arrow + dropdown showing "Beer > Oakham Ales > Citra"
- ✅ Pros: Compact
- ✅ Pros: Can jump to any level
- ❌ Cons: Hidden navigation (requires tap to see options)
- ❌ Cons: More complex interaction

**RECOMMENDATION: Option B (Large back button + context text)**

**Why:**
- Mobile-first design prioritizes touch targets
- Most users want to go back one level, not jump
- Simple, clear affordance
- Matches Material Design navigation patterns
- Accessibility: Large target = easier for motor impairments

**Implementation:**
```dart
class BreadcrumbBar extends StatelessWidget {
  final String backLabel;     // e.g., "Beer"
  final String? context;      // e.g., "Oakham Ales"
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Large back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            iconSize: 28,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          // Context text
          Expanded(
            child: Text(
              context != null ? '$backLabel / $context' : backLabel,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Decision 1.3: Festival Switching UI

**Question:** Where should users be able to switch festivals?

**Options:**

**A) AppBar dropdown (always visible)**
- Example: "Cambridge Beer Festival 2025 ▼" in AppBar
- ✅ Pros: Always accessible
- ✅ Pros: Clear current festival
- ❌ Cons: Takes AppBar space
- ❌ Cons: Most users stay in one festival

**B) Settings/More screen only**
- Example: "Change Festival" button in settings
- ✅ Pros: Clean main UI
- ✅ Pros: Reflects infrequent action
- ❌ Cons: Less discoverable
- ❌ Cons: Requires navigation to settings

**C) Home screen header**
- Example: Large festival name at top of drinks list, tappable
- ✅ Pros: Prominent but not intrusive
- ✅ Pros: Makes sense on home screen
- ❌ Cons: Not accessible from deep screens
- ❌ Cons: May not look tappable

**D) Drawer menu**
- Example: Side navigation drawer with festival list
- ✅ Pros: Standard pattern
- ✅ Pros: Room for multiple festivals
- ❌ Cons: Requires drawer (not in current design)
- ❌ Cons: Adds UI complexity

**RECOMMENDATION: Option B (Settings screen) + Option C (Home header) combined**

**Why:**
- Most users attend one festival at a time
- Festival switching is rare (maybe once per year)
- Settings screen is the right place for infrequent actions
- Home screen header provides discoverability without clutter
- No need to add drawer or clutter AppBar

**Implementation:**
- Home screen: Large festival name/logo at top (tappable)
- Settings screen: "Change Festival" button
- Both navigate to FestivalListScreen (new screen)
- Deep links automatically switch festival via URL

---

## Phase 3-4: Festival Log Decisions

### Decision 2.1: "Want to Try" vs "Tasted" Visual Design

**Question:** How should we visually distinguish drink states in the festival log?

**Options:**

**A) Color-coded backgrounds**
- "Want to try": Light blue background
- "Tasted": Light green background
- ✅ Pros: Very clear distinction
- ✅ Pros: Easy to scan
- ❌ Cons: Accessibility issues (color-blind users)
- ❌ Cons: Can look cluttered/overwhelming

**B) Icon badges only (current plan)**
- "Want to try": Grey circle badge
- "Tasted": Green checkmark badge
- Multiple tastings: Number badge
- ✅ Pros: Subtle, clean design
- ✅ Pros: Works with existing card design
- ❌ Cons: Small badges may be hard to see
- ❌ Cons: Relies on icon recognition

**C) Opacity + icon**
- "Want to try": Full opacity + circle badge
- "Tasted": 60% opacity + checkmark badge
- ✅ Pros: Clear visual hierarchy
- ✅ Pros: "Tasted" items fade to background
- ❌ Cons: Faded items harder to read
- ❌ Cons: May look broken/disabled

**D) Sections with headers**
- "To Try" section (full cards)
- "Tasted" section (compact cards)
- ✅ Pros: Very clear organization
- ✅ Pros: Can collapse sections
- ❌ Cons: Not unified list (contradicts design)
- ❌ Cons: More scrolling required

**RECOMMENDATION: Option B (Icon badges only) with enhanced accessibility**

**Why:**
- Matches design doc (PR/FAQ says "simple, visual indicators")
- Clean, minimal design fits app aesthetic
- Accessible if implemented correctly (Semantics + good contrast)
- Scalable (can add more states later)

**Implementation requirements:**
- Icons must have good color contrast (WCAG AA)
- Add Semantics labels for screen readers
- Make badges larger (24x24 minimum)
- Add optional "Show labels" accessibility setting

```dart
// Enhanced badge widget
Widget _buildStatusBadge(FavoriteItem item) {
  final (icon, color, label) = switch (item.status) {
    'want_to_try' => (Icons.circle_outlined, Colors.grey, 'Want to try'),
    'tasted' when item.tries.length == 1 =>
      (Icons.check_circle, Colors.green, 'Tasted once'),
    'tasted' =>
      (Icons.check_circle, Colors.green, 'Tasted ${item.tries.length} times'),
    _ => (Icons.circle_outlined, Colors.grey, 'Unknown'),
  };

  return Semantics(
    label: label,
    child: Icon(icon, color: color, size: 24),
  );
}
```

---

### Decision 2.2: Timestamp Editing Capabilities

**Question:** What should users be able to do with tasting timestamps?

**Options:**

**A) Append-only (no editing/deleting)**
- Users can only add new tastings
- ✅ Pros: Simple, no data loss
- ✅ Pros: Preserves history integrity
- ❌ Cons: Can't fix mistakes (wrong drink, accidental tap)
- ❌ Cons: Frustrating if user makes error

**B) Edit and delete freely**
- Users can edit timestamp, add notes, delete tries
- ✅ Pros: Full flexibility
- ✅ Pros: Can fix mistakes
- ❌ Cons: More complex UI
- ❌ Cons: Can accidentally lose data

**C) Delete only (no editing)**
- Users can delete mistakes, but can't change timestamps
- ✅ Pros: Balance of flexibility and simplicity
- ✅ Pros: Can fix major mistakes (wrong drink)
- ❌ Cons: If timestamp is wrong, must delete and re-add
- ❌ Cons: Still some data loss risk

**D) Edit with audit trail**
- All edits logged (original + edited timestamps)
- ✅ Pros: Full history preserved
- ✅ Pros: Maximum flexibility
- ❌ Cons: Very complex to implement
- ❌ Cons: Overkill for casual use

**RECOMMENDATION: Option C (Delete only) for v1, Option B (Edit freely) for v2**

**Why:**
- v1: Keep it simple, users can delete mistakes and re-add
- Most errors are "wrong drink" not "wrong time"
- Delete is easier to implement safely (no edit UI needed)
- v2: Add edit capability based on user feedback
- Can always add features later, harder to remove complexity

**Implementation (v1):**
```dart
// In DrinkDetailScreen
class TryHistoryList extends StatelessWidget {
  final List<DateTime> tries;
  final Function(DateTime) onDeleteTry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var tryDate in tries)
          ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text(_formatTryDate(tryDate)),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, tryDate),
            ),
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, DateTime tryDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete tasting?'),
        content: Text('Remove tasting from ${_formatTryDate(tryDate)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onDeleteTry(tryDate);
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
```

---

### Decision 2.3: Festival Log Screen Layout

**Question:** How should the Festival Log screen organize drinks?

**Options:**

**A) Unified list with filters**
- Single scrollable list, all drinks mixed
- Filter chips at top: "All" | "To Try" | "Tasted"
- ✅ Pros: Matches design doc (unified list)
- ✅ Pros: Simple, familiar pattern
- ❌ Cons: "To try" and "Tasted" intermixed by default
- ❌ Cons: Harder to see what you've tried

**B) Two sections (collapsible)**
- "To Try" section (expanded by default)
- "Tasted" section (collapsed by default)
- ✅ Pros: Clear separation
- ✅ Pros: Can hide tasted drinks
- ❌ Cons: Contradicts design doc (wants unified list)
- ❌ Cons: More complex UI

**C) Sort by status (smart order)**
- Single list, sorted: "To try" first, then "Tasted"
- Visual divider between groups
- ✅ Pros: Unified list (matches design)
- ✅ Pros: "To try" drinks at top (most relevant)
- ✅ Pros: Clear organization via sort
- ❌ Cons: Can't easily filter to just one state

**D) Tabs**
- Tab 1: "To Try" | Tab 2: "Tasted"
- ✅ Pros: Very clear separation
- ✅ Pros: Can show count badges on tabs
- ❌ Cons: Contradicts design doc (wants unified)
- ❌ Cons: Can't see both at once

**RECOMMENDATION: Option C (Sort by status) with optional filter**

**Why:**
- Matches design doc's "unified list" requirement
- Puts actionable items ("to try") at the top
- Simple visual divider shows grouping
- Can add filter chips later if needed
- Clean, scannable design

**Implementation:**
```dart
class FestivalLogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final favorites = provider.favoriteDrinks;

    // Sort: "want to try" first, then "tasted"
    final sorted = favorites.toList()
      ..sort((a, b) {
        final statusA = provider.getFavoriteStatus(a);
        final statusB = provider.getFavoriteStatus(b);

        // "want_to_try" comes before "tasted"
        if (statusA == 'want_to_try' && statusB == 'tasted') return -1;
        if (statusA == 'tasted' && statusB == 'want_to_try') return 1;

        // Within same status, sort by name
        return a.name.compareTo(b.name);
      });

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final drink = sorted[index];
        final status = provider.getFavoriteStatus(drink);

        // Show divider between "to try" and "tasted"
        final showDivider = index > 0 &&
          provider.getFavoriteStatus(sorted[index - 1]) != status;

        return Column(
          children: [
            if (showDivider) _buildSectionDivider(status),
            DrinkCard(drink: drink, showStatusBadge: true),
          ],
        );
      },
    );
  }

  Widget _buildSectionDivider(String status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              status == 'tasted' ? 'Tasted' : '',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}
```

---

## Phase 5-6: Cloud Sync Decisions

### Decision 3.1: Authentication Strategy

**Question:** How should users authenticate for cloud sync?

**Options:**

**A) Anonymous authentication only (v1)**
- Users get a unique ID automatically
- No login required
- ✅ Pros: Zero friction, seamless experience
- ✅ Pros: Works immediately, no setup
- ✅ Pros: Privacy-friendly (no personal data)
- ❌ Cons: Data lost if app is uninstalled (without backup)
- ❌ Cons: Can't sync across devices initially
- ❌ Cons: Requires account linking later for multi-device

**B) Social login required (Google/Apple)**
- Users must sign in with Google or Apple account
- ✅ Pros: Persistent identity across devices
- ✅ Pros: Easy account recovery
- ✅ Pros: Industry standard
- ❌ Cons: Friction - users must sign in
- ❌ Cons: Privacy concerns for some users
- ❌ Cons: Requires Google/Apple developer setup

**C) Email/password authentication**
- Traditional account creation
- ✅ Pros: No third-party dependence
- ✅ Pros: Full control over auth flow
- ❌ Cons: High friction (forms, validation, etc.)
- ❌ Cons: Password reset complexity
- ❌ Cons: Most users prefer social login

**D) Anonymous + optional social link (hybrid)**
- Start anonymous, offer "Link account" later
- ✅ Pros: Zero initial friction
- ✅ Pros: Can upgrade to persistent account
- ✅ Pros: Best of both worlds
- ❌ Cons: More complex implementation
- ❌ Cons: Need to handle account linking edge cases

**RECOMMENDATION: Option D (Anonymous + optional social link)**

**Why:**
- Phase 5.2: Start with anonymous (immediate sync, no friction)
- Phase 6.1: Add "Link account" option for multi-device users
- Best user experience: works immediately, can upgrade later
- Matches app's offline-first philosophy
- Firebase Auth supports this pattern natively

**Implementation plan:**
```dart
// Phase 5.2: Anonymous auth
class AuthService {
  Future<User?> signInAnonymously() async {
    final credential = await FirebaseAuth.instance.signInAnonymously();
    return credential.user;
  }
}

// Phase 6.1: Add account linking
class AuthService {
  Future<User?> linkWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return null;

    final googleProvider = GoogleAuthProvider();
    final credential = await user.linkWithProvider(googleProvider);
    return credential.user;
  }
}
```

**User flow:**
1. First launch: Auto sign-in anonymously (invisible)
2. Data syncs to cloud with anonymous ID
3. Later: User taps "Link account" in settings
4. Choose Google/Apple
5. Anonymous data merged with persistent account
6. Can now sync across devices

---

### Decision 3.2: Cloud Storage Backend

**Question:** Which Firebase database should we use for cloud sync?

**Options:**

**A) Cloud Firestore**
- NoSQL document database
- ✅ Pros: Excellent offline support (built-in)
- ✅ Pros: Structured queries
- ✅ Pros: Automatic conflict resolution
- ✅ Pros: Better scaling for complex features
- ✅ Pros: Modern Firebase recommendation
- ❌ Cons: More complex pricing (reads/writes)
- ❌ Cons: Slightly higher latency than RTDB

**B) Realtime Database (RTDB)**
- JSON tree database
- ✅ Pros: Very low latency
- ✅ Pros: Simple pricing (storage + bandwidth)
- ✅ Pros: Simpler data model (just JSON)
- ❌ Cons: Limited offline support (must implement manually)
- ❌ Cons: No structured queries
- ❌ Cons: Harder to scale complex features
- ❌ Cons: Legacy technology (Firebase recommends Firestore)

**C) Cloud Storage**
- File storage (like S3)
- ✅ Pros: Very simple for backup/restore
- ✅ Pros: Cheapest option
- ❌ Cons: No real-time sync
- ❌ Cons: Must implement all sync logic manually
- ❌ Cons: No offline support
- ❌ Cons: Overwrites entire file (no granular updates)

**D) Custom backend (REST API)**
- Build your own server
- ✅ Pros: Full control
- ✅ Pros: Can optimize for exact use case
- ❌ Cons: Significant development effort
- ❌ Cons: Must build offline support
- ❌ Cons: Must handle scaling, security, etc.
- ❌ Cons: Ongoing server maintenance

**RECOMMENDATION: Option A (Cloud Firestore)**

**Why:**
- Built-in offline support is critical for festival app
- Poor connectivity at festivals requires robust offline mode
- Structured queries enable future features (search, filters, analytics)
- Automatic conflict resolution handles multi-device edge cases
- Modern, well-supported by Flutter
- Room to grow (festival summaries, shared lists, etc.)

**Data structure:**
```
/users/{userId}/
  /festivals/{festivalId}/
    /favorites/{drinkId}/
      - id: string
      - status: "want_to_try" | "tasted"
      - tries: Timestamp[]
      - notes: string?
      - createdAt: Timestamp
      - updatedAt: Timestamp
    /ratings/{drinkId}/
      - rating: number (1-5)
      - updatedAt: Timestamp
  /profile/
    - createdAt: Timestamp
    - linkedAccounts: string[]
```

**Pricing estimate (free tier):**
- Firestore free tier: 50k reads, 20k writes, 1GB storage per day
- Typical user: ~100 favorites, ~50 ratings per festival
- Sync on app open + after changes: ~10 syncs per day
- Usage: ~150 reads + 5 writes per day
- **Well within free tier**, even for hundreds of users

---

### Decision 3.3: Sync Trigger Strategy

**Question:** When should the app sync data to the cloud?

**Options:**

**A) Manual sync only**
- User taps "Sync now" button
- ✅ Pros: User has full control
- ✅ Pros: No background battery usage
- ✅ Pros: Simple to implement
- ❌ Cons: Users will forget to sync
- ❌ Cons: Data loss if phone is lost
- ❌ Cons: Poor multi-device experience

**B) Automatic sync (aggressive)**
- Sync after every favorite/rating change
- Sync on app resume
- Sync every 5 minutes in background
- ✅ Pros: Data is always current
- ✅ Pros: No data loss
- ❌ Cons: Battery drain
- ❌ Cons: Network usage (problem at festivals)
- ❌ Cons: Complexity (background sync on mobile)

**C) Hybrid: Auto-sync with debouncing (smart)**
- Sync on app resume (foreground only)
- Sync after local changes (debounced 30 seconds)
- No background sync
- Manual "Sync now" option available
- ✅ Pros: Good balance of automatic + battery friendly
- ✅ Pros: Data synced when it matters (app is active)
- ✅ Pros: User can force sync if needed
- ❌ Cons: Slight delay in multi-device sync
- ❌ Cons: More complex than manual only

**D) Periodic sync (scheduled)**
- Sync once per hour (background)
- Sync on app resume
- ✅ Pros: Predictable sync schedule
- ✅ Pros: Low battery impact
- ❌ Cons: Up to 1 hour data lag
- ❌ Cons: Background sync complexity
- ❌ Cons: May sync when network is poor

**RECOMMENDATION: Option C (Hybrid auto-sync) - Phased implementation**

**Why:**
- Matches offline-first philosophy
- Battery-friendly (no background sync)
- Data is fresh when app is in use
- Users can force sync when switching devices
- Gracefully handles poor festival connectivity

**Phased implementation:**

**Phase 5.4 (v1): Manual sync only**
- Build the foundation safely
- Test sync logic thoroughly
- Get user feedback

**Phase 5.5 (v2): Add auto-sync**
- Add app resume listener
- Add debounced sync on changes
- Keep manual sync option

**Implementation:**
```dart
// Phase 5.5: Auto-sync with debouncing
class SyncService {
  Timer? _syncTimer;

  void scheduleSync() {
    // Cancel existing timer
    _syncTimer?.cancel();

    // Debounce: sync 30 seconds after last change
    _syncTimer = Timer(Duration(seconds: 30), () {
      syncToCloud();
    });
  }

  void syncOnResume() {
    // Called when app resumes from background
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(onResume: syncToCloud),
    );
  }

  Future<void> syncToCloud() async {
    if (!await _hasConnectivity()) {
      // Queue for later
      _queueSync();
      return;
    }

    // Sync logic...
  }
}
```

**Settings UI:**
```dart
// In settings screen
SwitchListTile(
  title: Text('Auto-sync'),
  subtitle: Text('Sync when app is active'),
  value: settings.autoSyncEnabled,
  onChanged: (value) => settings.setAutoSync(value),
),
ListTile(
  title: Text('Sync now'),
  trailing: Icon(Icons.sync),
  onTap: () => syncService.syncToCloud(),
),
```

---

### Decision 3.4: Conflict Resolution Strategy

**Question:** When the same favorite is modified on two devices offline, how should we merge the changes?

**Scenarios:**
- Device A: Mark as "tasted" at 2pm
- Device B: Still marked as "want to try"
- Both devices sync at 3pm - what happens?

**Options:**

**A) Last-write-wins (server timestamp)**
- Most recent change wins (based on server timestamp)
- Other changes are discarded
- ✅ Pros: Simple to implement
- ✅ Pros: Firestore supports this natively
- ✅ Pros: Works well for single-user data
- ❌ Cons: Can lose data (earlier changes discarded)
- ❌ Cons: Confusing if user sees change "undo"

**B) Last-write-wins (client timestamp)**
- Most recent change wins (based on device time)
- ✅ Pros: Respects user's timeline
- ✅ Pros: Simple to implement
- ❌ Cons: Vulnerable to incorrect device time
- ❌ Cons: Can still lose data

**C) Merge tries lists (custom logic)**
- Merge try timestamps from both devices
- Status becomes "tasted" if tasted on either device
- ✅ Pros: No data loss
- ✅ Pros: Logical for try tracking
- ❌ Cons: More complex implementation
- ❌ Cons: Can result in duplicate timestamps
- ❌ Cons: Must handle timestamp deduplication

**D) Prompt user to resolve**
- Show conflict dialog: "Keep Device A or Device B?"
- ✅ Pros: User has full control
- ✅ Pros: No data loss
- ❌ Cons: Interrupts user experience
- ❌ Cons: Most users won't understand conflict
- ❌ Cons: Can be overwhelming

**E) Optimistic: Prefer "tasted" over "want to try"**
- If status differs, "tasted" wins
- Merge all try timestamps
- ✅ Pros: Logical (can't "untaste" a beer)
- ✅ Pros: No data loss for tries
- ✅ Pros: Matches user expectations
- ❌ Cons: Custom logic needed
- ❌ Cons: What about ratings conflicts?

**RECOMMENDATION: Option E (Optimistic merge) for favorites, Option A (last-write-wins) for ratings**

**Why:**
- **Favorites:** Users can't "untaste" a drink, so "tasted" should always win
- Merge try timestamps (no data loss)
- **Ratings:** Last rating is most accurate (opinion can change)
- Simple enough to implement reliably
- Matches user mental model

**Implementation:**
```dart
class SyncService {
  Future<void> mergeFavorite(
    FavoriteItem local,
    FavoriteItem remote,
  ) async {
    // Prefer "tasted" status
    final status = (local.status == 'tasted' || remote.status == 'tasted')
        ? 'tasted'
        : 'want_to_try';

    // Merge try timestamps (deduplicate)
    final allTries = {...local.tries, ...remote.tries}.toList()
      ..sort();

    // Use most recent notes
    final notes = local.updatedAt.isAfter(remote.updatedAt)
        ? local.notes
        : remote.notes;

    return FavoriteItem(
      id: local.id,
      status: status,
      tries: allTries,
      notes: notes,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> mergeRating(int local, int remote, DateTime localTime, DateTime remoteTime) async {
    // Last-write-wins for ratings
    return localTime.isAfter(remoteTime) ? local : remote;
  }
}
```

**Edge cases to handle:**
- Duplicate timestamps (within 1 second) → deduplicate
- Missing fields (null notes) → keep non-null value
- Deleted items → tombstone marker with TTL

---

## Documentation Deliverables

Each phase must include:

### Code Documentation

**Every new file:**
- File-level doc comment explaining purpose
- Class-level doc comments
- Public method doc comments (including params, returns, throws)

**Example:**
```dart
/// Service for syncing user data to Firebase Cloud Firestore.
///
/// Handles favorites, ratings, and try history synchronization with
/// automatic conflict resolution and offline queueing.
class SyncService {
  /// Syncs local favorites to the cloud.
  ///
  /// Returns `true` if sync was successful, `false` if offline or error occurred.
  /// Queues changes for retry if network is unavailable.
  ///
  /// Throws [SyncException] if authentication fails.
  Future<bool> syncToCloud() async {
    // Implementation...
  }
}
```

### Phase Documentation

**At the end of each phase, create/update:**

1. **Phase 0-2 (Festival Linking):**
   - `docs/deep-linking.md` - How festival-scoped URLs work
   - Update `README.md` - Add deep linking section
   - Update `CLAUDE.md` - Document navigation helpers

2. **Phase 3-4 (Festival Log):**
   - `docs/festival-log.md` - Data model and user guide
   - Update `docs/api/README.md` - Document FavoriteItem schema
   - Update `CLAUDE.md` - Document new models and services

3. **Phase 5-6 (Cloud Sync):**
   - `docs/cloud-sync.md` - Architecture and setup guide
   - `docs/firebase-setup.md` - Firebase configuration for developers
   - Update `CLAUDE.md` - Document sync service usage

### Testing Documentation

**For each phase:**
- Document test coverage in PR description
- Add testing section to phase docs
- Document manual testing checklist

**Example (in `docs/festival-log.md`):**
```markdown
## Testing

### Automated Tests
- `test/models/favorite_item_test.dart` - FavoriteItem model tests
- `test/services/storage_service_test.dart` - Storage and migration tests
- `test/providers/beer_provider_test.dart` - Provider state tests
- `test/widgets/drink_card_test.dart` - Badge rendering tests

### Manual Testing Checklist
- [ ] Mark drink as "want to try"
- [ ] Mark drink as "tasted" (timestamp added)
- [ ] Mark as tasted again (second timestamp)
- [ ] Delete a timestamp
- [ ] View festival log (correct sort order)
- [ ] Status badges visible on all drink cards
- [ ] Migration from old favorites works
```

---

## Test Requirements by Phase

### Phase 0: Foundation

**Unit tests:**
- `test/utils/navigation_helpers_test.dart`
  - Test URL builders for all routes
  - Test special character encoding
  - Test festival ID extraction

**Widget tests:**
- `test/widgets/breadcrumb_bar_test.dart`
  - Test breadcrumb rendering
  - Test back button callback
  - Test context text display
  - Test text overflow handling
  - **Accessibility:** Test Semantics labels

**Coverage target:** 100% (new code only)

---

### Phase 1: Festival Linking - Foundation

**Unit tests:**
- `test/router_test.dart` (update existing)
  - Test root redirect to current festival
  - Test invalid festival ID handling
  - Test festival ID extraction from all routes

**Widget tests:**
- Update ALL screen tests to pass `festivalId`
- `test/screens/drinks_screen_test.dart`
- `test/screens/drink_detail_screen_test.dart`
- `test/screens/brewery_screen_test.dart`
- `test/screens/style_screen_test.dart`

**Integration tests:**
- `test/integration/navigation_test.dart` (create new)
  - Test deep linking to specific festival
  - Test navigation preserves festival context
  - Test bottom nav with different festivals
  - Test festival switching updates all routes

**Coverage target:** 90%+ for router changes

---

### Phase 2: Festival Linking - Polish

**Widget tests:**
- Update detail screen tests for breadcrumbs
- `test/widgets/breadcrumb_bar_test.dart` (already done in Phase 0)
- `test/screens/category_screen_test.dart` (new screen)

**Integration tests:**
- Test breadcrumb navigation
- Test category filtering

**Coverage target:** 90%+

---

### Phase 3: Festival Log - Data Model

**Unit tests:**
- `test/models/favorite_item_test.dart` (create new)
  - Test model creation
  - Test toJson/fromJson serialization
  - Test all fields (id, status, tries, notes, timestamps)
  - Test edge cases (empty tries list, null notes)

- `test/services/storage_service_test.dart` (update existing)
  - Test new storage format (Map<String, FavoriteItem>)
  - **CRITICAL:** Test migration from old Set<String> format
  - Test multiple migrations (idempotency)
  - Test empty data migration
  - Test corrupted data handling

- `test/providers/beer_provider_test.dart` (update existing)
  - Test markAsTried()
  - Test addToWantToTry()
  - Test deleteTry()
  - Test getFavoriteStatus()
  - Test festival-scoped favorites
  - Test provider notifies listeners

**Coverage target:** 95%+ (critical data code)

---

### Phase 4: Festival Log - UI

**Widget tests:**
- `test/widgets/drink_card_test.dart` (update existing)
  - Test status badge rendering
  - Test "want to try" badge (grey circle)
  - Test "tasted" badge (green checkmark)
  - Test multiple tastings badge (number)
  - **Accessibility:** Test Semantics for badges
  - Test badge visibility toggle

- `test/screens/drink_detail_screen_test.dart` (update existing)
  - Test "Mark as Tasted" button
  - Test try history list rendering
  - Test timestamp formatting
  - Test delete try button
  - Test confirmation dialog
  - **Accessibility:** Test Semantics for all buttons

- `test/screens/favorites_screen_test.dart` (create new or update)
  - Test unified list rendering
  - Test sort order ("to try" first, "tasted" second)
  - Test section divider
  - Test empty states
  - **Accessibility:** Test screen reader navigation

**Coverage target:** 90%+

---

### Phase 5: Cloud Sync - Architecture

**Unit tests:**
- `test/services/auth_service_test.dart` (create new)
  - Test anonymous sign-in
  - Test user ID persistence
  - Test auth state changes
  - Mock Firebase Auth

- `test/services/sync_service_test.dart` (create new)
  - Test syncToCloud() with mock Firestore
  - Test syncFromCloud()
  - Test data serialization to Firestore format
  - Test error handling (network error, auth error)
  - Test offline queueing
  - **CRITICAL:** Test conflict resolution (mergeFavorite)
  - Test merge logic for tries lists
  - Test last-write-wins for ratings

**Widget tests:**
- `test/widgets/sync_status_indicator_test.dart` (create new)
  - Test status states (idle, syncing, success, error)
  - Test status icon changes
  - Test error message display

**Integration tests:**
- `test/integration/sync_test.dart` (create new)
  - Test full sync flow (local → cloud → local)
  - Test conflict resolution end-to-end
  - Test multi-device simulation (mock)
  - Test offline → online sync

**Coverage target:** 85%+ (cloud code is harder to test)

---

### Phase 6: Cloud Sync - Polish

**Widget tests:**
- `test/screens/settings_screen_test.dart` (update or create)
  - Test auto-sync toggle
  - Test "Sync now" button
  - Test last sync timestamp display
  - **Accessibility:** Test all controls

- `test/services/export_service_test.dart` (create new)
  - Test JSON export format
  - Test import validation
  - Test import overwrites correctly

**Integration tests:**
- Test export → import flow
- Test data recovery scenario

**Coverage target:** 90%+

---

## Summary: What You Get

With these decisions and requirements:

✅ **Clear choices** for every major decision (you approve each one)
✅ **Explicit test requirements** (unit + widget tests for every task)
✅ **Documentation deliverables** (code docs + phase guides)
✅ **Multiple-choice format** (understand tradeoffs, not just told what to do)
✅ **Recommendations with rationale** (but you decide)

**Next steps:**
1. Review this document
2. Approve/modify decisions (or ask questions)
3. I'll create detailed task breakdown with tests included
4. Start Phase 0 implementation

Ready to review the decisions?
