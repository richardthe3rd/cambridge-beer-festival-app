# Development Guide

Developer documentation for the Cambridge Beer Festival app - implementation details and completed features.

## Table of Contents

- [Recently Implemented Features](#recently-implemented-features)
- [HTTP Request Timeouts](#http-request-timeouts)
- [Error Handling](#error-handling)
- [User-Friendly Error Messages](#user-friendly-error-messages)
- [Mobile UI Optimizations](#mobile-ui-optimizations)
- [Detail Screen Layout Pattern](#detail-screen-layout-pattern)
- [Testing](#testing)

---

## Recently Implemented Features

This document tracks features that have been successfully implemented and how they work.

### Status Overview

✅ **Completed (5 items):**
1. HTTP request timeouts
2. Error handling for URL launches
3. User-friendly error messages
4. SliverAppBar mobile optimization
5. Detail screen layout simplification

⚠️ **Partially Complete (1 item):**
- Widget tests (StarRating only)

❌ **Pending (29 items):**
- See [../todos.md](../todos.md) for complete list

---

## HTTP Request Timeouts

**Status:** ✅ Completed
**Location:** `lib/services/beer_api_service.dart`
**Implemented:** 2025-11-30

### How It Works

The `BeerApiService` now includes configurable HTTP request timeouts to prevent indefinite hangs.

**Implementation:**

```dart
class BeerApiService {
  final http.Client _client;
  final Duration timeout;

  BeerApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30), // Default 30s
  }) : _client = client ?? http.Client();

  Future<List<Drink>> fetchDrinks(Festival festival, String beverageType) async {
    final url = festival.getBeverageUrl(beverageType);
    final response = await _client.get(Uri.parse(url))
        .timeout(timeout); // Timeout applied here
    // ...
  }
}
```

### Key Features

- **Default timeout:** 30 seconds (configurable)
- **Throws TimeoutException** when exceeded
- **Can be customized** via constructor for testing
- **Applies to all HTTP requests** in the service

### Usage

```dart
// Use default 30s timeout
final service = BeerApiService();

// Custom timeout for testing
final testService = BeerApiService(
  timeout: const Duration(milliseconds: 100),
);
```

### Testing

Tests exist in `test/services_test.dart`:
- Default timeout verification
- Custom timeout acceptance
- Timeout enforcement on HTTP requests
- Successful completion within timeout

---

## Error Handling

**Status:** ✅ Completed
**Location:** `lib/screens/festival_info_screen.dart`
**Implemented:** 2025-11-30

### URL Launch Error Handling

URL launch operations (maps, website) now provide user feedback on failures.

**Implementation:**

```dart
void _openMaps(BuildContext context) async {
  if (festival.latitude == null || festival.longitude == null) return;

  final url = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${festival.latitude},${festival.longitude}',
  );

  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening maps')),
      );
    }
  }
}
```

### Key Features

- **Try-catch blocks** around async operations
- **User-friendly SnackBar messages** on failures
- **Context.mounted checks** to prevent errors after widget disposal
- **Separate messages** for "can't launch" vs "error launching"

### Similar Implementation

The same pattern is used for:
- `_openWebsite()` - Website URL launches
- Both in `lib/screens/festival_info_screen.dart:225-270`

---

## User-Friendly Error Messages

**Status:** ✅ Completed
**Location:** `lib/providers/beer_provider.dart`
**Implemented:** 2025-11-30

### Error Message Translation

Technical exceptions are now converted to user-friendly messages before display.

**Implementation:**

```dart
String _getUserFriendlyErrorMessage(Object error) {
  if (error is BeerApiException) {
    if (error.statusCode == 404) {
      return 'Festival data not found. Please try a different festival.';
    } else if (error.statusCode != null && error.statusCode! >= 500) {
      return 'Server error. Please try again later.';
    } else if (error.statusCode != null && error.statusCode! >= 400) {
      return 'Could not load drinks. Please try again.';
    } else {
      return 'Could not load drinks. Please check your connection.';
    }
  } else if (error is FestivalServiceException) {
    if (error.statusCode == 404) {
      return 'Festival list not found. Please try again later.';
    } else if (error.statusCode != null && error.statusCode! >= 500) {
      return 'Server error. Please try again later.';
    } else {
      return 'Could not load festivals. Please check your connection.';
    }
  } else if (error is SocketException) {
    return 'No internet connection. Please check your network.';
  } else if (error is TimeoutException) {
    return 'Request timed out. Please check your connection and try again.';
  } else if (error is FormatException) {
    return 'Invalid data received. Please try again later.';
  } else {
    return 'Something went wrong. Please try again.';
  }
}
```

### Key Features

- **Exception type detection** - Different messages for different errors
- **HTTP status code handling** - 404, 4xx, 5xx get specific messages
- **Network errors** - SocketException, TimeoutException handled
- **Data errors** - FormatException handled
- **Fallback message** - Generic message for unknown errors

### Usage in Provider

```dart
try {
  _allDrinks = await _apiService.fetchAllDrinks(currentFestival);
  // ...
} catch (e) {
  _error = _getUserFriendlyErrorMessage(e); // Translates error
  // ...
}
```

### Before vs After

**Before:**
```
"BeerApiException: Failed to fetch beer: 500"
"SocketException: Connection refused"
```

**After:**
```
"Server error. Please try again later."
"No internet connection. Please check your network."
```

---

## Mobile UI Optimizations

**Status:** ✅ SliverAppBar completed
**Location:** `lib/screens/drinks_screen.dart`
**Implemented:** 2025-11-30

### SliverAppBar with Collapsing Behavior

The DrinksScreen now uses a collapsing app bar to save vertical space on mobile.

**Implementation:**

```dart
Widget build(BuildContext context) {
  final provider = context.watch<BeerProvider>();

  return Scaffold(
    body: Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.loadDrinks(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,  // Appears on scroll up
                  snap: true,      // Snaps in/out
                  title: _buildFestivalHeader(context, provider),
                ),
                // ... rest of content
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Key Features

- **`floating: true`** - AppBar reappears when scrolling up
- **`snap: true`** - Smooth snap-in/snap-out animation
- **Saves ~56px** of vertical space when scrolled down
- **CustomScrollView** with slivers for optimal performance

### User Experience

1. User scrolls down → AppBar hides, more content visible
2. User scrolls up slightly → AppBar immediately reappears
3. Smooth animations, no jarring transitions

### Additional Mobile Optimizations Pending

See [../todos.md](../todos.md) for remaining mobile UI items:
- #26: Collapsible festival info banner (40-50px savings)
- #27: Horizontal scrolling style chips (40-80px savings)
- #28: Reduced card density on mobile (20-30px per card)

---

## Detail Screen Layout Pattern

**Status:** ✅ Completed
**Location:** `lib/screens/drink_detail_screen.dart`, `lib/screens/brewery_screen.dart`, `lib/screens/style_screen.dart`
**Implemented:** 2025-12-14

### Overview

Detail screens (DrinkDetailScreen, BreweryScreen, StyleScreen) use a simplified SliverAppBar layout that avoids text overlap and provides a clean, consistent user experience.

### Layout Pattern

All detail screens follow this pattern:

```dart
Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverAppBar(
        expandedHeight: 200-220,  // Adjust based on content
        pinned: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        // NO title property - avoids overlap with header content
        actions: [/* action buttons */],
        flexibleSpace: FlexibleSpaceBar(
          background: SafeArea(
            child: _buildHeader(context, ...),
          ),
        ),
      ),
      // ... content slivers
    ],
  ),
)
```

### Key Design Principles

1. **No Title Duplication**: The SliverAppBar does NOT have a `title` property. The title is displayed only in the header within the FlexibleSpaceBar. This prevents text overlap when the app bar collapses.

2. **Fixed Expanded Heights**: 
   - DrinkDetailScreen: 200px
   - BreweryScreen: 220px
   - StyleScreen: 200px
   - Adjusted to fit header content without overflow

3. **Simplified Headers**: Headers are kept compact to fit within the expandedHeight:
   - Essential information only (name, key details)
   - Reduced spacing and padding
   - Smaller icon/avatar sizes when needed

4. **Consistent Structure**: All detail screens share the same overall structure, making the code easier to understand and maintain.

### Example: DrinkDetailScreen Header

```dart
Widget _buildHeader(BuildContext context, Drink drink) {
  final theme = Theme.of(context);
  // ... decorative elements ...
  
  return Container(
    // Gradient background with category accent
    child: Stack(
      children: [
        // Decorative background elements
        // Content in Padding widget
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,  // Important!
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(drink.name, style: headlineMedium),
              SelectableText(drink.breweryName, style: titleMedium),
              // ... minimal additional info ...
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Common Pitfalls to Avoid

❌ **Don't add title to SliverAppBar:**
```dart
SliverAppBar(
  title: Text(drink.name),  // This will overlap with header!
  flexibleSpace: FlexibleSpaceBar(
    background: _buildHeader(context, drink),
  ),
)
```

❌ **Don't make headers too tall:**
```dart
// This will cause overflow errors
Widget _buildHeader(...) {
  return Padding(
    padding: const EdgeInsets.all(32),  // Too much padding
    child: Column(
      children: [
        // 10+ lines of content  // Too much content
      ],
    ),
  );
}
```

✅ **Do keep headers compact:**
```dart
Widget _buildHeader(...) {
  return Padding(
    padding: const EdgeInsets.all(20),  // Moderate padding
    child: Column(
      mainAxisSize: MainAxisSize.min,  // Don't take more space than needed
      children: [
        // 3-5 essential pieces of info
      ],
    ),
  );
}
```

### Future Refactoring Opportunities

The three detail screens share a common pattern. Potential improvements:

1. **Extract common SliverAppBar configuration** into a reusable widget or helper
2. **Create a DetailScreenScaffold widget** that encapsulates the common structure
3. **Standardize header styling** with shared theme tokens or constants
4. **Abstract decorative elements** (gradients, background shapes) into reusable components

However, keep each screen's unique identity and specific information display requirements in mind when refactoring.

---

## Testing

### Current Test Coverage

**Widget Tests:**
- ✅ `test/widgets_test.dart` - StarRating widget (complete)
- ❌ Screen widget tests - Not yet implemented

**Unit Tests:**
- ✅ `test/models_test.dart` - Data models
- ✅ `test/services_test.dart` - API service, storage
- ✅ `test/provider_test.dart` - BeerProvider state management

**Integration Tests:**
- ❌ Not yet implemented

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/services_test.dart

# Run tests with semantics enabled (for a11y)
flutter test --enable-semantics
```

### Test Structure

```
test/
├── models_test.dart           # Model JSON parsing, validation
├── services_test.dart         # API calls, storage operations
├── provider_test.dart         # State management, filtering
├── provider_test.mocks.dart   # Generated mocks (Mockito)
├── widgets_test.dart          # StarRating widget
└── beer_api_service_test.dart # API service detailed tests
```

### Adding New Tests

See [CLAUDE.md](../CLAUDE.md) Testing Requirements section for:
- Test file location conventions
- How to add widget tests
- Integration test setup (when implemented)

---

## Development Workflow

### Before Making Changes

1. **Read CLAUDE.md** - Project instructions and code style
2. **Check todos.md** - Verify task status
3. **Run tests** - Ensure baseline passes
4. **Run analyzer** - `flutter analyze --no-fatal-infos`

### After Making Changes

1. **Run analyzer** - `flutter analyze --no-fatal-infos`
2. **Run tests** - `flutter test`
3. **Update documentation** - If adding features
4. **Update todos.md** - Mark items complete
5. **Commit with clear message**

### Code Style

See [CLAUDE.md](../CLAUDE.md) Code Style Checklist for:
- Single quotes for strings
- `const` constructors where possible
- `final` for local variables
- Accessibility requirements (Semantics widgets)
- Large text testing

---

## Next Steps for Development

Based on [../todos.md](../todos.md), prioritize in this order:

### Phase 1: Complete Critical Fixes
- ❌ Remove localhost from production CORS (#4)

### Phase 2: Testing & Accessibility
- ⚠️ Complete widget tests for all screens (#2)
- ❌ Implement accessibility (Semantics) (#6) - See [ACCESSIBILITY.md](ACCESSIBILITY.md)
- ❌ Add retry logic for API calls (#8)
- ❌ Add keys to ListView items (#9)

### Phase 3: Monitoring & Polish
- ❌ Add Firebase Crashlytics/Analytics (#10)
- ❌ Add integration tests (#5)
- ❌ Improve test coverage to 70%+ (#14)

See full implementation order in [../todos.md](../todos.md).

---

## Useful Links

- [Main Project Instructions](../CLAUDE.md) - AI coding guidelines
- [TODO List](../todos.md) - All pending and completed tasks
- [Accessibility Guide](ACCESSIBILITY.md) - How to implement a11y
- [API Documentation](api/README.md) - API schemas and endpoints

---

## Questions or Issues?

If you encounter issues with implemented features:

1. Check this document for implementation details
2. Review test files for usage examples
3. Check [../todos.md](../todos.md) for known issues
4. Run tests to verify functionality

For new feature development, always check [CLAUDE.md](../CLAUDE.md) first for project guidelines.
