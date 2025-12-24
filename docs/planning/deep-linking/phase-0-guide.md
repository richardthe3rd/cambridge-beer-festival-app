# Phase 0: Foundation - Implementation Guide

**Status:** ✅ **COMPLETE** (December 2024)

## 📋 Overview

**Duration:** 2-3 hours
**Risk Level:** ⚠️ LOW (no existing code modified)
**Dependencies:** None
**Blocks:** Phase 1 (Festival Linking)

---

## 🎯 Aims

**Primary Goal:** Create reusable utilities and components for festival-scoped navigation **without modifying any existing code**.

**Why This Phase Matters:**
- Builds the foundation for festival-scoped URLs (Phase 1)
- Tests the development workflow (mise, testing, CI/CD)
- Validates the implementation plan with low-risk changes
- Creates components that will be integrated later

**What This Phase Does NOT Do:**
- Does not change any routes or navigation
- Does not modify any existing screens
- Does not change user-facing behavior
- Does not add festival linking yet (that's Phase 1)

---

## 📦 Deliverables

### Task 0.1: Navigation Helper Utilities

**File to create:** `lib/utils/navigation_helpers.dart`

**What to build:**
```dart
/// Navigation utilities for festival-scoped routing.
///
/// Provides helper functions to build festival-scoped URLs consistently
/// throughout the app. These will be used in Phase 1 when routes are updated.
library;

/// Builds a festival-scoped URL path.
///
/// Example:
/// ```dart
/// buildFestivalPath('cbf2025', '/drinks') // Returns: '/cbf2025/drinks'
/// buildFestivalPath('cbf2025', '/brewery/123') // Returns: '/cbf2025/brewery/123'
/// ```
String buildFestivalPath(String festivalId, String path) {
  // Ensure path starts with /
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return '/$festivalId$cleanPath';
}

/// Builds a festival home URL.
///
/// Example:
/// ```dart
/// buildFestivalHome('cbf2025') // Returns: '/cbf2025'
/// ```
String buildFestivalHome(String festivalId) {
  return '/$festivalId';
}

/// Builds a drinks list URL for a festival.
///
/// Example:
/// ```dart
/// buildDrinksPath('cbf2025') // Returns: '/cbf2025/drinks'
/// buildDrinksPath('cbf2025', category: 'beer') // Returns: '/cbf2025/drinks?category=beer'
/// ```
String buildDrinksPath(String festivalId, {String? category}) {
  final base = buildFestivalPath(festivalId, '/drinks');
  if (category != null) {
    return '$base?category=$category';
  }
  return base;
}

/// Builds a drink detail URL.
///
/// Example:
/// ```dart
/// buildDrinkDetailPath('cbf2025', 'drink-123') // Returns: '/cbf2025/drink/drink-123'
/// ```
String buildDrinkDetailPath(String festivalId, String drinkId) {
  return buildFestivalPath(festivalId, '/drink/$drinkId');
}

/// Builds a brewery detail URL.
///
/// Example:
/// ```dart
/// buildBreweryPath('cbf2025', 'brewery-123') // Returns: '/cbf2025/brewery/brewery-123'
/// ```
String buildBreweryPath(String festivalId, String breweryId) {
  return buildFestivalPath(festivalId, '/brewery/$breweryId');
}

/// Builds a style detail URL.
///
/// Example:
/// ```dart
/// buildStylePath('cbf2025', 'IPA') // Returns: '/cbf2025/style/IPA'
/// ```
String buildStylePath(String festivalId, String style) {
  // URL-encode the style name to handle special characters
  final encodedStyle = Uri.encodeComponent(style);
  return buildFestivalPath(festivalId, '/style/$encodedStyle');
}

/// Builds a category URL.
///
/// Example:
/// ```dart
/// buildCategoryPath('cbf2025', 'beer') // Returns: '/cbf2025/category/beer'
/// ```
String buildCategoryPath(String festivalId, String category) {
  return buildFestivalPath(festivalId, '/category/$category');
}

/// Extracts festival ID from a festival-scoped path.
///
/// Example:
/// ```dart
/// extractFestivalId('/cbf2025/drinks') // Returns: 'cbf2025'
/// extractFestivalId('/invalid') // Returns: null
/// ```
String? extractFestivalId(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isNotEmpty ? segments.first : null;
}

/// Checks if a path is festival-scoped.
///
/// Example:
/// ```dart
/// isFestivalPath('/cbf2025/drinks') // Returns: true
/// isFestivalPath('/drinks') // Returns: false
/// ```
bool isFestivalPath(String path) {
  return extractFestivalId(path) != null;
}
```

**Export in barrel file:** Update `lib/utils/utils.dart`:
```dart
export 'navigation_helpers.dart';
```

**If `lib/utils/utils.dart` doesn't exist, create it:**
```dart
/// Utility functions for the Cambridge Beer Festival app.
library;

export 'navigation_helpers.dart';
```

**Unit tests to write:** `test/utils/navigation_helpers_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  group('Navigation Helpers', () {
    group('buildFestivalPath', () {
      test('builds path with leading slash', () {
        expect(
          buildFestivalPath('cbf2025', '/drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('builds path without leading slash', () {
        expect(
          buildFestivalPath('cbf2025', 'drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('handles nested paths', () {
        expect(
          buildFestivalPath('cbf2025', '/brewery/123'),
          equals('/cbf2025/brewery/123'),
        );
      });

      test('handles festival IDs with special characters', () {
        expect(
          buildFestivalPath('cbf-2025', '/drinks'),
          equals('/cbf-2025/drinks'),
        );
      });
    });

    group('buildFestivalHome', () {
      test('builds home path', () {
        expect(
          buildFestivalHome('cbf2025'),
          equals('/cbf2025'),
        );
      });
    });

    group('buildDrinksPath', () {
      test('builds drinks path without category', () {
        expect(
          buildDrinksPath('cbf2025'),
          equals('/cbf2025/drinks'),
        );
      });

      test('builds drinks path with category', () {
        expect(
          buildDrinksPath('cbf2025', category: 'beer'),
          equals('/cbf2025/drinks?category=beer'),
        );
      });
    });

    group('buildDrinkDetailPath', () {
      test('builds drink detail path', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink-123'),
          equals('/cbf2025/drink/drink-123'),
        );
      });

      test('handles drink IDs with special characters', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'drink-123-abc'),
          equals('/cbf2025/drink/drink-123-abc'),
        );
      });
    });

    group('buildBreweryPath', () {
      test('builds brewery path', () {
        expect(
          buildBreweryPath('cbf2025', 'brewery-123'),
          equals('/cbf2025/brewery/brewery-123'),
        );
      });
    });

    group('buildStylePath', () {
      test('builds style path', () {
        expect(
          buildStylePath('cbf2025', 'IPA'),
          equals('/cbf2025/style/IPA'),
        );
      });

      test('URL-encodes style names with spaces', () {
        expect(
          buildStylePath('cbf2025', 'American IPA'),
          equals('/cbf2025/style/American%20IPA'),
        );
      });

      test('URL-encodes style names with special characters', () {
        expect(
          buildStylePath('cbf2025', 'Barrel-Aged Stout'),
          equals('/cbf2025/style/Barrel-Aged%20Stout'),
        );
      });
    });

    group('buildCategoryPath', () {
      test('builds category path', () {
        expect(
          buildCategoryPath('cbf2025', 'beer'),
          equals('/cbf2025/category/beer'),
        );
      });
    });

    group('extractFestivalId', () {
      test('extracts festival ID from simple path', () {
        expect(
          extractFestivalId('/cbf2025/drinks'),
          equals('cbf2025'),
        );
      });

      test('extracts festival ID from nested path', () {
        expect(
          extractFestivalId('/cbf2025/brewery/123'),
          equals('cbf2025'),
        );
      });

      test('extracts festival ID from home path', () {
        expect(
          extractFestivalId('/cbf2025'),
          equals('cbf2025'),
        );
      });

      test('returns null for root path', () {
        expect(
          extractFestivalId('/'),
          isNull,
        );
      });

      test('returns null for empty path', () {
        expect(
          extractFestivalId(''),
          isNull,
        );
      });

      test('handles paths without leading slash', () {
        expect(
          extractFestivalId('cbf2025/drinks'),
          equals('cbf2025'),
        );
      });
    });

    group('isFestivalPath', () {
      test('returns true for festival-scoped paths', () {
        expect(isFestivalPath('/cbf2025/drinks'), isTrue);
        expect(isFestivalPath('/cbf2025/brewery/123'), isTrue);
        expect(isFestivalPath('/cbf2025'), isTrue);
      });

      test('returns false for non-festival paths', () {
        expect(isFestivalPath('/'), isFalse);
        expect(isFestivalPath(''), isFalse);
      });
    });
  });
}
```

**Documentation to write:** Add to `docs/navigation.md` (create new):
```markdown
# Navigation Utilities

This document describes the navigation helper utilities used throughout the app.

## Festival-Scoped URLs

All app URLs are scoped to a specific festival. This allows:
- Deep linking to specific festivals
- Viewing historical festival data
- Switching between multiple festivals

## URL Structure

```
/{festivalId}/{path}
```

Examples:
- `/cbf2025` - Festival home
- `/cbf2025/drinks` - Drinks list
- `/cbf2025/drink/123` - Drink detail
- `/cbf2025/brewery/456` - Brewery detail
- `/cbf2025/style/IPA` - Style detail
- `/cbf2025/category/beer` - Category page

## Helper Functions

See `lib/utils/navigation_helpers.dart` for all helper functions.

### Building URLs

```dart
import 'package:cambridge_beer_festival/utils/utils.dart';

// Build festival home URL
final homeUrl = buildFestivalHome('cbf2025'); // '/cbf2025'

// Build drinks URL
final drinksUrl = buildDrinksPath('cbf2025'); // '/cbf2025/drinks'
final beerUrl = buildDrinksPath('cbf2025', category: 'beer'); // '/cbf2025/drinks?category=beer'

// Build detail URLs
final drinkUrl = buildDrinkDetailPath('cbf2025', drink.id);
final breweryUrl = buildBreweryPath('cbf2025', brewery.id);
final styleUrl = buildStylePath('cbf2025', 'IPA');
```

### Parsing URLs

```dart
// Extract festival ID from path
final festivalId = extractFestivalId('/cbf2025/drinks'); // 'cbf2025'

// Check if path is festival-scoped
if (isFestivalPath(path)) {
  // Handle festival-scoped navigation
}
```

## Testing

All navigation helpers have 100% test coverage in `test/utils/navigation_helpers_test.dart`.
```

---

### Task 0.2: Breadcrumb Bar Widget

**File to create:** `lib/widgets/breadcrumb_bar.dart`

**What to build:**
```dart
import 'package:flutter/material.dart';

/// A navigation breadcrumb bar for detail screens.
///
/// Shows a back button with context text (e.g., "Beer / Oakham Ales").
/// Optimized for mobile with large touch targets.
///
/// Example usage:
/// ```dart
/// BreadcrumbBar(
///   backLabel: 'Beer',
///   context: 'Oakham Ales',
///   onBack: () => Navigator.pop(context),
/// )
/// ```
class BreadcrumbBar extends StatelessWidget {
  /// Creates a breadcrumb bar.
  const BreadcrumbBar({
    required this.backLabel,
    required this.onBack,
    this.context,
    super.key,
  });

  /// Label for the back button (e.g., "Beer", "Drinks").
  final String backLabel;

  /// Optional context text (e.g., brewery name, style name).
  final String? context;

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final contextText = this.context;

    return Semantics(
      label: 'Back to $backLabel',
      button: true,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Large back button
            IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              tooltip: 'Back to $backLabel',
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
            // Context text
            Expanded(
              child: ExcludeSemantics(
                // Already announced in parent Semantics
                child: Text(
                  contextText != null
                      ? '$backLabel / $contextText'
                      : backLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Export in barrel file:** Update `lib/widgets/widgets.dart`:
```dart
export 'breadcrumb_bar.dart';
```

**Widget tests to write:** `test/widgets/breadcrumb_bar_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

void main() {
  group('BreadcrumbBar', () {
    testWidgets('renders back button and label', (tester) async {
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => backPressed = true,
            ),
          ),
        ),
      );

      // Find back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Find label text
      expect(find.text('Beer'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backPressed, isTrue);
    });

    testWidgets('renders with context text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              context: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find combined text
      expect(find.text('Beer / Oakham Ales'), findsOneWidget);
    });

    testWidgets('handles long text with ellipsis', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // Constrain width to force overflow
              child: BreadcrumbBar(
                backLabel: 'Beer',
                context: 'Very Long Brewery Name That Should Overflow',
                onBack: () {},
              ),
            ),
          ),
        ),
      );

      // Find text widget
      final textWidget = tester.widget<Text>(
        find.text('Beer / Very Long Brewery Name That Should Overflow'),
      );

      // Verify overflow behavior
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              context: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find Semantics widget
      final semantics = tester.widget<Semantics>(
        find.byType(Semantics).first,
      );

      // Verify semantic properties
      expect(semantics.properties.label, 'Back to Beer');
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('back button has tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find IconButton
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );

      // Verify tooltip
      expect(iconButton.tooltip, equals('Back to Beer'));
    });

    testWidgets('calls onBack when back button is pressed', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => callCount++,
            ),
          ),
        ),
      );

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(callCount, equals(1));

      // Tap again
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(callCount, equals(2));
    });
  });
}
```

**Documentation to write:** Add to `docs/ui-components.md` (create new):
```markdown
# UI Components

## BreadcrumbBar

A navigation breadcrumb bar for detail screens.

### Usage

```dart
import 'package:cambridge_beer_festival/widgets/widgets.dart';

// Simple breadcrumb (back to list)
BreadcrumbBar(
  backLabel: 'Beer',
  onBack: () => context.pop(),
)

// With context (show parent item)
BreadcrumbBar(
  backLabel: 'Beer',
  context: 'Oakham Ales',
  onBack: () => context.pop(),
)
```

### Accessibility

- Large touch target (48x48 minimum)
- Clear semantic label for screen readers
- Tooltip on back button
- Supports text scaling (no overflow)

### Design

- Material Design back arrow icon
- Context text with separator (/)
- Ellipsis for long text
- Consistent padding (8px)

### When to Use

Use `BreadcrumbBar` on:
- Drink detail screens (back to drinks list)
- Brewery detail screens (back to drinks list)
- Style detail screens (back to drinks list)

Do NOT use on:
- Home screen (no parent)
- Modal dialogs (use dialog close button)
- Settings screens (use AppBar back button)
```

---

## ✅ Definition of Done

### Code Quality

- [ ] All code follows style guide (single quotes, const, final)
- [ ] All public APIs have doc comments
- [ ] No analyzer warnings: `./bin/mise run analyze` passes
- [ ] All functions under 50 lines

### Testing

- [ ] Unit tests written for all navigation helpers
- [ ] Widget tests written for BreadcrumbBar
- [ ] All tests pass: `./bin/mise run test` passes
- [ ] Test coverage ≥95% for new code: `./bin/mise run coverage`

### Documentation

- [ ] `docs/navigation.md` created with usage examples
- [ ] `docs/ui-components.md` created with BreadcrumbBar guide
- [ ] All new files have file-level doc comments
- [ ] All public functions have doc comments with examples

### Integration

- [ ] `lib/utils/utils.dart` exports navigation helpers
- [ ] `lib/widgets/widgets.dart` exports BreadcrumbBar
- [ ] No existing code modified
- [ ] No import errors in project

### CI/CD

- [ ] All GitHub Actions workflows pass
- [ ] No new warnings in CI output
- [ ] Coverage report uploaded successfully

---

## 🎯 Success Criteria

### Functional Requirements

✅ **Navigation helpers work correctly:**
- `buildFestivalPath('cbf2025', '/drinks')` returns `/cbf2025/drinks`
- `extractFestivalId('/cbf2025/drinks')` returns `cbf2025`
- All helper functions handle edge cases (special characters, empty strings)

✅ **BreadcrumbBar renders correctly:**
- Back button is visible and tappable
- Label text displays correctly
- Context text displays with separator
- Long text truncates with ellipsis
- Semantic label is correct for screen readers

### Quality Requirements

✅ **Tests are comprehensive:**
- Navigation helpers: 15+ test cases covering all functions
- BreadcrumbBar: 6+ test cases covering rendering, interaction, accessibility
- All edge cases tested (empty, null, special characters, overflow)

✅ **Documentation is complete:**
- Usage examples for all helper functions
- When to use BreadcrumbBar
- Accessibility guidelines documented

### Non-Functional Requirements

✅ **No breaking changes:**
- All existing tests still pass
- No existing code modified
- App still runs and functions normally

✅ **Ready for Phase 1:**
- Navigation helpers can be imported and used
- BreadcrumbBar can be imported and used
- Team understands how to use new utilities

---

## 🧪 Testing Checklist

### Before Committing

Run these commands and ensure they all pass:

```bash
# 1. Code generation (if models changed - not needed for Phase 0)
./bin/mise run generate

# 2. Static analysis (MUST pass with 0 warnings)
./bin/mise run analyze

# 3. All tests (MUST pass with 0 failures)
./bin/mise run test

# 4. Coverage report (check new code is well-tested)
./bin/mise run coverage
```

### Manual Testing

Even though Phase 0 doesn't change the app, verify:

- [ ] App still compiles: `MISE_ENV=dev ./bin/mise run build:web`
- [ ] App still runs: `MISE_ENV=dev ./bin/mise run dev`
- [ ] No console errors on app launch
- [ ] Bottom nav still works
- [ ] Can still navigate to drink details

### Code Review Checklist

Before creating a PR:

- [ ] Read through all new code (do a self-review)
- [ ] Check all doc comments are clear and helpful
- [ ] Verify all tests are meaningful (not just 100% coverage)
- [ ] Ensure examples in docs actually work
- [ ] Check for typos in comments and docs

---

## 📊 Verification Steps

### Step 1: Verify Navigation Helpers

```bash
# Run just the navigation helpers tests
./bin/mise exec flutter -- flutter test test/utils/navigation_helpers_test.dart

# Expected: All tests pass (15+ tests)
```

**Manual verification:**
```dart
// In Dart DevTools or a test file, verify:
import 'package:cambridge_beer_festival/utils/utils.dart';

void main() {
  print(buildFestivalPath('cbf2025', '/drinks')); // Should print: /cbf2025/drinks
  print(extractFestivalId('/cbf2025/drinks'));    // Should print: cbf2025
  print(buildStylePath('cbf2025', 'American IPA')); // Should print: /cbf2025/style/American%20IPA
}
```

### Step 2: Verify BreadcrumbBar Widget

```bash
# Run just the breadcrumb tests
./bin/mise exec flutter -- flutter test test/widgets/breadcrumb_bar_test.dart

# Expected: All tests pass (6+ tests)
```

**Manual verification:**

Create a temporary test screen to see the widget:

```dart
// In a test file or temporary screen
import 'package:cambridge_beer_festival/widgets/widgets.dart';

class TestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Test BreadcrumbBar')),
      body: Column(
        children: [
          BreadcrumbBar(
            backLabel: 'Beer',
            onBack: () => print('Back pressed'),
          ),
          BreadcrumbBar(
            backLabel: 'Beer',
            context: 'Oakham Ales',
            onBack: () => print('Back pressed'),
          ),
        ],
      ),
    );
  }
}
```

**Expected visual result:**
- First breadcrumb shows: `← Beer`
- Second breadcrumb shows: `← Beer / Oakham Ales`
- Back buttons are large and tappable
- Text truncates if too long

### Step 3: Verify Documentation

```bash
# Check docs exist
ls docs/navigation.md
ls docs/ui-components.md

# Read docs and verify examples are correct
cat docs/navigation.md
cat docs/ui-components.md
```

**Verification:**
- [ ] All code examples in docs are valid Dart
- [ ] All imports in examples are correct
- [ ] Usage instructions are clear

### Step 4: Verify CI/CD

```bash
# Push to your branch
git add .
git commit -m "Phase 0: Add navigation helpers and breadcrumb widget"
git push origin claude/festival-linking-plan-N4Xqp

# Check GitHub Actions
# Navigate to: https://github.com/richardthe3rd/cambridge-beer-festival-app/actions
# Verify: All checks pass (analyze, test, build)
```

---

## 🚀 Ready for Phase 1?

After completing Phase 0, you should have:

✅ Navigation helper functions ready to use
✅ BreadcrumbBar widget ready to integrate
✅ Comprehensive tests (95%+ coverage)
✅ Clear documentation for team
✅ CI/CD pipeline passing
✅ Confidence in the development workflow

**What's next in Phase 1:**
- Update router with festival-scoped routes
- Add `festivalId` parameter to all screens
- Replace hardcoded URLs with navigation helpers
- Integrate BreadcrumbBar into detail screens

**Phase 0 → Phase 1 transition:**
- Phase 0 built the tools (helpers, widgets)
- Phase 1 uses the tools (integration)
- Clear separation makes Phase 1 easier and safer

---

## 📝 Commit Message Template

```
Phase 0: Add navigation helpers and breadcrumb widget

Add festival-scoped navigation utilities and breadcrumb bar widget
as foundation for Phase 1 festival linking implementation.

New features:
- Navigation helper functions for building festival URLs
- BreadcrumbBar widget for detail screen navigation
- Comprehensive unit and widget tests
- Documentation for navigation and UI components

No existing code modified. All tests pass.

Files added:
- lib/utils/navigation_helpers.dart
- lib/utils/utils.dart (barrel export)
- lib/widgets/breadcrumb_bar.dart
- test/utils/navigation_helpers_test.dart
- test/widgets/breadcrumb_bar_test.dart
- docs/navigation.md
- docs/ui-components.md

Test coverage: 100% for new code
```

---

## ❓ FAQ

**Q: Why create these utilities if they're not used yet?**
A: Phase 0 validates the approach with low risk. If there's a problem with the design, we discover it now before modifying any existing code.

**Q: Can I skip Phase 0 and go straight to Phase 1?**
A: Not recommended. Phase 0 builds confidence and validates the workflow. It's only 2-3 hours and makes Phase 1 much easier.

**Q: What if I want to change the navigation helper design?**
A: Perfect time to do it! Phase 0 is low-risk. Experiment with different APIs, naming, or structure. Get it right before Phase 1.

**Q: Do I need to update CLAUDE.md?**
A: Not yet. Wait until Phase 1 when the features are actually integrated and usable.

**Q: Should I create a PR for Phase 0?**
A: Yes! Create a small, focused PR. This validates the CI/CD pipeline and gets early feedback.

**Q: What if tests fail in CI but pass locally?**
A: This is why Phase 0 is valuable - it exposes environment issues early. Debug the CI failure now before Phase 1.

---

## ✅ Completion Summary

**Completed:** December 2024
**Branch:** `claude/festival-linking-phase-zero-k3Rpl`
**Commits:**
- `f8e1a62` - Phase 0: Add navigation helpers and breadcrumb widget
- `4ca8226` - Fix Phase 0: Address all critical issues and add comprehensive tests
- `de154a6` - Add widget coding standards documentation

**Deliverables:**

✅ **Navigation Helpers** (`lib/utils/navigation_helpers.dart`)
- All builder functions implemented with URL encoding
- Input validation with assertions
- Comprehensive edge case handling
- 39 unit tests (100% coverage)

✅ **BreadcrumbBar Widget** (`lib/widgets/breadcrumb_bar.dart`)
- Accessible navigation widget for detail screens
- Semantic labels only on interactive elements
- Proper text overflow handling
- 10 widget tests (100% coverage)

✅ **Documentation**
- `docs/navigation.md` - Navigation utilities guide
- `docs/ui-components.md` - BreadcrumbBar usage and accessibility
- `docs/code/widget-standards.md` - Widget coding standards (NEW)

✅ **Testing**
- 49 tests total (39 navigation helpers + 10 BreadcrumbBar)
- All tests passing
- Zero analyzer issues
- Edge cases covered: Unicode, special characters, empty strings, long strings

**Key Improvements from Expert Review:**
- Added URL encoding to all path builders (`Uri.encodeComponent`)
- Fixed BreadcrumbBar semantics anti-pattern (only IconButton wrapped)
- Renamed `context` parameter to `contextLabel` (avoid BuildContext shadowing)
- Added comprehensive input validation with assertions
- Documented limitations of `extractFestivalId` (cannot validate against registry)

**Ready for Phase 1:**
- ✅ Navigation helpers tested and documented
- ✅ BreadcrumbBar ready for integration
- ✅ Widget standards established
- ✅ Development workflow validated
- ✅ CI/CD pipeline passing
