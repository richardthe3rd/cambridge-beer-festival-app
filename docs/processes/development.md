# Development Guide

Developer documentation for the Cambridge Beer Festival app - implementation details and completed features.

## Table of Contents

- [Recently Implemented Features](#recently-implemented-features)
- [HTTP Request Timeouts](#http-request-timeouts)
- [Error Handling](#error-handling)
- [User-Friendly Error Messages](#user-friendly-error-messages)
- [Mobile UI Optimizations](#mobile-ui-optimizations)
- [Reusable Screen Components](#reusable-screen-components)
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
5. EntityDetailScreen reusable component

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

## Reusable Screen Components

**Status:** ✅ Completed
**Location:** `lib/widgets/entity_detail_screen.dart`
**Implemented:** 2025-12-14

### EntityDetailScreen - Generic Detail Screen Pattern

The `EntityDetailScreen` widget provides a reusable layout pattern for detail screens that display a filtered list of drinks (e.g., BreweryScreen, StyleScreen). This refactoring extracted common code from similar screens, reducing duplication and making it easier to create new detail screens.

**Implementation:**

```dart
class EntityDetailScreen extends StatefulWidget {
  final String title;
  final String notFoundMessage;
  final String notFoundTitle;
  final double expandedHeight;
  final List<Drink> Function(List<Drink> allDrinks) filterDrinks;
  final Widget Function(BuildContext context, List<Drink> drinks) buildHeader;
  final Future<void> Function()? logAnalytics;

  const EntityDetailScreen({
    required this.title,
    required this.notFoundMessage,
    required this.notFoundTitle,
    required this.expandedHeight,
    required this.filterDrinks,
    required this.buildHeader,
    this.logAnalytics,
  });
}
```

### Common Elements Extracted

The widget provides the following shared functionality:

1. **Loading State** - Shows loading indicator while data is being fetched
2. **Not Found State** - Displays message when no drinks match the filter
3. **SliverAppBar Layout** - Collapsible header with customizable expanded height
4. **Navigation** - Home button when can't pop, back button otherwise
5. **Analytics** - Optional analytics logging via callback
6. **Drink List** - Filtered DrinkCard list with favorite toggle
7. **Theme Support** - Uses primaryContainer color scheme

### Usage Examples

**BreweryScreen:**

```dart
EntityDetailScreen(
  title: producer.name,
  notFoundTitle: 'Brewery Not Found',
  notFoundMessage: 'This brewery could not be found.',
  expandedHeight: 244,
  filterDrinks: (allDrinks) =>
      allDrinks.where((d) => d.producer.id == breweryId).toList(),
  buildHeader: (context, drinks) {
    final producer = drinks.first.producer;
    return _buildBreweryHeader(context, producer, drinks.length);
  },
  logAnalytics: () async {
    await provider.analyticsService.logBreweryViewed(producer.name);
  },
)
```

**StyleScreen:**

```dart
EntityDetailScreen(
  title: style,
  notFoundTitle: 'Style Not Found',
  notFoundMessage: 'No drinks found for this style.',
  expandedHeight: 220,
  filterDrinks: (allDrinks) =>
      allDrinks.where((d) => d.style == style).toList(),
  buildHeader: (context, drinks) {
    final avgAbv = drinks.fold(0.0, (sum, d) => sum + d.abv) / drinks.length;
    return _buildStyleHeader(context, style, drinks.length, avgAbv);
  },
  logAnalytics: () async {
    await provider.analyticsService.logStyleViewed(style);
  },
)
```

### Benefits

- **Code Reuse** - Eliminated ~100 lines of duplicated code per screen
- **Consistency** - Ensures all detail screens follow the same UX pattern
- **Maintainability** - Bug fixes in EntityDetailScreen benefit all screens
- **Flexibility** - Builder pattern allows customization of header content
- **Type Safety** - Strong typing for filter and header builder functions

### Screen-Specific Customization

Each screen maintains its unique header design while sharing the common layout:

- **BreweryScreen** - Shows brewery initials, location, year founded, drink count
- **StyleScreen** - Shows style initial, drink count, average ABV statistics

Future detail screens (e.g., by category, region) can easily reuse this pattern.

---

## Testing

### Current Test Coverage

**Widget Tests:**
- ✅ `test/widgets_test.dart` - StarRating widget (complete)
- ✅ `test/brewery_screen_test.dart` - BreweryScreen (9 tests)
- ✅ `test/style_screen_test.dart` - StyleScreen (8 tests)

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
