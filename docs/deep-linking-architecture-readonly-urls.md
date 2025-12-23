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

## Summary of Changes Needed

### Provider Changes

1. ❌ **Remove:** `Festival _currentFestival;`
2. ✅ **Keep:** `Festival _userPreferredFestival;`
3. ✅ **Add:** `Festival? getFestivalById(String id)`
4. ✅ **Add:** `Future<List<Drink>> getDrinksForFestival(Festival)`
5. ✅ **Add:** Multi-festival caching (if Q3 = A)

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
