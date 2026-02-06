# Phase 1 Handoff - Festival Linking Implementation

**Date:** December 2024
**Phase 0 Status:** ✅ Complete
**Branch:** `claude/festival-linking-phase-zero-k3Rpl`

---

## 🎯 What's Ready

Phase 0 has established a **solid foundation** for Phase 1 festival linking implementation:

### ✅ Navigation Utilities

**File:** `lib/utils/navigation_helpers.dart`

All helper functions for building festival-scoped URLs are implemented and tested:

```dart
// Available functions (all with URL encoding):
buildFestivalPath(festivalId, path)      // Base URL builder
buildFestivalHome(festivalId)            // /{festivalId}
buildDrinksPath(festivalId, {category})  // /{festivalId}/drinks
buildDrinkDetailPath(festivalId, drinkId)  // /{festivalId}/drink/{drinkId}
buildBreweryPath(festivalId, breweryId)  // /{festivalId}/brewery/{breweryId}
buildStylePath(festivalId, styleName)    // /{festivalId}/style/{name}
buildCategoryPath(festivalId, category)  // /{festivalId}/category/{name}

// URL parsing functions:
extractFestivalId(path)  // Extract festival ID from path (see limitations)
isFestivalPath(path)     // Check if path is festival-scoped
```

**Import:** `import 'package:cambridge_beer_festival/utils/utils.dart';`

**Key Features:**
- ✅ Automatic URL encoding (special characters, Unicode, spaces)
- ✅ Input validation with assertions (debug mode)
- ✅ Handles edge cases (empty strings, long paths, multiple slashes)
- ✅ 39 comprehensive tests (100% coverage)

**Important Limitations:**
- `extractFestivalId()` returns first path segment but **cannot validate** if it's a real festival ID
- Validation against festival registry must be done in Phase 1 routing logic

### ✅ BreadcrumbBar Widget

**File:** `lib/widgets/breadcrumb_bar.dart`

Ready-to-use navigation widget for detail screens:

```dart
import 'package:cambridge_beer_festival/widgets/widgets.dart';

// Simple breadcrumb
BreadcrumbBar(
  backLabel: 'Beer',
  onBack: () => context.pop(),
)

// With context (show parent)
BreadcrumbBar(
  backLabel: 'Beer',
  contextLabel: 'Oakham Ales',  // Note: renamed from 'context'
  onBack: () => context.pop(),
)
```

**Key Features:**
- ✅ Accessible (Semantics only on interactive IconButton)
- ✅ Text overflow handling (single line with ellipsis)
- ✅ Large touch target (48x48 minimum)
- ✅ Tooltip on hover
- ✅ 10 widget tests (100% coverage)

**Breaking Change Note:**
- Parameter renamed from `context` to `contextLabel` to avoid BuildContext confusion

### ✅ Documentation

**Navigation Guide:** [`docs/navigation.md`](../../../navigation.md)
- URL structure and patterns
- Helper function usage examples
- URL encoding strategy
- Input validation rules
- Parsing limitations

**UI Components:** [`docs/ui-components.md`](../../../ui-components.md)
- BreadcrumbBar usage and examples
- Accessibility requirements
- When to use / when not to use

**Widget Standards:** [`docs/code/widget-standards.md`](../../code/widget-standards.md)
- Text selectability (SelectableText vs Text)
- Accessibility requirements (Semantics, WCAG AA)
- Widget patterns and best practices
- Testing requirements
- Code style guidelines

### ✅ Quality Assurance

**Tests:** 49 tests total
- 39 navigation helper tests
- 10 BreadcrumbBar widget tests
- **100% coverage** for all new code
- All edge cases tested

**Analyzer:** Zero issues
**CI/CD:** All checks passing

---

## 🚀 Phase 1 Implementation Guide

### What Phase 1 Needs to Do

**Goal:** Integrate festival-scoped URLs into the app routing and navigation

**Key Tasks:**

1. **Update Router** (`lib/router.dart`)
   - Add festival ID path parameter to routes
   - Use navigation helpers for route building
   - Add festival validation against registry
   - Handle invalid festival IDs (redirect to current festival)

2. **Update Screens** (all screens that take festival-scoped URLs)
   - Add `festivalId` parameter to constructors
   - Use navigation helpers for building links
   - Integrate BreadcrumbBar widget on detail screens

3. **Update Navigation** (throughout app)
   - Replace hard-coded URLs with navigation helper calls
   - Pass festival ID to all navigation calls

4. **Festival Validation**
   - Load festival registry at app startup
   - Validate festival IDs from URLs
   - Redirect invalid festival IDs

5. **Testing**
   - Update existing navigation tests
   - Add festival-scoped navigation tests
   - Test invalid festival ID handling

### Using Navigation Helpers

**Pattern to follow throughout Phase 1:**

```dart
// OLD (Phase 0 and before):
context.go('/drink/$drinkId');

// NEW (Phase 1):
import 'package:cambridge_beer_festival/utils/utils.dart';

final festivalId = /* get from context/provider */;
context.go(buildDrinkDetailPath(festivalId, drinkId));
```

**Get festival ID from provider:**

```dart
// In widgets with access to context:
final provider = context.read<BeerProvider>();
final festivalId = provider.currentFestival.id;

// Then use helpers:
context.go(buildDrinksPath(festivalId));
```

### Integrating BreadcrumbBar

**Pattern for detail screens:**

```dart
import 'package:cambridge_beer_festival/widgets/widgets.dart';

// In detail screen build method:
BreadcrumbBar(
  backLabel: 'Drinks',  // Where to go back to
  contextLabel: drink.name,  // Optional: current item name
  onBack: () {
    if (context.canPop()) {
      context.pop();
    } else {
      // Can't pop, go to festival home
      context.go(buildFestivalHome(festivalId));
    }
  },
)
```

### Festival Validation Pattern

**Phase 1 needs to implement this logic:**

```dart
// Pseudocode for router validation
GoRoute(
  path: '/:festivalId',
  redirect: (context, state) {
    final festivalId = state.pathParameters['festivalId'];
    final provider = context.read<BeerProvider>();

    // Check if festival ID is valid
    if (!provider.isValidFestivalId(festivalId)) {
      // Redirect to current/default festival
      return '/${provider.currentFestival.id}';
    }

    return null; // No redirect, festival is valid
  },
  // ... rest of route config
)
```

---

## 📋 Phase 1 Checklist

Before starting Phase 1:
- [ ] Read [`docs/planning/deep-linking/implementation-plan.md`](implementation-plan.md)
- [ ] Review [`docs/planning/deep-linking/phase-0-guide.md`](phase-0-guide.md) completion summary
- [ ] Read [`docs/navigation.md`](../../../navigation.md) - navigation helper usage
- [ ] Read [`docs/ui-components.md`](../../../ui-components.md) - BreadcrumbBar usage
- [ ] Understand URL encoding strategy (all IDs are encoded)
- [ ] Understand `extractFestivalId` limitations (cannot validate against registry)

During Phase 1:
- [ ] Use navigation helpers for ALL URL building
- [ ] Add festival validation in router
- [ ] Integrate BreadcrumbBar on detail screens
- [ ] Update all screens to accept `festivalId` parameter
- [ ] Test festival switching (different festivals, different URLs)
- [ ] Test invalid festival ID handling
- [ ] Ensure all existing tests still pass
- [ ] Add new tests for festival-scoped navigation

After Phase 1:
- [ ] All routes are festival-scoped
- [ ] Deep links work (can share URLs to specific festivals)
- [ ] Invalid festival IDs redirect gracefully
- [ ] BreadcrumbBar integrated on detail screens
- [ ] All tests passing
- [ ] Documentation updated

---

## 🐛 Known Issues and Gotchas

### extractFestivalId Limitation

**Issue:** `extractFestivalId('/drinks')` returns `'drinks'` as a potential festival ID

**Why:** The function cannot distinguish between a festival ID and a page name without the festival registry

**Solution:** Phase 1 must validate against the festival registry after extraction:

```dart
final potentialId = extractFestivalId(path);
if (potentialId != null && provider.isValidFestivalId(potentialId)) {
  // It's a real festival ID
} else {
  // Not a festival ID, redirect to default
}
```

### BreadcrumbBar Parameter Rename

**Breaking Change:** `context` parameter renamed to `contextLabel`

**Reason:** Avoids confusion with Flutter's `BuildContext context`

**Update any references:**
```dart
// OLD:
BreadcrumbBar(context: 'Item Name', ...)

// NEW:
BreadcrumbBar(contextLabel: 'Item Name', ...)
```

### URL Encoding

**All IDs are automatically encoded** - don't encode them manually:

```dart
// ✅ GOOD:
buildDrinkDetailPath('cbf2025', 'drink with spaces')
// Returns: /cbf2025/drink/drink%20with%20spaces

// ❌ BAD:
final encoded = Uri.encodeComponent('drink with spaces');
buildDrinkDetailPath('cbf2025', encoded)
// Returns: /cbf2025/drink/drink%2520with%2520spaces (double encoded!)
```

---

## 📚 Reference Files

**Planning Documents:**
- [`implementation-plan.md`](implementation-plan.md) - Full Phase 1-4 implementation plan
- [`phase-0-guide.md`](phase-0-guide.md) - Phase 0 completion details
- [`design.md`](design.md) - Design decisions and rationale
- [`testing-strategy.md`](testing-strategy.md) - Testing approach

**Code Documentation:**
- [`docs/navigation.md`](../../../navigation.md) - Navigation utilities
- [`docs/ui-components.md`](../../../ui-components.md) - UI component guide
- [`docs/code/widget-standards.md`](../../code/widget-standards.md) - Widget standards
- [`docs/code/accessibility.md`](../../code/accessibility.md) - Accessibility guide

**Implementation Files:**
- `lib/utils/navigation_helpers.dart` - Navigation helper functions
- `lib/widgets/breadcrumb_bar.dart` - BreadcrumbBar widget
- `test/utils/navigation_helpers_test.dart` - Navigation tests
- `test/widgets/breadcrumb_bar_test.dart` - BreadcrumbBar tests

---

## ✅ Summary

**Phase 0 Completed:**
- ✅ Navigation helpers with URL encoding
- ✅ BreadcrumbBar widget
- ✅ Comprehensive tests (49 tests, 100% coverage)
- ✅ Complete documentation
- ✅ Zero analyzer issues
- ✅ CI/CD passing

**Ready for Phase 1:**
- ✅ Solid foundation with no technical debt
- ✅ All utilities tested and documented
- ✅ Clear integration patterns established
- ✅ Widget standards documented

**Next Steps:**
1. Start Phase 1 implementation (router updates)
2. Use navigation helpers for all URL building
3. Integrate BreadcrumbBar on detail screens
4. Add festival validation logic
5. Test thoroughly

---

**Questions?** See [`phase-0-guide.md`](phase-0-guide.md) FAQ section or review the planning documents.

**Last Updated:** December 2024
**Phase 0 Branch:** `claude/festival-linking-phase-zero-k3Rpl`
