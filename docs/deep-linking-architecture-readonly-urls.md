# Deep Linking Architecture Clarification: Read-Only URLs

## Critical Principle

**URLs must be read-only for navigation state. Visiting a URL should NEVER mutate application state.**

This document clarifies the architecture based on this fundamental web principle that was initially conflated in the original design.

---

## The Problem: State Conflation

The original design conflated two separate concepts:

1. **View Festival** (what URL you're looking at right now)
2. **User's Preferred Festival** (their saved default choice)

**These must be separate!**

---

## Correct Architecture

### Two Separate State Concepts

```dart
class BeerProvider extends ChangeNotifier {
  // User's PREFERENCE (persisted, only changed by explicit UI action)
  Festival _userPreferredFestival;

  // Getter for user's preference
  Festival get userPreferredFestival => _userPreferredFestival;

  // REMOVED: Don't store "currentFestival" derived from URL
  // Festival _currentFestival; ❌ DELETE THIS

  // User explicitly switches preferred festival (UI action only)
  Future<void> setUserPreferredFestival(Festival festival) async {
    _userPreferredFestival = festival;
    await _storage.saveFestival(festival);
    notifyListeners();
  }

  // Utility: Get any festival by ID (for URL-based loading)
  Festival? getFestivalById(String festivalId) {
    return _festivals.firstWhere(
      (f) => f.id == festivalId,
      orElse: () => null,
    );
  }

  // Load drinks for ANY festival (URL-based, not just preferred)
  Future<List<Drink>> getDrinksForFestival(Festival festival) async {
    return await _apiService.fetchAllDrinks(festival);
  }
}
```

---

## How It Works: Example Scenarios

### Scenario 1: Deep Link (Read-Only)

```
1. User opens: /cbf2024/drink/123
2. DrinkDetailScreen reads festivalId from URL: "cbf2024"
3. Screen loads drink from CBF 2024
4. Provider's userPreferredFestival STAYS cbf2025 (unchanged!)
5. User clicks "Drinks" in bottom nav → goes to /cbf2025 (their preference)
```

**Key:** Viewing `/cbf2024/drink/123` does NOT change the user's preferred festival.

---

### Scenario 2: Explicit Festival Switching (Write)

```
1. User is at /cbf2025
2. User opens festival selector UI → picks CBF 2024
3. Provider.setUserPreferredFestival(cbf2024) is called
4. Navigate to /cbf2024
5. Now "/" redirects to /cbf2024
6. Bottom nav uses cbf2024
```

**Key:** Only explicit UI action changes preferred festival.

---

### Scenario 3: Browser Back Button

```
1. User at /cbf2025
2. Opens /cbf2024/drink/123 (via link)
3. Clicks browser back
4. Returns to /cbf2025
5. Provider's userPreferredFestival was always cbf2025 (unchanged)
```

**Key:** Browser history works correctly because URL doesn't mutate state.

---

## Screen Implementation Pattern

### Old Pattern (Wrong)

```dart
class DrinkDetailScreen extends StatefulWidget {
  final String drinkId;  // ❌ Missing festivalId

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // ❌ WRONG: Uses provider's currentFestival (what does this even mean?)
    final drink = provider.getDrinkById(drinkId);
  }
}
```

### New Pattern (Correct)

```dart
class DrinkDetailScreen extends StatefulWidget {
  final String festivalId;  // ✅ From URL
  final String drinkId;

  const DrinkDetailScreen({
    super.key,
    required this.festivalId,  // ✅ URL parameter
    required this.drinkId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // ✅ Load THIS festival's data (from URL)
    final festival = provider.getFestivalById(widget.festivalId);
    if (festival == null) {
      // Invalid festival - show error or redirect
      return FestivalNotFoundScreen();
    }

    final drinks = await provider.getDrinksForFestival(festival);
    final drink = drinks.firstWhere((d) => d.id == widget.drinkId);

    // User's preferred festival is separate (for navigation)
    final preferredFestival = provider.userPreferredFestival;
  }
}
```

---

## Navigation Logic

### Bottom Navigation (App Home)

**Bottom nav always uses user's preferred festival, NOT URL festival.**

```dart
// Bottom nav "Drinks" button
void onDrinksPressed(BuildContext context) {
  final provider = context.read<BeerProvider>();

  // ✅ Go to user's PREFERRED festival (app home)
  context.go('/${provider.userPreferredFestival.id}');
}

// Bottom nav "Favorites" button
void onFavoritesPressed(BuildContext context) {
  final provider = context.read<BeerProvider>();

  // ✅ Go to user's PREFERRED festival favorites
  context.go('/${provider.userPreferredFestival.id}/favorites');
}
```

**Why:** Bottom nav is "app home navigation" - it should go to MY festival, not whatever festival I'm currently viewing via a shared link.

---

### Breadcrumbs (URL Context)

**Breadcrumbs navigate within the URL's festival context.**

```dart
// Breadcrumb "Festival" link
void onFestivalBreadcrumbPressed(BuildContext context, String urlFestivalId) {
  // ✅ Stay in URL's festival context
  context.go('/$urlFestivalId');
}

// Breadcrumb "Producer" link
void onProducerBreadcrumbPressed(
  BuildContext context,
  String urlFestivalId,
  String producerId,
) {
  // ✅ Navigate within URL's festival
  context.go('/$urlFestivalId/producer/$producerId');
}
```

**Why:** Breadcrumbs show WHERE you are, not WHERE you want to go home to.

---

### Drink Card Navigation

**Drink cards navigate within current screen's festival context.**

```dart
class DrinksScreen extends StatefulWidget {
  final String festivalId;  // From URL

  @override
  Widget build(BuildContext context) {
    return DrinkCard(
      drink: drink,
      onTap: () {
        // ✅ Navigate within THIS festival
        context.go(buildDrinkUrl(widget.festivalId, drink.id));
      },
    );
  }
}
```

---

## Router Configuration

### Root Redirect

```dart
GoRoute(
  path: '/',
  redirect: (context, state) {
    final provider = context.read<BeerProvider>();

    // ✅ Redirect to user's PREFERRED festival
    return '/${provider.userPreferredFestival.id}';
  },
)
```

---

### Festival Validation

```dart
// Guard for invalid festival IDs
String? _validateFestival(BuildContext context, GoRouterState state) {
  final festivalId = state.pathParameters['festivalId'];
  if (festivalId == null) return null;

  final provider = context.read<BeerProvider>();
  final festival = provider.getFestivalById(festivalId);

  if (festival == null) {
    // Invalid festival - redirect to preferred festival
    // Try to preserve the resource path
    final pathSegments = state.uri.pathSegments;
    if (pathSegments.length > 1) {
      // e.g., /invalid/drink/123 → /cbf2025/drink/123
      final resourcePath = pathSegments.sublist(1).join('/');
      return '/${provider.userPreferredFestival.id}/$resourcePath';
    }

    // Just festival - redirect to preferred
    return '/${provider.userPreferredFestival.id}';
  }

  return null; // Valid festival
}
```

---

## Data Loading Strategy

### Per-Festival Caching

Since users might navigate between festivals via deep links, cache multiple festivals' data:

```dart
class BeerProvider extends ChangeNotifier {
  // Cache data per festival
  final Map<String, List<Drink>> _drinksByFestival = {};

  Future<List<Drink>> getDrinksForFestival(Festival festival) async {
    // Return cached if available
    if (_drinksByFestival.containsKey(festival.id)) {
      return _drinksByFestival[festival.id]!;
    }

    // Load and cache
    final drinks = await _apiService.fetchAllDrinks(festival);
    _drinksByFestival[festival.id] = drinks;
    return drinks;
  }

  // Clear cache when memory constrained
  void clearFestivalCache(String festivalId) {
    _drinksByFestival.remove(festivalId);
  }
}
```

---

## UI Considerations

### 1. Festival Indicator

Show which festival user is viewing (especially if different from preferred):

```dart
Widget buildFestivalIndicator(BuildContext context) {
  final urlFestivalId = widget.festivalId;
  final provider = context.watch<BeerProvider>();
  final preferredFestivalId = provider.userPreferredFestival.id;

  if (urlFestivalId != preferredFestivalId) {
    // Viewing different festival than preferred
    return Container(
      color: Colors.amber.shade100,
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 8),
          Text('Viewing: ${festival.name}'),
          Spacer(),
          TextButton(
            onPressed: () {
              // Switch preferred festival
              provider.setUserPreferredFestival(festival);
            },
            child: Text('Make Default'),
          ),
        ],
      ),
    );
  }

  return SizedBox.shrink();
}
```

---

### 2. Festival Selector

Explicit UI for switching preferred festival:

```dart
void showFestivalSelector(BuildContext context) {
  final provider = context.read<BeerProvider>();

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return ListView(
        children: provider.festivals.map((festival) {
          final isPreferred = festival.id == provider.userPreferredFestival.id;

          return ListTile(
            title: Text(festival.name),
            subtitle: Text(festival.formattedDates),
            trailing: isPreferred ? Icon(Icons.check) : null,
            onTap: () {
              // Update preference
              provider.setUserPreferredFestival(festival);

              // Navigate to new festival
              context.go('/${festival.id}');

              Navigator.pop(context);
            },
          );
        }).toList(),
      );
    },
  );
}
```

---

## Open Questions to Resolve

### Q1: Bottom Nav Behavior

User is viewing `/cbf2024/drink/123` (CBF 2024 via deep link), clicks "Favorites":

**Option A: Go to preferred festival favorites**
```dart
context.go('/${provider.userPreferredFestival.id}/favorites');
// → /cbf2025/favorites
```

**Option B: Stay in URL festival**
```dart
context.go('/${widget.festivalId}/favorites');
// → /cbf2024/favorites
```

**Recommendation:** Option A
- Bottom nav is "app home navigation"
- Favorites = MY favorites = MY festival
- More intuitive

**Decision needed:** A or B?

---

### Q2: Festival Indicator UI

Should we show which festival is being viewed?

**Option A: Always show festival prominently**
```
[Cambridge Beer Festival 2025 ▼]  [Info] [About]
```

**Option B: Only show indicator if URL festival ≠ preferred**
```
⚠️ Viewing CBF 2024 (Your festival: CBF 2025) [Switch]
```

**Option C: No explicit indicator**

**Recommendation:** Option B
- Shows context when needed
- Doesn't clutter when viewing preferred festival
- Provides action ("Switch") to make it preferred

**Decision needed:** A, B, or C?

---

### Q3: Multiple Festival Data Caching

Should we cache multiple festivals' data?

**Option A: Cache all viewed festivals** (Recommended)
```dart
Map<String, List<Drink>> _drinksByFestival;
```
- Allows fast switching between festivals
- Reasonable memory usage (2-3 festivals max)

**Option B: Only cache preferred festival**
```dart
List<Drink> _preferredFestivalDrinks;
```
- Lower memory
- Slower for deep links to other festivals

**Option C: No caching, always reload**
- Simplest
- Slowest

**Recommendation:** Option A (cache multiple)

**Decision needed:** A, B, or C?

---

## Festival Log: Personal Festival Tracker

### Overview

The **Festival Log** (user-facing: "My Festival") serves as a personal festival tracker with two states:

1. **"To Try"** - Drinks the user plans to sample
2. **"Tasted"** - Drinks the user has sampled, with timestamps

**Key feature:** Users can mark a drink as tasted **multiple times** (e.g., trying a favorite on different days).

### Naming Convention

- **Code/Internal**: `FestivalLog`, `FavoriteItem` (legacy), `_favoritesByFestival`
- **User-facing UI**:
  - Navigation tab: "My Festival"
  - Screen title: "My {Festival Name}" (e.g., "My CBF 2025")
  - Sections: "To Try" / "Tasted"
  - URL: `/{festivalId}/log` or `/{festivalId}/my-festival`

---

### Data Model

```dart
class FavoriteItem {
  final String drinkId;
  final List<DateTime> triedDates;  // Empty = "want to try", 1+ = "tried"

  FavoriteItem({
    required this.drinkId,
    this.triedDates = const [],
  });

  // Convenience getters
  bool get isWantToTry => triedDates.isEmpty;
  bool get hasTried => triedDates.isNotEmpty;
  int get tryCount => triedDates.length;

  // Serialization
  Map<String, dynamic> toJson() => {
    'drinkId': drinkId,
    'triedDates': triedDates.map((d) => d.toIso8601String()).toList(),
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    drinkId: json['drinkId'],
    triedDates: (json['triedDates'] as List<dynamic>?)
        ?.map((d) => DateTime.parse(d as String))
        .toList() ?? [],
  );
}
```

---

### Storage Structure

```dart
// Map: festivalId → Map: drinkId → FavoriteItem
Map<String, Map<String, FavoriteItem>> _favoritesByFestival = {
  'cbf2025': {
    'drink123': FavoriteItem(
      drinkId: 'drink123',
      triedDates: [], // Want to try
    ),
    'drink456': FavoriteItem(
      drinkId: 'drink456',
      triedDates: [
        DateTime(2025, 5, 20, 14, 30),  // Tried on day 1
        DateTime(2025, 5, 21, 16, 45),  // Tried again on day 2
      ],
    ),
  },
  'cbf2024': { ... },
};
```

**Why Map<String, Map<...>>?**
- Outer map: Festival-scoped isolation
- Inner map: Fast lookup by drinkId
- Allows multiple festivals' favorites to coexist

---

### Provider API

```dart
class BeerProvider extends ChangeNotifier {
  Map<String, Map<String, FavoriteItem>> _favoritesByFestival = {};

  // ========================================
  // Favorites Getters
  // ========================================

  /// Get all favorites for a festival
  Map<String, FavoriteItem> getFavoritesForFestival(String festivalId) {
    return _favoritesByFestival[festivalId] ?? {};
  }

  /// Check if drink is favorited (want to try OR tried)
  bool isFavorite(String festivalId, String drinkId) {
    return _favoritesByFestival[festivalId]?.containsKey(drinkId) ?? false;
  }

  /// Get specific favorite item
  FavoriteItem? getFavorite(String festivalId, String drinkId) {
    return _favoritesByFestival[festivalId]?[drinkId];
  }

  // ========================================
  // Favorites Actions
  // ========================================

  /// Add to "want to try" list
  void addToWantToTry(String festivalId, String drinkId) {
    _favoritesByFestival.putIfAbsent(festivalId, () => {});
    _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(drinkId: drinkId);
    notifyListeners();
    _saveFavorites();
  }

  /// Mark as tried (adds a new timestamp)
  ///
  /// If [customDate] is provided, uses that instead of DateTime.now().
  /// This allows users to "go back in time" for historical entries.
  void markAsTried(String festivalId, String drinkId, {DateTime? customDate}) {
    final date = customDate ?? DateTime.now();
    _favoritesByFestival.putIfAbsent(festivalId, () => {});

    final existing = _favoritesByFestival[festivalId]![drinkId];
    if (existing != null) {
      // Add new tried date to existing favorite
      final updatedDates = [...existing.triedDates, date]..sort();
      _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(
        drinkId: drinkId,
        triedDates: updatedDates,
      );
    } else {
      // New favorite, mark as tried immediately
      _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(
        drinkId: drinkId,
        triedDates: [date],
      );
    }

    notifyListeners();
    _saveFavorites();
  }

  /// Update a specific tried date (allows editing timestamps)
  void updateTriedDate(
    String festivalId,
    String drinkId,
    DateTime oldDate,
    DateTime newDate,
  ) {
    final existing = _favoritesByFestival[festivalId]?[drinkId];
    if (existing != null) {
      final updatedDates = existing.triedDates
          .map((d) => d == oldDate ? newDate : d)
          .toList()
        ..sort();

      _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(
        drinkId: drinkId,
        triedDates: updatedDates,
      );

      notifyListeners();
      _saveFavorites();
    }
  }

  /// Remove a specific tried date
  void removeTriedDate(String festivalId, String drinkId, DateTime date) {
    final existing = _favoritesByFestival[festivalId]?[drinkId];
    if (existing != null) {
      final updatedDates = existing.triedDates
          .where((d) => d != date)
          .toList();

      if (updatedDates.isEmpty) {
        // No more tries - revert to "want to try"
        _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(
          drinkId: drinkId,
          triedDates: [],
        );
      } else {
        _favoritesByFestival[festivalId]![drinkId] = FavoriteItem(
          drinkId: drinkId,
          triedDates: updatedDates,
        );
      }

      notifyListeners();
      _saveFavorites();
    }
  }

  /// Remove from favorites entirely
  void removeFavorite(String festivalId, String drinkId) {
    _favoritesByFestival[festivalId]?.remove(drinkId);
    if (_favoritesByFestival[festivalId]?.isEmpty ?? false) {
      _favoritesByFestival.remove(festivalId);
    }
    notifyListeners();
    _saveFavorites();
  }

  /// Toggle favorite (smart toggle based on current state)
  void toggleFavorite(String festivalId, String drinkId) {
    if (isFavorite(festivalId, drinkId)) {
      removeFavorite(festivalId, drinkId);
    } else {
      addToWantToTry(festivalId, drinkId);
    }
  }

  // ========================================
  // Festival Summary
  // ========================================

  /// Generate a summary of user's festival experience
  ///
  /// Returns statistics and list of tried drinks with dates.
  /// Useful for end-of-festival recap.
  Map<String, dynamic> generateFestivalSummary(String festivalId) {
    final favorites = getFavoritesForFestival(festivalId);
    final wantToTry = favorites.values.where((f) => f.isWantToTry).toList();
    final tried = favorites.values.where((f) => f.hasTried).toList();

    return {
      'festivalId': festivalId,
      'totalFavorites': favorites.length,
      'wantToTryCount': wantToTry.length,
      'triedCount': tried.length,
      'totalTries': tried.fold<int>(0, (sum, f) => sum + f.tryCount),
      'triedDrinks': tried.map((f) => {
        'drinkId': f.drinkId,
        'dates': f.triedDates,
        'tryCount': f.tryCount,
        'firstTried': f.triedDates.first,
        'lastTried': f.triedDates.last,
      }).toList(),
      'wantToTryDrinks': wantToTry.map((f) => f.drinkId).toList(),
    };
  }

  // ========================================
  // Persistence
  // ========================================

  Future<void> _saveFavorites() async {
    final json = _favoritesByFestival.map(
      (festivalId, favorites) => MapEntry(
        festivalId,
        favorites.map(
          (drinkId, item) => MapEntry(drinkId, item.toJson()),
        ),
      ),
    );

    await _storage.saveFavorites(json);
  }

  Future<void> _loadFavorites() async {
    final json = await _storage.loadFavorites();
    if (json != null) {
      _favoritesByFestival = json.map(
        (festivalId, favorites) => MapEntry(
          festivalId,
          (favorites as Map<String, dynamic>).map(
            (drinkId, itemJson) => MapEntry(
              drinkId,
              FavoriteItem.fromJson(itemJson),
            ),
          ),
        ),
      );
    }
  }
}
```

---

### UI Interaction Flow

#### 1. Drink Detail Screen - Favorite Button

```dart
class DrinkDetailScreen extends StatelessWidget {
  final String festivalId;
  final String drinkId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final favorite = provider.getFavorite(festivalId, drinkId);

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Simple toggle for want-to-try
          IconButton(
            icon: Icon(
              favorite != null ? Icons.favorite : Icons.favorite_border,
            ),
            onPressed: () {
              provider.toggleFavorite(festivalId, drinkId);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ... drink details ...

          // Mark as tried button
          if (favorite != null)
            ElevatedButton.icon(
              icon: Icon(Icons.check_circle),
              label: Text('Mark as Tried'),
              onPressed: () {
                provider.markAsTried(festivalId, drinkId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Marked as tried!')),
                );
              },
            ),

          // Show tried dates
          if (favorite?.hasTried ?? false)
            Column(
              children: [
                Text('Tried ${favorite!.tryCount} time(s):'),
                ...favorite.triedDates.map((date) => ListTile(
                  title: Text(DateFormat.yMMMd().add_jm().format(date)),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _editDate(context, date),
                  ),
                )),
              ],
            ),
        ],
      ),
    );
  }

  void _editDate(BuildContext context, DateTime currentDate) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (newDate != null) {
      final newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDate),
      );

      if (newTime != null) {
        final updatedDate = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          newTime.hour,
          newTime.minute,
        );

        context.read<BeerProvider>().updateTriedDate(
          widget.festivalId,
          widget.drinkId,
          currentDate,
          updatedDate,
        );
      }
    }
  }
}
```

---

#### 2. Festival Log Screen - "My Festival" View

```dart
class FestivalLogScreen extends StatelessWidget {
  final String festivalId;

  const FestivalLogScreen({super.key, required this.festivalId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final log = provider.getFavoritesForFestival(festivalId);
    final festival = provider.festivals.firstWhere((f) => f.id == festivalId);

    final toTry = log.values.where((f) => f.isWantToTry).toList();
    final tasted = log.values.where((f) => f.hasTried).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('My ${festival.name}'),  // e.g., "My CBF 2025"
      ),
      body: log.isEmpty
          ? Center(child: Text('Your festival log is empty. Start adding drinks!'))
          : ListView(
              children: [
                // To Try section
                _SectionHeader(
                  title: 'To Try',
                  count: toTry.length,
                ),
                ...toTry.map((item) => _LogCard(
                  festivalId: festivalId,
                  drinkId: item.drinkId,
                  status: 'to-try',
                )),

                SizedBox(height: 24),

                // Tasted section
                _SectionHeader(
                  title: 'Tasted',
                  count: tasted.length,
                ),
                ...tasted.map((item) => _LogCard(
                  festivalId: festivalId,
                  drinkId: item.drinkId,
                  status: 'tasted',
                  tryCount: item.tryCount,
                  lastTasted: item.triedDates.last,
                )),

                SizedBox(height: 24),

                // Summary button
                if (log.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.summarize),
                      label: Text('Festival Summary'),
                      onPressed: () => _showSummary(context, festivalId),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showSummary(BuildContext context, String festivalId) {
    final provider = context.read<BeerProvider>();
    final summary = provider.generateFestivalSummary(festivalId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Festival Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total favorites: ${summary['totalFavorites']}'),
              Text('Tried: ${summary['triedCount']} drinks'),
              Text('Total tries: ${summary['totalTries']}'),
              Text('Still want to try: ${summary['wantToTryCount']}'),
              SizedBox(height: 16),
              Text('Tried drinks:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(summary['triedDrinks'] as List).map((drink) => Text(
                '• ${drink['drinkId']} (${drink['tryCount']}x)',
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Export summary as text/JSON
            },
            child: Text('Export'),
          ),
        ],
      ),
    );
  }
}
```

---

### Storage Format (SharedPreferences)

```json
{
  "favorites": {
    "cbf2025": {
      "drink123": {
        "drinkId": "drink123",
        "triedDates": []
      },
      "drink456": {
        "drinkId": "drink456",
        "triedDates": [
          "2025-05-20T14:30:00.000Z",
          "2025-05-21T16:45:00.000Z"
        ]
      }
    },
    "cbf2024": {
      "drink789": {
        "drinkId": "drink789",
        "triedDates": ["2024-05-22T15:00:00.000Z"]
      }
    }
  }
}
```

---

### Benefits of This Design

1. **Festival-scoped** - Favorites don't mix across festivals
2. **Historical tracking** - Keep records of past festivals
3. **Multiple tries** - Realistic for festival-goers who revisit favorites
4. **Flexible timestamps** - Users can correct dates if needed
5. **Summary generation** - Create end-of-festival recaps
6. **Simple data model** - List of dates is easy to understand and serialize
7. **Backward compatible** - Can migrate old boolean favorites to empty `triedDates`

---

### Migration from Current Favorites

Current favorites are stored as `Set<String>` (drink IDs only).

**Migration strategy:**

```dart
Future<void> _migrateFavorites() async {
  // Load old favorites (Set<String>)
  final oldFavorites = await _storage.loadOldFavorites();

  if (oldFavorites != null && oldFavorites.isNotEmpty) {
    // Get current festival
    final festivalId = _userPreferredFestival.id;

    // Convert to new format (as "want to try")
    _favoritesByFestival[festivalId] = {
      for (var drinkId in oldFavorites)
        drinkId: FavoriteItem(drinkId: drinkId),
    };

    // Save in new format
    await _saveFavorites();

    // Delete old storage
    await _storage.deleteOldFavorites();
  }
}
```

**Impact:** All existing favorites become "want to try" items for the current festival.

---

### Cloud Sync (Future Enhancement)

**Goal:** Sync user data across devices using cloud storage (Firebase, etc.)

**Data to sync:**
- ✅ **Favorites/To-Do List** - Want-to-try and tried drinks with timestamps
- ✅ **Ratings** - User ratings for drinks (1-5 stars)
- 🔜 **Tasting Notes** - User's personal notes about drinks
- 🔜 **Preferred Festival** - User's last-selected festival
- 🔜 **Filter Preferences** - Last-used filters and search queries

#### Data Model Considerations

The data model is designed to be cloud-friendly with support for all user data:

```json
{
  "users": {
    "user123": {
      "preferredFestival": "cbf2025",
      "favorites": {
        "cbf2025": {
          "drink456": {
            "drinkId": "drink456",
            "triedDates": [
              "2025-05-20T14:30:00.000Z",
              "2025-05-21T16:45:00.000Z"
            ]
          }
        }
      },
      "ratings": {
        "cbf2025": {
          "drink456": {
            "drinkId": "drink456",
            "rating": 5,
            "updatedAt": "2025-05-20T14:35:00.000Z"
          }
        }
      },
      "tastingNotes": {
        "cbf2025": {
          "drink456": {
            "drinkId": "drink456",
            "note": "Hoppy with citrus notes, very refreshing!",
            "createdAt": "2025-05-20T14:35:00.000Z",
            "updatedAt": "2025-05-20T16:22:00.000Z"
          }
        }
      }
    }
  }
}
```

**Benefits:**
- ✅ ISO 8601 timestamps (universally parseable)
- ✅ Flat structure (easy to sync)
- ✅ Festival-scoped (no cross-user contamination)
- ✅ Versioned data (timestamps for conflict resolution)
- ✅ Extensible (easy to add new fields)

---

#### Sync Strategy

**Option A: Firestore** (Recommended)
```dart
class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sync favorites to cloud
  Future<void> syncFavorites(String userId, Map<String, Map<String, FavoriteItem>> favorites) async {
    final json = favorites.map(
      (festivalId, items) => MapEntry(
        festivalId,
        items.map((id, item) => MapEntry(id, item.toJson())),
      ),
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc('data')
        .set({'festivals': json}, SetOptions(merge: true));
  }

  // Load favorites from cloud
  Future<Map<String, Map<String, FavoriteItem>>?> loadFavorites(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc('data')
        .get();

    if (!doc.exists) return null;

    final data = doc.data()?['festivals'] as Map<String, dynamic>?;
    if (data == null) return null;

    return data.map(
      (festivalId, items) => MapEntry(
        festivalId,
        (items as Map<String, dynamic>).map(
          (id, itemJson) => MapEntry(id, FavoriteItem.fromJson(itemJson)),
        ),
      ),
    );
  }

  // Real-time sync listener
  Stream<Map<String, Map<String, FavoriteItem>>> watchFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc('data')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data()?['festivals'] as Map<String, dynamic>?;
          if (data == null) return {};

          return data.map(
            (festivalId, items) => MapEntry(
              festivalId,
              (items as Map<String, dynamic>).map(
                (id, itemJson) => MapEntry(id, FavoriteItem.fromJson(itemJson)),
              ),
            ),
          );
        });
  }
}
```

---

#### Conflict Resolution

**Scenario:** User tries drink on Phone A, also tries on Phone B (offline), both sync.

**Strategy: Last-Write-Wins with Array Merging**

```dart
// Merge strategy for tried dates
List<DateTime> mergeTriedDates(List<DateTime> local, List<DateTime> remote) {
  final combined = {...local, ...remote}.toList()..sort();
  return combined;
}

// Example conflict resolution
FavoriteItem resolveConflict(FavoriteItem local, FavoriteItem remote) {
  // Merge all tried dates from both devices
  final mergedDates = mergeTriedDates(local.triedDates, remote.triedDates);

  return FavoriteItem(
    drinkId: local.drinkId,
    triedDates: mergedDates,
  );
}
```

**Why this works:**
- Tried dates are append-only (no deletions in normal use)
- Timestamps are unique enough to avoid duplicates
- Set union prevents double-counting
- User sees combined history from all devices

---

#### Provider Integration

```dart
class BeerProvider extends ChangeNotifier {
  final CloudSyncService _cloudSync;
  StreamSubscription<Map<String, Map<String, FavoriteItem>>>? _syncSubscription;

  // Enable cloud sync
  Future<void> enableCloudSync(String userId) async {
    // Initial upload
    await _cloudSync.syncFavorites(userId, _favoritesByFestival);

    // Watch for remote changes
    _syncSubscription = _cloudSync.watchFavorites(userId).listen((remoteFavorites) {
      // Merge with local favorites
      for (final festivalId in remoteFavorites.keys) {
        final remoteItems = remoteFavorites[festivalId]!;
        final localItems = _favoritesByFestival[festivalId] ?? {};

        for (final drinkId in remoteItems.keys) {
          final remote = remoteItems[drinkId]!;
          final local = localItems[drinkId];

          if (local == null) {
            // New item from remote
            _favoritesByFestival.putIfAbsent(festivalId, () => {});
            _favoritesByFestival[festivalId]![drinkId] = remote;
          } else {
            // Merge tried dates
            final merged = resolveConflict(local, remote);
            _favoritesByFestival[festivalId]![drinkId] = merged;
          }
        }
      }

      notifyListeners();
    });
  }

  // Disable cloud sync
  void disableCloudSync() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  // Modified save method (writes to both local + cloud)
  Future<void> _saveFavorites() async {
    final json = _favoritesByFestival.map(
      (festivalId, favorites) => MapEntry(
        festivalId,
        favorites.map((drinkId, item) => MapEntry(drinkId, item.toJson())),
      ),
    );

    // Save locally (immediate)
    await _storage.saveFavorites(json);

    // Sync to cloud (if enabled)
    final userId = _authService.currentUserId;
    if (userId != null) {
      await _cloudSync.syncFavorites(userId, _favoritesByFestival);
    }
  }
}
```

---

#### Implementation Phases

**Phase 1: Local-only** (Current)
- ✅ All favorites stored in SharedPreferences
- ✅ Works offline
- ❌ No cross-device sync

**Phase 2: Cloud Backup** (Future)
- ✅ One-time upload to cloud on app open
- ✅ One-time download from cloud on new device
- ❌ No real-time sync

**Phase 3: Real-time Sync** (Future)
- ✅ Live sync across devices
- ✅ Conflict resolution
- ✅ Offline-first with background sync

---

#### Authentication Requirement

Cloud sync requires user authentication:

**Options:**
- **Firebase Anonymous Auth** - Auto-generated user IDs (simple, limited)
- **Firebase Email/Google Auth** - Full user accounts (recommended)

**Migration path:**
1. Start with anonymous auth (easy onboarding)
2. Offer email/Google upgrade (preserve data)
3. Link anonymous → authenticated account

---

#### Storage Costs

**Firestore pricing (pay-as-you-go):**
- Stored data: $0.18/GB/month
- Document writes: $0.18 per 100K writes
- Document reads: $0.06 per 100K reads

**Estimate for 10,000 users:**
- Average favorites per user: ~20 drinks
- Storage: ~1KB per user × 10,000 = 10MB = **$0.002/month**
- Writes: 5 per user per festival = 50K writes = **$0.09/festival**

**Conclusion:** Very affordable, even at scale.

---

#### Implementation Checklist

When adding cloud sync:

- [ ] Add Firebase SDK to `pubspec.yaml`
- [ ] Create `CloudSyncService` class
- [ ] Add authentication flow (Firebase Auth)
- [ ] Implement conflict resolution strategy
- [ ] Add sync indicator UI (syncing/synced/offline)
- [ ] Handle offline mode gracefully
- [ ] Add "Delete account" functionality (GDPR)
- [ ] Test with multiple devices simultaneously
- [ ] Add sync settings (enable/disable)
- [ ] Document privacy policy (data stored in cloud)

---

## Summary of Changes Needed

### Provider Changes

1. ❌ **Remove:** `Festival _currentFestival;`
2. ✅ **Keep:** `Festival _userPreferredFestival;`
3. ✅ **Add:** `Festival? getFestivalById(String id)`
4. ✅ **Add:** `Future<List<Drink>> getDrinksForFestival(Festival)`
5. ✅ **Add:** Multi-festival caching (if Q3 = A)
6. ✅ **Add:** `Map<String, Map<String, FavoriteItem>> _favoritesByFestival`
7. ✅ **Add:** Favorites API methods (addToWantToTry, markAsTried, etc.)
8. ✅ **Add:** `generateFestivalSummary(String festivalId)`

### Screen Changes

1. ✅ **All screens:** Add `final String festivalId;` parameter (from URL)
2. ✅ **All screens:** Load data using `widget.festivalId`, not provider's preferred
3. ✅ **Bottom nav:** Use `provider.userPreferredFestival.id` for navigation
4. ✅ **Breadcrumbs:** Use `widget.festivalId` for navigation
5. ✅ **Add:** Festival indicator UI (if Q2 = A or B)

### Router Changes

1. ✅ **Root redirect:** Use `provider.userPreferredFestival.id`
2. ✅ **Add:** Festival validation/redirect for invalid IDs
3. ✅ **All routes:** Pass `festivalId` parameter to screens

---

## Benefits of This Architecture

1. **Web Standards Compliance** - URLs are read-only, stateless
2. **Browser History Works** - Back/forward buttons behave correctly
3. **Deep Links Isolated** - Viewing a shared link doesn't mess up your app state
4. **Clear Separation** - View state (URL) vs. user preference (provider)
5. **Testable** - Easier to test URL-based behavior
6. **Predictable** - User knows what will happen when clicking navigation

---

## Migration from Original Design

### What Changes

1. **Provider API**
   - Remove `currentFestival` concept
   - Add `userPreferredFestival` explicitly
   - Add `getFestivalById()` helper

2. **Screen Constructors**
   - All screens get `festivalId` parameter
   - Load data based on URL festival, not provider

3. **Navigation Logic**
   - Bottom nav → preferred festival
   - Breadcrumbs → URL festival
   - Drink cards → current screen's festival

### What Stays the Same

- ✅ URL structure (`/{festivalId}/drink/{id}`)
- ✅ Breadcrumb UI (still clickable)
- ✅ Festival-scoped data loading
- ✅ Testing strategy

---

## Next Steps

1. **Answer Q1-Q3** (bottom nav behavior, festival indicator, caching)
2. **Update implementation plan** with this architecture
3. **Update provider design** in Phase 3
4. **Update screen patterns** in Phase 4
5. **Add festival selector UI** (new phase)
6. **Test with multiple festivals** (E2E tests)

---

## Recommendation

This read-only URL architecture is **correct and necessary**. It aligns with web standards and prevents confusing state mutations.

**Impact:** Medium - requires updates to provider and all screens, but design is clearer and more robust.

**Timeline:** Adds ~2 hours to implementation (updated provider API + screen changes).

**Confidence:** High - this is the right architectural approach.
