# Domain Architecture Guide

This guide explains the domain layer architecture and design decisions for the Cambridge Beer Festival app.

## Overview

The app uses a **layered architecture** with a dedicated domain layer containing business logic separated from UI and infrastructure concerns.

## Architecture Layers

```
┌─────────────────────────────────────────────┐
│         UI Layer (Screens/Widgets)          │
│  • DrinksScreen, DrinkDetailScreen, etc.    │
└─────────────────┬───────────────────────────┘
                  │ context.watch()
                  ↓
┌─────────────────────────────────────────────┐
│    State Management (BeerProvider)          │
│  • Composes domain controllers              │
│  • Manages UI state (loading, errors)       │
│  • Handles persistence, analytics, notify   │
│  • Uses repositories for data access        │
└───────────┬────────────────┬────────────────┘
            │ composes       │ uses
            ↓                ↓
┌───────────────────────────┐ ┌──────────────────────────────┐
│ Domain Controllers        │ │  Domain Repositories         │
│  • DrinkFilterController  │ │  • DrinkRepository (interface)│
│  • FestivalController     │ │  • FestivalRepository (iface) │
│  • UserDrinkStateController│ │  Data access abstractions    │
│  • UserPreferencesController│ └───────────┬─────────────────┘
│  Owns filter/sort state   │              │
└───────────┬───────────────┘              │
            │ delegates to                 │
            ↓                              │
┌───────────────────────┐                  │
│ Domain Services       │                  │
│  • DrinkFilterService │                  │
│  • DrinkSortService   │                  │
│  • SearchMatchService │                  │
│  Pure, stateless      │                  │
└───────────┬───────────┘                  │
            │ operates on      implemented by
            ↓                              ↓
┌─────────────────────────────────────────────┐
│         Data Layer (Models)                 │
│  • Drink, Product, Producer, Festival       │
└─────────────────────────────────────────────┘
                  ↑ fetched by
                  │
┌─────────────────┴───────────────────────────┐
│  Repository Implementations                 │
│  • ApiDrinkRepository                       │
│  • ApiFestivalRepository                    │
└───────────┬─────────────────────────────────┘
            │ uses
            ↓
┌─────────────────────────────────────────────┐
│   Infrastructure (Services)                 │
│  • BeerApiService - HTTP calls              │
│  • UserDataStore - All per-user data        │
│  • DrinkCacheService - Offline catalogue     │
│  • FestivalService - Festival API           │
│  • FestivalStorageService - Festival choice │
│  • AnalyticsService - Tracking              │
└─────────────────────────────────────────────┘
```

## Domain Services

### DrinkFilterService

**Location:** `lib/domain/services/drink_filter_service.dart`

**Purpose:** Contains all filtering logic for drinks.

**Methods:**
- `filterByCategories(drinks, categories)` - Filter by categories (multi-select, OR logic)
- `filterByStyles(drinks, styles)` - Filter by multiple styles (OR logic)
- `filterByFavorites(drinks, favoritesOnly:)` - Show only favorites
- `filterByAvailability(drinks, hideUnavailable:)` - Hide sold-out drinks
- `filterByNotTasted(drinks, notTastedOnly:)` - Hide drinks already tasted
- `filterByVegan(drinks, veganOnly:)` - Only drinks explicitly flagged vegan
- `filterByExcludedAllergens(drinks, excludedAllergens)` - Exclude drinks carrying any listed allergen
- `filterBySearch(drinks, query)` - Search across name, brewery, style, description, and the user's own note
- `filterDrinks(drinks, {...})` - Composes all of the above in sequence

**Design:**
- Pure functions - no side effects
- Stateless - no instance variables
- Single-purpose filters return a lazy `Iterable`; `filterDrinks` materialises once at the end
- `filterDrinks` is *composed from* the single-purpose filters rather than
  re-testing each predicate inline, so there is exactly one copy of every rule —
  a fix to `filterByAvailability` cannot pass its own unit test while leaving the
  rendered list unchanged
- Returns new lists - doesn't mutate input
- Free-text matching is delegated to `SearchMatchService`, the shared source of
  truth for which fields search covers, so the UI's excerpt/highlighting stays in
  lock-step with what actually matched

**Example:**
```dart
final service = DrinkFilterService();

final filtered = service.filterDrinks(
  allDrinks,
  categories: {'beer'},
  styles: {'IPA', 'Bitter'},
  favoritesOnly: true,
  visibilityFilters: {DrinkVisibilityFilter.availableOnly},
  excludedAllergens: {'gluten'},
  searchQuery: 'hoppy',
);
```

**Tests:** `test/domain/services/drink_filter_service_test.dart`
- 30+ isolated unit tests
- No mocks required
- Fast execution

### DrinkSortService

**Location:** `lib/domain/services/drink_sort_service.dart`

**Purpose:** Contains all sorting logic for drinks.

**Methods:**
- `sortDrinks(drinks, sortBy)` - Sort by DrinkSort enum value
- `sortByNameAsc(drinks)` - Sort A-Z
- `sortByNameDesc(drinks)` - Sort Z-A
- `sortByAbvHigh(drinks)` - Sort by ABV high to low
- `sortByAbvLow(drinks)` - Sort by ABV low to high
- `sortByBrewery(drinks)` - Sort by brewery name
- `sortByStyle(drinks)` - Sort by style

**Design:**
- Mutates the list in place (standard Dart List.sort behavior)
- Returns the sorted list for method chaining
- Stateless and pure (aside from mutation)

**Example:**
```dart
final service = DrinkSortService();

final sorted = service.sortDrinks(drinks, DrinkSort.abvHigh);
```

**Tests:** `test/domain/services/drink_sort_service_test.dart`
- Tests for each sort strategy
- Verifies correct ordering
- Tests all DrinkSort enum values

## Domain Repositories

### DrinkRepository

**Location:** `lib/domain/repositories/drink_repository.dart`

**Purpose:** Abstracts data access for drinks, favorites, and ratings.

**Interface Methods:**
- `getDrinks(Festival)` - Fetch drinks for a festival with favorites/ratings populated
- `getFavorites(festivalId)` - Get favorite drink IDs
- `toggleFavorite(festivalId, drinkId)` - Toggle favorite status
- `getRating(festivalId, drinkId)` - Get drink rating
- `setRating(festivalId, drinkId, rating)` - Set drink rating
- `removeRating(festivalId, drinkId)` - Remove drink rating

**Implementation:** `ApiDrinkRepository`
- Delegates catalogue loading to `BeerApiService` / `DrinkCacheService`, and all
  personal state to a `UserDataStore`
- Fetches drinks and populates favorite/rating/tasted status in a single operation

**Design:**
- Interface in domain layer - abstracts data access
- Implementation uses infrastructure services
- BeerProvider depends on repository interface, not concrete services
- Depending on the `UserDataStore` *interface* (not the concrete
  SharedPreferences store) keeps a synced backend a constructor swap

**Example:**
```dart
final repository = ApiDrinkRepository(
  apiService: BeerApiService(),
  userDataStore: userDataStore,
  cacheService: DrinkCacheService(),
  analyticsService: AnalyticsService(),
);

final drinks = await repository.getDrinks(festival);
// Drinks already have isFavorite, rating, and tasted status populated
```

### FestivalRepository

**Location:** `lib/domain/repositories/festival_repository.dart`

**Purpose:** Abstracts data access for festival metadata and user preferences.

**Interface Methods:**
- `getFestivals()` - Fetch all available festivals (returns `FestivalsResponse`)
- `getSelectedFestivalId()` - Get previously selected festival ID from storage
- `setSelectedFestivalId(festivalId)` - Save selected festival ID to storage

**Implementation:** `ApiFestivalRepository`
- Wraps `FestivalService`, `FestivalStorageService`
- Separates festival data fetching from local preference storage

## Domain Controllers

Controllers sit between `BeerProvider` and the pure services. They own
*application state* (the user's current filter selections) while the services
stay stateless. Like services they are pure application logic — no Flutter,
persistence, async, or analytics — so they unit-test in isolation.

### DrinkFilterController

**Location:** `lib/domain/controllers/drink_filter_controller.dart`

**Purpose:** Owns filtering, sorting, and search state, and derives the views the
UI needs — the filtered list plus the category/style/allergen facets.

`BeerProvider` composes this controller, feeds it the loaded drinks via
`setSource()`, and handles the cross-cutting concerns (persistence, analytics,
change notification) around it. All mutators are synchronous and side-effect
free; callers persist and broadcast.

**The single recompute path** is `recompute()` — every mutator ends by calling
it, and it is the only place the filter/sort pipeline runs:

```dart
void recompute() {
  final filtered = _filterService.filterDrinks(
    _source,
    categories: _selectedCategories,
    styles: _selectedStyles,
    favoritesOnly: _showFavoritesOnly,
    visibilityFilters: _visibilityFilters,
    excludedAllergens: _excludedAllergens,
    searchQuery: _searchQuery,
  );
  _filtered = _sortService.sortDrinks(filtered, _currentSort);
}
```

Call `recompute()` directly after the source drinks mutate in place (e.g. a
favourite or tasted toggle); use `setSource()` when the list itself is replaced.

#### The facet-scoping rule

`availableCategories`, `categoryCountsMap`, `availableStyles`, `styleCountsMap`,
`stylesByCategory`, and `availableAllergens` are all derived by one rule:

> **A facet is computed from the source with every *other* structural filter
> applied — but never its own.**

Structural filters are category, styles, favourites-only, visibility filters, and
excluded allergens. A facet must not narrow itself, or selecting one of its own
options would hide its siblings and the list would collapse under the user's
finger — picking one style must not make every other style vanish from the style
picker. `_scopeFor(_Facet)` is the single helper all the getters share; it blanks
out exactly the facet's own criterion.

Two invariants hold for every facet:

1. **An active filter is never hidden.** A currently-selected option is always
   listed, even when its scoped count is 0. This matters most for allergen
   exclusions, which are a *safety* filter — a ticked allergen must never vanish
   from the UI the user would use to untick it.
2. **Allergens must be actually present.** `availableAllergens` lists only
   allergens with a non-zero value on some drink in scope, not merely mentioned
   with a value of 0 — matching `DrinkFilterService.filterByExcludedAllergens`'s
   own definition of "absent".

**Free-text search is deliberately excluded from facet scoping.**
`drinks_screen.dart` derives `hasStyleFilter` from
`provider.availableStyles.isNotEmpty` to decide whether to show the Style button
in the filter bar. Scoping facets by the search query would make that button
appear and disappear as the user types.

A related consequence: `toggleCategory` *prunes* the style selection to the new
scope rather than clearing it. Under the old single-select category this was an
unconditional clear, which is too destructive for multi-select — adding "perry"
to an existing "cider" selection would otherwise wipe a cider style the user just
picked.

## BeerProvider Orchestration

`BeerProvider` composes the controllers and exposes their derived views:

```dart
BeerProvider({
  AnalyticsService? analyticsService,
  DrinkFilterService? filterService,
  DrinkSortService? sortService,
  DrinkRepository? drinkRepository,
  FestivalRepository? festivalRepository,
}) : _analyticsService = analyticsService ?? AnalyticsService(),
     _filter = DrinkFilterController(
       filterService: filterService,
       sortService: sortService,
     ),
     _drinkRepository = drinkRepository,
     _festivalRepository = festivalRepository;

// Derived views delegate straight through
List<Drink> get drinks => _filter.filteredDrinks;
```

## Design Principles

### 1. Separation of Concerns

- **Domain services** - Business logic (filtering, sorting)
- **BeerProvider** - State management and orchestration
- **API services** - Data fetching and persistence
- **UI** - Presentation and user interaction

### 2. Dependency Inversion

Services and repositories are injected into `BeerProvider` (can be mocked for testing):

```dart
BeerProvider({
  DrinkRepository? drinkRepository,
  FestivalRepository? festivalRepository,
  AnalyticsService? analyticsService,
  DrinkFilterService? filterService,
  DrinkSortService? sortService,
})  : _filterService = filterService ?? DrinkFilterService(),
      _sortService = sortService ?? DrinkSortService(),
      _drinkRepository = drinkRepository,
      _festivalRepository = festivalRepository;

// Repositories created in initialize() if not injected
Future<void> initialize() async {
  if (_drinkRepository == null) {
    _drinkRepository = ApiDrinkRepository(...);
  }
  if (_festivalRepository == null) {
    _festivalRepository = ApiFestivalRepository(...);
  }
  // ...
}
```

### 3. Testability

**Domain services:**
- Tested in isolation
- No mocking required
- Fast, focused unit tests

**BeerProvider:**
- Integration tests verify orchestration
- Services can be mocked if needed
- Tests focus on state management

### 4. Reusability

Domain services can be used:
- By BeerProvider (current usage)
- By widgets directly (future possibility)
- By other providers (if app grows)
- In background isolates (for heavy processing)

## Benefits of Domain Layer

### 1. Easier Testing

**Before:**
```dart
// Had to mock entire provider to test filtering
test('filters by category', () {
  final provider = BeerProvider(
    apiService: mockApi,
    festivalService: mockFestival,
    analyticsService: mockAnalytics,
  );
  await provider.initialize();
  // ... complex setup ...
  provider.setCategory('beer');
  expect(provider.drinks.length, 2);
});
```

**After:**
```dart
// Simple, focused unit test
test('filters by categories', () {
  final service = DrinkFilterService();
  final result = service.filterByCategories(testDrinks, {'beer'});
  expect(result, hasLength(2));
});
```

### 2. Better Maintainability

Changes to filtering logic:
- **Before:** Modify a monolithic `_applyFiltersAndSort()` inside `BeerProvider`
- **After:** Modify `DrinkFilterService` (a single rule) or
  `DrinkFilterController` (how the rules compose and what state drives them)

### 3. Code Reuse

Domain services are reusable:
```dart
// In a widget that needs custom filtering
final filterService = DrinkFilterService();
final filtered = filterService.filterBySearch(drinks, userQuery);
```

### 4. Reduced Coupling

- UI depends on BeerProvider (state management)
- BeerProvider depends on domain services (business logic)
- Domain services depend on nothing (pure logic)

## When to Add New Domain Services

Create a new domain service when:
1. **Business logic gets complex** (>20 lines)
2. **Logic is reused** in multiple places
3. **Logic is independent** of state management
4. **You want isolated testing** without mocking

Examples of good candidates:
- `DrinkRecommendationService` - Personalized recommendations
- `DrinkStatisticsService` - Calculate stats (avg ABV, etc.)
- `DrinkValidationService` - Validate drink data

## Testing Strategy

### Unit Tests (Domain Services)

**Focus:** Business logic correctness
**Location:** `test/domain/services/`
**Characteristics:**
- Fast execution (<1ms per test)
- No mocks required
- Test edge cases exhaustively

### Integration Tests (BeerProvider)

**Focus:** State management and orchestration
**Location:** `test/beer_provider_test.dart`
**Characteristics:**
- Test that services are called correctly
- Test state changes (loading, errors)
- Test that notifyListeners is called
- Can mock services if needed

### Widget Tests (UI)

**Focus:** User interactions
**Location:** `test/screens/`, `test/widgets/`
**Characteristics:**
- Test that UI responds to provider state
- Test user interactions trigger provider methods

## Code Organization

```
lib/domain/
└── services/
    ├── drink_filter_service.dart
    ├── drink_sort_service.dart
    └── services.dart              # Barrel export

test/domain/
└── services/
    ├── drink_filter_service_test.dart
    └── drink_sort_service_test.dart
```

## Future Enhancements

Potential extensions to the domain layer:

### 1. Repository Pattern ✅ IMPLEMENTED

**Status:** Implemented in Phase 2

Data access is now abstracted behind repository interfaces:

**Repository Interfaces:**
- `DrinkRepository` - Abstracts drink data access, favorites, ratings, and tastings
- `FestivalRepository` - Abstracts festival data access and user preferences

**Implementations:**
- `ApiDrinkRepository` - Wraps BeerApiService, UserDataStore, DrinkCacheService, AnalyticsService
- `ApiFestivalRepository` - Wraps FestivalService, FestivalStorageService, FestivalCacheService, AnalyticsService

**Location:** `lib/domain/repositories/`

**Example:**
```dart
abstract class DrinkRepository {
  Future<List<Drink>> getDrinks(Festival festival);
  Future<List<Drink>?> getCachedDrinks(Festival festival);
  Future<List<String>> getFavorites(String festivalId);
  Future<UserDrinkState?> toggleFavorite(String festivalId, String drinkId);
  Future<int?> getRating(String festivalId, String drinkId);
  Future<UserDrinkState?> setRating(String festivalId, String drinkId, int rating);
  Future<UserDrinkState?> removeRating(String festivalId, String drinkId);
  Future<bool> hasTasted(String festivalId, String drinkId);
  Future<UserDrinkState?> toggleTasted(String festivalId, String drinkId);
  // ... tasting-log methods
}
```

Mutating methods return the persisted `UserDrinkState`, or `null` when the
record was pruned to empty — the caller updates from what was actually written
rather than assuming the write succeeded.

**Benefits:**
- **Testability:** BeerProvider can be tested with mock repositories
- **Decoupling:** Provider doesn't depend on concrete services
- **Flexibility:** Easy to swap implementations (e.g., offline mode, caching)

### 2. Use Cases / Interactors

Encapsulate complex workflows:

```dart
class LoadFestivalDrinksUseCase {
  final DrinkRepository _repository;
  final DrinkFilterService _filterService;

  Future<List<Drink>> execute(Festival festival, FilterCriteria criteria) {
    final drinks = await _repository.getDrinks(festival);
    return _filterService.filterDrinks(drinks, ...);
  }
}
```

**When to add:** When workflows involve multiple services or complex orchestration.

### 3. Value Objects

Encapsulate validation and behavior:

```dart
class FilterCriteria {
  final Set<String> categories;
  final Set<String> styles;
  final bool favoritesOnly;
  final Set<DrinkVisibilityFilter> visibilityFilters;
  final Set<String> excludedAllergens;
  final String searchQuery;

  FilterCriteria({...});

  bool get hasActiveFilters =>
    categories.isNotEmpty ||
    styles.isNotEmpty ||
    favoritesOnly ||
    visibilityFilters.isNotEmpty ||
    excludedAllergens.isNotEmpty ||
    searchQuery.isNotEmpty;
}
```

**When to add:** When domain concepts have validation rules or behavior.

## Migration from Previous Architecture

### What Changed

**Removed from BeerProvider:**
- 40+ lines of filtering logic → `DrinkFilterService`
- 20+ lines of sorting logic → `DrinkSortService`

**Added to BeerProvider:**
- 2 domain service instances
- Delegation calls to services

**Net result:**
- BeerProvider: 583 lines → 540 lines (-7%)
- Business logic: Now testable in isolation
- Complexity: Reduced (logic now in focused services)

### Breaking Changes

**None.** The refactoring is internal - public API of BeerProvider remains the same.

### Migration Checklist

**Phase 1: Domain Services**
✅ Domain services created (DrinkFilterService, DrinkSortService)
✅ BeerProvider refactored to use services
✅ Unit tests added for domain services (41 tests)
✅ Integration tests updated
✅ Documentation updated

**Phase 2: Repository Pattern**
✅ Repository interfaces created (DrinkRepository, FestivalRepository)
✅ Repository implementations created (ApiDrinkRepository, ApiFestivalRepository)
✅ BeerProvider refactored to use repositories
✅ Test mocks updated (MockDrinkRepository, MockFestivalRepository)
✅ Documentation updated (442/485 tests passing, 91% pass rate)

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Development instructions
- [API Documentation](api/README.md) - API reference
- [Accessibility Guide](accessibility.md) - Accessibility requirements

## Questions?

For questions about the domain architecture:
1. Review this guide
2. Read the domain service source code
3. Check the unit tests for examples
4. Consult the team or create an issue
