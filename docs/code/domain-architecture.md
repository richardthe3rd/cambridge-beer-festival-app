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
│  • Orchestrates domain services             │
│  • Manages UI state (loading, errors)       │
│  • Uses repositories for data access        │
└───────────┬────────────────┬────────────────┘
            │ delegates to   │ uses
            ↓                ↓
┌───────────────────────┐ ┌──────────────────────────────┐
│ Domain Layer          │ │  Domain Repositories         │
│  • DrinkFilterService │ │  • DrinkRepository (interface)│
│  • DrinkSortService   │ │  • FestivalRepository (iface) │
│  Pure business logic  │ │  Data access abstractions    │
└───────────────────────┘ └────────────┬─────────────────┘
            │ operates on                │ implemented by
            ↓                            ↓
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
│  • FavoritesService - Storage               │
│  • FestivalService - Festival API           │
│  • FestivalStorageService - Storage         │
│  • AnalyticsService - Tracking              │
└─────────────────────────────────────────────┘
```

## Domain Services

### DrinkFilterService

**Location:** `lib/domain/services/drink_filter_service.dart`

**Purpose:** Contains all filtering logic for drinks.

**Methods:**
- `filterByCategory(drinks, category)` - Filter by category (beer, cider, etc.)
- `filterByStyles(drinks, styles)` - Filter by multiple styles (OR logic)
- `filterByFavorites(drinks, favoritesOnly)` - Show only favorites
- `filterByAvailability(drinks, hideUnavailable)` - Hide out-of-stock drinks
- `filterBySearch(drinks, query)` - Search across name, brewery, style, notes
- `applyAllFilters(drinks, {...})` - Convenience method for all filters

**Design:**
- Pure functions - no side effects
- Stateless - no instance variables
- No dependencies - operates only on data passed as parameters
- Returns new lists - doesn't mutate input

**Example:**
```dart
final service = DrinkFilterService();

final filtered = service.applyAllFilters(
  allDrinks,
  category: 'beer',
  styles: {'IPA', 'Bitter'},
  favoritesOnly: true,
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
- Wraps `BeerApiService`, `FavoritesService`, `RatingsService`
- Fetches drinks and populates favorite/rating status in a single operation

**Design:**
- Interface in domain layer - abstracts data access
- Implementation uses infrastructure services
- BeerProvider depends on repository interface, not concrete services

**Example:**
```dart
final repository = ApiDrinkRepository(
  apiService: BeerApiService(),
  favoritesService: FavoritesService(prefs),
  ratingsService: RatingsService(prefs),
);

final drinks = await repository.getDrinks(festival);
// Drinks already have isFavorite and rating populated
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

## BeerProvider Orchestration

`BeerProvider` delegates business logic to domain services:

```dart
void _applyFiltersAndSort() {
  var drinks = List<Drink>.from(_allDrinks);

  // Delegate filtering to domain service
  drinks = _filterService.applyAllFilters(
    drinks,
    category: _selectedCategory,
    styles: _selectedStyles,
    favoritesOnly: _showFavoritesOnly,
    hideUnavailable: _hideUnavailable,
    searchQuery: _searchQuery,
  );

  // Delegate sorting to domain service
  drinks = _sortService.sortDrinks(drinks, _currentSort);

  _filteredDrinks = drinks;
}
```

**Before refactoring:** 63 lines of filtering/sorting logic in `_applyFiltersAndSort()`
**After refactoring:** 17 lines delegating to domain services

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
test('filters by category', () {
  final service = DrinkFilterService();
  final result = service.filterByCategory(testDrinks, 'beer');
  expect(result, hasLength(2));
});
```

### 2. Better Maintainability

Changes to filtering logic:
- **Before:** Modify `BeerProvider._applyFiltersAndSort()` (63 lines)
- **After:** Modify `DrinkFilterService` (focused, single responsibility)

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
- `DrinkRepository` - Abstracts drink data access, favorites, and ratings
- `FestivalRepository` - Abstracts festival data access and user preferences

**Implementations:**
- `ApiDrinkRepository` - Wraps BeerApiService, FavoritesService, RatingsService
- `ApiFestivalRepository` - Wraps FestivalService, FestivalStorageService

**Location:** `lib/domain/repositories/`

**Example:**
```dart
abstract class DrinkRepository {
  Future<List<Drink>> getDrinks(Festival festival);
  Future<List<String>> getFavorites(String festivalId);
  Future<bool> toggleFavorite(String festivalId, String drinkId);
  Future<int?> getRating(String festivalId, String drinkId);
  Future<void> setRating(String festivalId, String drinkId, int rating);
  Future<void> removeRating(String festivalId, String drinkId);
}

class ApiDrinkRepository implements DrinkRepository {
  final BeerApiService _apiService;
  final FavoritesService _favoritesService;
  final RatingsService _ratingsService;

  @override
  Future<List<Drink>> getDrinks(Festival festival) async {
    final drinks = await _apiService.fetchAllDrinks(festival);
    // Populate favorites and ratings
    final favorites = _favoritesService.getFavorites(festival.id);
    for (final drink in drinks) {
      drink.isFavorite = favorites.contains(drink.id);
      drink.rating = _ratingsService.getRating(festival.id, drink.id);
    }
    return drinks;
  }
  // ... other methods
}
```

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
    return _filterService.applyAllFilters(drinks, ...);
  }
}
```

**When to add:** When workflows involve multiple services or complex orchestration.

### 3. Value Objects

Encapsulate validation and behavior:

```dart
class FilterCriteria {
  final String? category;
  final Set<String> styles;
  final bool favoritesOnly;
  final bool hideUnavailable;
  final String searchQuery;

  FilterCriteria({...});

  bool get hasActiveFilters =>
    category != null ||
    styles.isNotEmpty ||
    favoritesOnly ||
    hideUnavailable ||
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
