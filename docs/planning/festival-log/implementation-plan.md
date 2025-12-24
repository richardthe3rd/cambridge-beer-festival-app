# Festival Log Implementation Plan

**Status**: 💡 Proposal (not yet implemented)

**Context**: 🚀 Pre-release - No migration needed, no backward compatibility required

## Overview

This document provides a detailed, step-by-step implementation plan for the Festival Log ("My Festival") tasting tracker.

**Pre-release advantage:** Since there are no existing users with saved data, we can implement the optimal data structure from day 1 without migration code or backward compatibility concerns. This significantly simplifies the implementation.

## Prerequisites

**Must complete first:**
- ✅ Phase 0-2: Festival Linking (deep linking must be implemented)
  - Reason: Festival Log is festival-scoped and depends on festival-scoped URLs and navigation

**Dependencies:**
- `lib/providers/beer_provider.dart` - Will be extended with new methods
- `lib/services/storage_service.dart` - Will be updated for new data format
- `lib/widgets/drink_card.dart` - Will add status badges
- `lib/screens/drink_detail_screen.dart` - Will add try tracking UI

## Implementation Phases

### Phase 3: Data Model & Storage (4-6 hours)

**Goal:** Implement the new favorites data structure (no migration needed - pre-release).

---

#### Task 3.1: Create FavoriteItem Model

**File:** `lib/models/favorite_item.dart` (NEW)

**Implementation:**

```dart
/// Represents a drink in the user's festival log.
///
/// Tracks whether a drink is on the "want to try" list or has been tasted,
/// along with timestamps of tastings and optional notes.
class FavoriteItem {
  /// Creates a favorite item.
  const FavoriteItem({
    required this.id,
    required this.status,
    required this.tries,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Drink ID.
  final String id;

  /// Status: 'want_to_try' or 'tasted'.
  final String status;

  /// List of tasting timestamps (empty if want_to_try).
  final List<DateTime> tries;

  /// Optional user notes.
  final String? notes;

  /// When this item was added to the log.
  final DateTime createdAt;

  /// When this item was last updated.
  final DateTime updatedAt;

  /// Creates a FavoriteItem from JSON.
  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'want_to_try',
      tries: (json['tries'] as List?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this item to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'tries': tries.map((t) => t.toIso8601String()).toList(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields.
  FavoriteItem copyWith({
    String? id,
    String? status,
    List<DateTime>? tries,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      status: status ?? this.status,
      tries: tries ?? this.tries,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

**Export:** Add to `lib/models/models.dart`:
```dart
export 'favorite_item.dart';
```

**Tests:** `test/models/favorite_item_test.dart`

---

#### Task 3.2: Update StorageService

**File:** `lib/services/storage_service.dart` (UPDATE)

**Pre-release simplification:** No migration code needed! Just implement the new format directly.

**Changes:**

1. **Add storage key:**
```dart
static const String _favoritesKey = 'favorites'; // Clean, simple key
```

2. **Implement load/save methods:**
```dart
/// Loads favorites for a festival.
Future<Map<String, FavoriteItem>> loadFavorites(String festivalId) async {
  final data = await _prefs.getString('${festivalId}_$_favoritesKey');
  if (data == null || data.isEmpty) {
    return {}; // Empty map for new users
  }

  try {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return json.map(
      (key, value) => MapEntry(
        key,
        FavoriteItem.fromJson(value as Map<String, dynamic>),
      ),
    );
  } catch (e) {
    debugPrint('Error loading favorites: $e');
    return {}; // Return empty on error (corrupted data)
  }
}

/// Saves favorites for a festival.
Future<void> saveFavorites(
  String festivalId,
  Map<String, FavoriteItem> favorites,
) async {
  final json = favorites.map((key, value) => MapEntry(key, value.toJson()));
  await _prefs.setString(
    '${festivalId}_$_favoritesKey',
    jsonEncode(json),
  );
}
```

**Tests:** `test/services/storage_service_test.dart` (UPDATE)
- Test load with no data (returns empty map)
- Test load with valid data
- Test load with corrupted data (returns empty map)
- Test save and load roundtrip
- Test festival-scoped storage (different festivals, different data)

---

#### Task 3.3: Update BeerProvider

**File:** `lib/providers/beer_provider.dart` (UPDATE)

**Changes:**

1. **Update favorites field:**
```dart
// OLD:
Set<String> _favorites = {};

// NEW:
Map<String, FavoriteItem> _favorites = {};
```

2. **Add new getters:**
```dart
/// Get favorite status for a drink.
String? getFavoriteStatus(Drink drink) {
  return _favorites[drink.id]?.status;
}

/// Check if drink is in festival log.
bool isInFestivalLog(Drink drink) {
  return _favorites.containsKey(drink.id);
}

/// Get try count for a drink.
int getTryCount(Drink drink) {
  return _favorites[drink.id]?.tries.length ?? 0;
}

/// Get all favorite drinks.
List<Drink> get favoriteDrinks {
  return _drinks.where((d) => _favorites.containsKey(d.id)).toList();
}
```

3. **Update existing toggleFavorite method:**
```dart
/// Toggles favorite status (adds to "want to try" or removes from log).
void toggleFavorite(Drink drink) {
  if (_favorites.containsKey(drink.id)) {
    // Remove from log
    _favorites.remove(drink.id);
  } else {
    // Add to "want to try"
    _favorites[drink.id] = FavoriteItem(
      id: drink.id,
      status: 'want_to_try',
      tries: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  _saveFavorites();
  notifyListeners();
}
```

4. **Add new methods:**
```dart
/// Marks a drink as tasted (adds timestamp).
void markAsTasted(Drink drink) {
  final existing = _favorites[drink.id];
  final now = DateTime.now();

  if (existing == null) {
    // Not in log yet, add as tasted
    _favorites[drink.id] = FavoriteItem(
      id: drink.id,
      status: 'tasted',
      tries: [now],
      createdAt: now,
      updatedAt: now,
    );
  } else {
    // Already in log, add timestamp and update status
    _favorites[drink.id] = existing.copyWith(
      status: 'tasted',
      tries: [...existing.tries, now],
      updatedAt: now,
    );
  }

  _saveFavorites();
  notifyListeners();

  // Analytics
  _analytics.logEvent(
    name: getTryCount(drink) > 1 ? 'festival_log_multiple_tasting' : 'festival_log_mark_tasted',
    parameters: {'drink_id': drink.id, 'try_count': getTryCount(drink)},
  );
}

/// Deletes a specific tasting timestamp.
void deleteTry(Drink drink, DateTime timestamp) {
  final existing = _favorites[drink.id];
  if (existing == null) return;

  final updatedTries = existing.tries.where((t) => t != timestamp).toList();

  if (updatedTries.isEmpty) {
    // No more tries, revert to "want to try"
    _favorites[drink.id] = existing.copyWith(
      status: 'want_to_try',
      tries: [],
      updatedAt: DateTime.now(),
    );
  } else {
    // Still has tries, just update list
    _favorites[drink.id] = existing.copyWith(
      tries: updatedTries,
      updatedAt: DateTime.now(),
    );
  }

  _saveFavorites();
  notifyListeners();

  // Analytics
  _analytics.logEvent(
    name: 'festival_log_delete_timestamp',
    parameters: {'drink_id': drink.id},
  );
}
```

**Tests:** `test/providers/beer_provider_test.dart` (UPDATE)
- Test toggleFavorite (add/remove)
- Test markAsTasted (first time)
- Test markAsTasted (multiple times)
- Test deleteTry
- Test getFavoriteStatus
- Test getTryCount

---

### Phase 4: UI Implementation (6-8 hours)

**Goal:** Add visual indicators and try tracking UI.

---

#### Task 4.1: Add Status Badges to Drink Cards

**File:** `lib/widgets/drink_card.dart` (UPDATE)

**Changes:**

1. **Add badge widget:**
```dart
Widget _buildStatusBadge(BuildContext context, Drink drink) {
  final provider = context.watch<BeerProvider>();
  final status = provider.getFavoriteStatus(drink);

  if (status == null) {
    return const SizedBox.shrink(); // No badge
  }

  final (icon, color, label) = switch (status) {
    'want_to_try' => (
        Icons.circle_outlined,
        Colors.grey,
        'Want to try',
      ),
    'tasted' when provider.getTryCount(drink) == 1 => (
        Icons.check_circle,
        Colors.green,
        'Tasted once',
      ),
    'tasted' => (
        Icons.check_circle,
        Colors.green,
        'Tasted ${provider.getTryCount(drink)} times',
      ),
    _ => (Icons.circle_outlined, Colors.grey, 'Unknown'),
  };

  return Positioned(
    top: 8,
    right: 8,
    child: Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (provider.getTryCount(drink) > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${provider.getTryCount(drink)}x',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
```

2. **Add badge to card:**
```dart
@override
Widget build(BuildContext context) {
  return Card(
    child: Stack( // Wrap in Stack
      children: [
        // Existing card content (InkWell, Column, etc.)
        InkWell(...),

        // Status badge overlay
        _buildStatusBadge(context, drink),
      ],
    ),
  );
}
```

**Tests:** `test/widgets/drink_card_test.dart` (UPDATE)
- Test badge renders for "want to try"
- Test badge renders for "tasted" (single)
- Test badge renders for "tasted" (multiple with count)
- Test no badge for drinks not in log
- Test Semantics labels

---

#### Task 4.2: Update Drink Detail Screen

**File:** `lib/screens/drink_detail_screen.dart` (UPDATE)

**Changes:**

1. **Add "Mark as Tasted" button:**
```dart
ElevatedButton.icon(
  onPressed: () {
    provider.markAsTasted(drink);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked as tasted!')),
    );
  },
  icon: Icon(Icons.check_circle),
  label: Text('Mark as Tasted'),
),
```

2. **Add try history list:**
```dart
Widget _buildTryHistory(BuildContext context, Drink drink) {
  final provider = context.watch<BeerProvider>();
  final item = provider._favorites[drink.id];

  if (item == null || item.tries.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Tasting History',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (var tryDate in item.tries)
        ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text(_formatTryDate(tryDate)),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline),
            tooltip: 'Delete tasting',
            onPressed: () => _confirmDeleteTry(context, drink, tryDate),
          ),
        ),
    ],
  );
}

void _confirmDeleteTry(BuildContext context, Drink drink, DateTime tryDate) {
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
            context.read<BeerProvider>().deleteTry(drink, tryDate);
            Navigator.pop(context);
          },
          child: Text('Delete'),
        ),
      ],
    ),
  );
}

String _formatTryDate(DateTime date) {
  // Format like: "Dec 23, 2025 at 2:30 PM"
  return DateFormat('MMM d, y \'at\' h:mm a').format(date);
}
```

**Tests:** `test/screens/drink_detail_screen_test.dart` (UPDATE)
- Test "Mark as Tasted" button renders
- Test tapping button calls provider method
- Test try history list renders
- Test delete button shows confirmation
- Test deleting try calls provider method

---

#### Task 4.3: Redesign Favorites Screen as Festival Log

**File:** `lib/main.dart` or `lib/screens/favorites_screen.dart` (UPDATE)

**Changes:**

1. **Update screen title:**
```dart
// Old: "Favorites"
// New: "My Festival"
```

2. **Implement unified list with smart sort:**
```dart
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

  if (sorted.isEmpty) {
    return _buildEmptyState(context);
  }

  return ListView.builder(
    itemCount: sorted.length,
    itemBuilder: (context, index) {
      final drink = sorted[index];
      final status = provider.getFavoriteStatus(drink);

      // Show divider between "want to try" and "tasted"
      final showDivider = index > 0 &&
          provider.getFavoriteStatus(sorted[index - 1]) != status;

      return Column(
        children: [
          if (showDivider) _buildSectionDivider(status!),
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
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    ),
  );
}

Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_border, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'Your festival log is empty',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 8),
        Text(
          'Tap the heart icon to add drinks you want to try',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
```

**Tests:** `test/screens/favorites_screen_test.dart` (NEW or UPDATE)
- Test unified list renders
- Test sort order ("want to try" first)
- Test section divider appears
- Test empty state
- Test Semantics for screen reader

---

## Testing Strategy

**Pre-release note:** No migration tests needed since there's no legacy data format to migrate from.

### Unit Tests

**Critical tests:**
- FavoriteItem serialization (toJson/fromJson)
- StorageService load/save (empty data, valid data, corrupted data)
- Provider methods (toggle, markAsTasted, deleteTry)
- Festival-scoped data isolation

**Coverage target:** 95%+ for data model and storage

### Widget Tests

**Critical tests:**
- Status badge rendering (all states)
- Badge Semantics labels
- Try tracking UI (button, list, delete confirmation)
- Festival Log screen (list, sort, divider, empty state)

**Coverage target:** 90%+ for UI components

### Integration Tests

**User flows to test:**
1. Add drink to "Want to Try"
2. Mark drink as "Tasted"
3. Mark same drink tasted again (multiple)
4. Delete a tasting timestamp
5. View Festival Log (sorted correctly)
6. Switch festivals (data is scoped)

### Manual Testing Checklist

- [ ] Status badges visible on all drink cards
- [ ] "Mark as Tasted" adds timestamp
- [ ] Multiple tastings show count
- [ ] Deleting timestamp works with confirmation
- [ ] Festival Log sorts correctly
- [ ] Empty states show helpful messages
- [ ] Fresh app install works (no data errors)
- [ ] Festival-scoped data isolation (CBF 2025 vs CBF 2024 have separate favorites)
- [ ] Accessibility: TalkBack/VoiceOver reads labels correctly
- [ ] Large text: No overflow at 200% scale

## Validation Checklist

**Before marking Phase 3 complete:**
- [ ] All unit tests pass
- [ ] Storage service handles edge cases (empty, corrupted data)
- [ ] Code follows style guide
- [ ] All public APIs documented

**Before marking Phase 4 complete:**
- [ ] All widget tests pass
- [ ] Integration tests pass
- [ ] Manual testing checklist complete
- [ ] Accessibility verified
- [ ] Analytics events firing

## Related Documents

- **[design.md](design.md)** - Design decisions and rationale
- **[detailed-decisions.md](detailed-decisions.md)** - Detailed pros/cons for each decision
- **[../../processes/festival-data-prs.md](../../processes/festival-data-prs.md)** - User-facing FAQ
- **[../deep-linking/implementation-plan.md](../deep-linking/implementation-plan.md)** - Prerequisite: Festival linking

---

**Last Updated**: December 2025
**Status**: 💡 Proposal - Awaiting implementation
