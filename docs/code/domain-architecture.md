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
│  • Persists user preferences                │
└─────────────────┬───────────────────────────┘
                  │ delegates to
                  ↓
┌─────────────────────────────────────────────┐
│       Domain Layer (Business Logic)         │
│  • DrinkFilterService - Filtering logic     │
│  • DrinkSortService - Sorting strategies    │
│  • Pure functions, no dependencies          │
└─────────────────────────────────────────────┘
                  │ operates on
                  ↓
┌─────────────────────────────────────────────┐
│         Data Layer (Models)                 │
│  • Drink, Product, Producer, Festival       │
└─────────────────────────────────────────────┘
                  │ fetched by
                  ↓
┌─────────────────────────────────────────────┐
│   Infrastructure (Services)                 │
│  • BeerApiService - HTTP calls              │
│  • FavoritesService - Storage               │
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

Services are injected into `BeerProvider` (can be mocked for testing):

```dart
BeerProvider({
  DrinkFilterService? filterService,
  DrinkSortService? sortService,
})  : _filterService = filterService ?? DrinkFilterService(),
      _sortService = sortService ?? DrinkSortService();
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

### 1. Repository Pattern

Abstract data access behind interfaces:

```dart
abstract class DrinkRepository {
  Future<List<Drink>> getDrinks(Festival festival);
  Future<void> saveFavorite(String drinkId);
}

class ApiDrinkRepository implements DrinkRepository {
  final BeerApiService _api;
  final FavoritesService _favorites;
  // Implementation...
}
```

**When to add:** When you need offline support, caching, or multiple data sources.

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

✅ Domain services created
✅ BeerProvider refactored to use services
✅ Unit tests added for domain services
✅ Integration tests updated
✅ Documentation updated

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
