# Deep Linking Implementation Plan

## Overview

This document provides a detailed, step-by-step implementation plan for adding festival-scoped deep linking to the Cambridge Beer Festival app.

## Design Summary

### URL Structure

**Before (Current):**
```
/                    → Drinks list (implicit festival)
/drink/{id}          → Drink detail
/brewery/{id}        → Brewery detail
/style/{name}        → Style-filtered drinks
/festival-info       → Festival info
/favorites           → Favorites
/about               → About app
```

**After (Festival-Scoped):**
```
/                              → Redirects to /{currentFestivalId}
/{festivalId}                  → Festival drinks list
/{festivalId}/drink/{id}       → Drink detail
/{festivalId}/brewery/{id}     → Brewery detail
/{festivalId}/style/{name}     → Style-filtered drinks
/{festivalId}/category/{name}  → Category-filtered drinks (NEW)
/{festivalId}/info             → Festival info (was /festival-info)
/{festivalId}/favorites        → Favorites for this festival
/about                         → About app (global)
```

### Key Decisions

- ✅ Festival IDs are user-friendly slugs (`cbf2025`, `cbfw2025`)
- ✅ Festival at root of URL path
- ✅ Category URLs enabled
- ✅ Style URLs enabled (existing, needs festival scope)
- ✅ Root `/` redirects to last-selected/current festival
- ✅ Breadcrumbs are clickable (except current page)
- ✅ No backwards compatibility needed (pre-v1)

## Implementation Phases

### Phase 1: Foundation (No Code Changes Yet)

#### 1.1 Create Navigation Helper Utilities

**File:** `lib/utils/navigation_helpers.dart` (NEW)

**Purpose:** Centralized URL building functions to ensure consistency

**Functions to create:**
```dart
// Build festival-scoped URLs
String buildFestivalUrl(String festivalId) => '/$festivalId';

String buildDrinkUrl(String festivalId, String drinkId) =>
    '/$festivalId/drink/$drinkId';

String buildBreweryUrl(String festivalId, String breweryId) =>
    '/$festivalId/brewery/$breweryId';

String buildStyleUrl(String festivalId, String styleName) =>
    '/$festivalId/style/${Uri.encodeComponent(styleName)}';

String buildCategoryUrl(String festivalId, String categoryName) =>
    '/$festivalId/category/${Uri.encodeComponent(categoryName)}';

String buildFestivalInfoUrl(String festivalId) =>
    '/$festivalId/info';

String buildFavoritesUrl(String festivalId) =>
    '/$festivalId/favorites';

// About is global, no festival scope
String buildAboutUrl() => '/about';
```

**Additional helper:**
```dart
// Get current festival ID from provider
String getCurrentFestivalId(BuildContext context) {
  final provider = context.read<BeerProvider>();
  return provider.currentFestival.id;
}
```

**Export:** Add to `lib/utils/utils.dart` (create if needed)

---

### Phase 2: New Screens

#### 2.1 Create CategoryScreen

**File:** `lib/screens/category_screen.dart` (NEW)

**Purpose:** Show drinks filtered by category (beer, cider, perry, etc.)

**Implementation notes:**
- Similar to `StyleScreen` structure
- Takes `category` and `festivalId` parameters
- Shows category header with stats (drink count, avg ABV)
- Lists all drinks in that category
- Includes breadcrumbs: `Festival > Category: Beer`

**Key features:**
- SliverAppBar with category name
- Category-specific color/icon (reuse existing category colors from drinks_screen.dart)
- Drink cards with navigation to drink detail
- Home button if can't pop
- Analytics event for category viewed

**Barrel export:** Add to `lib/screens/screens.dart`:
```dart
export 'category_screen.dart';
```

---

### Phase 3: Router Updates

#### 3.1 Update Router Configuration

**File:** `lib/router.dart`

**Changes needed:**

1. **Add root redirect:**
   ```dart
   GoRoute(
     path: '/',
     redirect: (context, state) {
       final provider = context.read<BeerProvider>();
       return '/${provider.currentFestival.id}';
     },
   ),
   ```

2. **Wrap existing routes with festival scope:**
   ```dart
   // Parent shell still initializes provider
   ShellRoute(
     builder: (context, state, child) => ProviderInitializer(child: child),
     routes: [
       // Festival-scoped routes
       GoRoute(
         path: '/:festivalId',
         routes: [
           // Nested routes for main screens with bottom nav
           ShellRoute(
             builder: (context, state, child) => BeerFestivalHome(child: child),
             routes: [
               GoRoute(
                 path: '',  // /{festivalId}
                 pageBuilder: (context, state) => NoTransitionPage(
                   child: DrinksScreen(
                     festivalId: state.pathParameters['festivalId']!,
                   ),
                 ),
               ),
               GoRoute(
                 path: 'favorites',  // /{festivalId}/favorites
                 pageBuilder: (context, state) => NoTransitionPage(
                   child: FavoritesScreen(
                     festivalId: state.pathParameters['festivalId']!,
                   ),
                 ),
               ),
             ],
           ),
           // Detail routes without bottom nav
           GoRoute(
             path: 'drink/:drinkId',
             builder: (context, state) => DrinkDetailScreen(
               festivalId: state.pathParameters['festivalId']!,
               drinkId: state.pathParameters['drinkId']!,
             ),
           ),
           GoRoute(
             path: 'brewery/:breweryId',
             builder: (context, state) => BreweryScreen(
               festivalId: state.pathParameters['festivalId']!,
               breweryId: state.pathParameters['breweryId']!,
             ),
           ),
           GoRoute(
             path: 'style/:name',
             builder: (context, state) {
               final name = Uri.decodeComponent(state.pathParameters['name']!);
               return StyleScreen(
                 festivalId: state.pathParameters['festivalId']!,
                 style: name,
               );
             },
           ),
           GoRoute(
             path: 'category/:name',  // NEW
             builder: (context, state) {
               final name = Uri.decodeComponent(state.pathParameters['name']!);
               return CategoryScreen(
                 festivalId: state.pathParameters['festivalId']!,
                 category: name,
               );
             },
           ),
           GoRoute(
             path: 'info',
             builder: (context, state) => FestivalInfoScreen(
               festivalId: state.pathParameters['festivalId']!,
             ),
           ),
         ],
       ),
       // Global routes (no festival scope)
       GoRoute(
         path: '/about',
         builder: (context, state) => const AboutScreen(),
       ),
     ],
   ),
   ```

---

### Phase 4: Screen Updates

#### 4.1 Update Screen Constructors

**All screens need to accept `festivalId` parameter:**

1. **DrinksScreen** (`lib/screens/drinks_screen.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - No major logic changes (provider already manages festival)

2. **FavoritesScreen** (`lib/main.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - Could validate that provider's current festival matches URL

3. **DrinkDetailScreen** (`lib/screens/drink_detail_screen.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - Use for breadcrumbs

4. **BreweryScreen** (`lib/screens/brewery_screen.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - Use for breadcrumbs

5. **StyleScreen** (`lib/screens/style_screen.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - Use for breadcrumbs

6. **FestivalInfoScreen** (`lib/screens/festival_info_screen.dart`)
   - Add `final String festivalId;` field
   - Add to constructor
   - Could validate/switch festival if different from provider

---

#### 4.2 Update Navigation Calls

**Files with `context.go()` calls:**

1. **lib/main.dart**
   - Bottom navigation bar (Drinks, Favorites)
   - Update to use navigation helpers
   ```dart
   // Before:
   if (index == 0) context.go('/');
   if (index == 1) context.go('/favorites');

   // After:
   final festivalId = getCurrentFestivalId(context);
   if (index == 0) context.go(buildFestivalUrl(festivalId));
   if (index == 1) context.go(buildFavoritesUrl(festivalId));
   ```

2. **lib/screens/drinks_screen.dart**
   - Drink card navigation
   - Festival info button
   - About button
   ```dart
   // Drink card - Before:
   onTap: () => context.go('/drink/${drink.id}')

   // After:
   onTap: () => context.go(buildDrinkUrl(widget.festivalId, drink.id))

   // Info button - Before:
   context.go('/festival-info')

   // After:
   context.go(buildFestivalInfoUrl(widget.festivalId))
   ```

3. **lib/screens/drink_detail_screen.dart**
   - Brewery link
   ```dart
   // Before:
   onTap: () => context.go('/brewery/${drink.producer.id}')

   // After:
   onTap: () => context.go(buildBreweryUrl(widget.festivalId, drink.producer.id))
   ```

4. **lib/screens/brewery_screen.dart**
   - Drink card navigation
   - Home button
   ```dart
   // Drink card - Before:
   onTap: () => context.go('/drink/${drink.id}')

   // After:
   onTap: () => context.go(buildDrinkUrl(widget.festivalId, drink.id))

   // Home button - Before:
   onPressed: () => context.go('/')

   // After:
   onPressed: () => context.go(buildFestivalUrl(widget.festivalId))
   ```

5. **lib/screens/style_screen.dart**
   - Drink card navigation
   - Home button
   ```dart
   // Same changes as brewery_screen.dart
   ```

---

### Phase 5: Breadcrumbs

#### 5.1 Create BreadcrumbBar Widget

**File:** `lib/widgets/breadcrumb_bar.dart` (NEW)

**Purpose:** Show navigation context and provide clickable navigation

**Interface:**
```dart
class BreadcrumbBar extends StatelessWidget {
  final String festivalId;
  final List<BreadcrumbItem> items;

  const BreadcrumbBar({
    super.key,
    required this.festivalId,
    required this.items,
  });
}

class BreadcrumbItem {
  final String label;
  final String? url;  // null = current page (not clickable)

  const BreadcrumbItem({
    required this.label,
    this.url,
  });
}
```

**Visual design:**
- Horizontal layout with chevron separators (›)
- Clickable items: Primary color, underlined on hover
- Current item: Regular text color, not clickable
- Responsive: Truncate long names with ellipsis
- Semantic labels for screen readers

**Example usage:**
```dart
BreadcrumbBar(
  festivalId: festivalId,
  items: [
    BreadcrumbItem(
      label: provider.currentFestival.name,
      url: buildFestivalUrl(festivalId),
    ),
    BreadcrumbItem(
      label: drink.producer.name,
      url: buildBreweryUrl(festivalId, drink.producer.id),
    ),
    BreadcrumbItem(
      label: drink.name,
      url: null,  // Current page
    ),
  ],
)
```

**Barrel export:** Add to `lib/widgets/widgets.dart`:
```dart
export 'breadcrumb_bar.dart';
```

---

#### 5.2 Add Breadcrumbs to Screens

**DrinkDetailScreen:**
```dart
// Add below AppBar, above main content
BreadcrumbBar(
  festivalId: widget.festivalId,
  items: [
    BreadcrumbItem(
      label: provider.currentFestival.name,
      url: buildFestivalUrl(widget.festivalId),
    ),
    BreadcrumbItem(
      label: drink.producer.name,
      url: buildBreweryUrl(widget.festivalId, drink.producer.id),
    ),
    BreadcrumbItem(
      label: drink.name,
      url: null,
    ),
  ],
)
```

**BreweryScreen:**
```dart
BreadcrumbBar(
  festivalId: widget.festivalId,
  items: [
    BreadcrumbItem(
      label: provider.currentFestival.name,
      url: buildFestivalUrl(widget.festivalId),
    ),
    BreadcrumbItem(
      label: producer.name,
      url: null,
    ),
  ],
)
```

**StyleScreen:**
```dart
BreadcrumbBar(
  festivalId: widget.festivalId,
  items: [
    BreadcrumbItem(
      label: provider.currentFestival.name,
      url: buildFestivalUrl(widget.festivalId),
    ),
    BreadcrumbItem(
      label: 'Style: ${widget.style}',
      url: null,
    ),
  ],
)
```

**CategoryScreen:**
```dart
BreadcrumbBar(
  festivalId: widget.festivalId,
  items: [
    BreadcrumbItem(
      label: provider.currentFestival.name,
      url: buildFestivalUrl(widget.festivalId),
    ),
    BreadcrumbItem(
      label: 'Category: ${widget.category}',
      url: null,
    ),
  ],
)
```

---

### Phase 6: Filter Button Updates

#### 6.1 Update Category Filter Button

**File:** `lib/screens/drinks_screen.dart`

**Current behavior:** Opens modal, sets category filter in provider

**New behavior:** Navigate to category URL instead of modal

```dart
// Before:
onPressed: () => _showCategoryFilter(context, provider)

// After:
onPressed: () {
  // Navigate to category URL when a category is selected
  // Could still show modal to choose, then navigate
  // OR: Show modal with categories, each navigates on tap
}
```

**Modal update:**
```dart
void _showCategoryFilter(BuildContext context, BeerProvider provider) {
  // Show modal with category options
  // When user taps a category:
  context.go(buildCategoryUrl(widget.festivalId, categoryName));
}
```

---

### Phase 7: Testing & Validation

#### 7.1 Update Screenshot Tests

**File:** `screenshots.config.json`

**Update all URLs to festival-scoped format:**
```json
[
  {
    "path": "/cbf2025",
    "name": "home"
  },
  {
    "path": "/cbf2025/brewery/[brewery-id]",
    "name": "brewery-detail"
  },
  {
    "path": "/cbf2025/drink/[drink-id]",
    "name": "drink-detail"
  },
  {
    "path": "/cbf2025/style/IPA",
    "name": "style-ipa"
  },
  {
    "path": "/cbf2025/category/beer",
    "name": "category-beer"
  },
  {
    "path": "/cbf2025/info",
    "name": "festival-info"
  },
  {
    "path": "/cbf2025/favorites",
    "name": "favorites"
  },
  {
    "path": "/about",
    "name": "about"
  }
]
```

**Note:** Will need to use real IDs from test data for brewery/drink detail screenshots.

---

#### 7.2 Manual Testing Checklist

**Deep Link Tests:**
- [ ] `/` redirects to current festival (e.g., `/cbf2025`)
- [ ] `/{festivalId}` shows drinks list for that festival
- [ ] `/{festivalId}/drink/{id}` shows correct drink detail
- [ ] `/{festivalId}/brewery/{id}` shows correct brewery
- [ ] `/{festivalId}/style/{name}` shows filtered drinks
- [ ] `/{festivalId}/category/{name}` shows filtered drinks
- [ ] `/{festivalId}/info` shows festival info
- [ ] `/{festivalId}/favorites` shows favorites
- [ ] `/about` shows about page (global)

**Breadcrumb Tests:**
- [ ] Breadcrumbs appear on all detail pages
- [ ] Festival name is clickable, goes to `/{festivalId}`
- [ ] Producer name is clickable (on drink detail), goes to brewery
- [ ] Current page item is NOT clickable
- [ ] Breadcrumbs work with screen readers (semantic labels)

**Navigation Tests:**
- [ ] Bottom nav (Drinks/Favorites) preserves festival context
- [ ] All drink cards navigate to correct festival-scoped detail
- [ ] Back button works correctly from all screens
- [ ] Home button (on detail screens) goes to correct festival home

**Festival Switching Tests:**
- [ ] Switching festival updates URL
- [ ] URL stays consistent across app navigation
- [ ] Last-selected festival is remembered on app restart
- [ ] Deep links to different festival than last-selected work correctly

---

#### 7.3 Code Quality Checks

**Run before committing:**
```bash
# Check for issues
flutter analyze --no-fatal-infos

# Run tests
flutter test

# Build web to verify no compile errors
flutter build web --release --base-href "/cambridge-beer-festival-app/"
```

**Check for:**
- No analyzer warnings
- All tests pass
- No hardcoded URLs (use navigation helpers)
- Consistent parameter naming (`festivalId`, `drinkId`, etc.)
- Proper use of `const` constructors
- Barrel exports updated

---

## Files to Create

1. `lib/utils/navigation_helpers.dart` - URL building utilities
2. `lib/utils/utils.dart` - Barrel export for utils (if doesn't exist)
3. `lib/screens/category_screen.dart` - Category filter screen
4. `lib/widgets/breadcrumb_bar.dart` - Breadcrumb navigation widget

## Files to Modify

1. `lib/router.dart` - Add festival-scoped routes, root redirect
2. `lib/main.dart` - Update FavoritesScreen, bottom nav
3. `lib/screens/drinks_screen.dart` - Add festivalId param, update navigation, filter button
4. `lib/screens/drink_detail_screen.dart` - Add festivalId param, breadcrumbs
5. `lib/screens/brewery_screen.dart` - Add festivalId param, breadcrumbs, update navigation
6. `lib/screens/style_screen.dart` - Add festivalId param, breadcrumbs, update navigation
7. `lib/screens/festival_info_screen.dart` - Add festivalId param
8. `lib/screens/screens.dart` - Export CategoryScreen
9. `lib/widgets/widgets.dart` - Export BreadcrumbBar
10. `screenshots.config.json` - Update test URLs

## Potential Challenges & Solutions

### Challenge 1: Festival ID Validation

**Problem:** What if someone enters an invalid festival ID in the URL?

**Solution:**
- Add validation in route redirect
- If festival not found, redirect to current/default festival
- Log analytics event for invalid festival attempts

### Challenge 2: Provider Festival Mismatch

**Problem:** URL says `cbf2024` but provider is on `cbf2025`

**Solution:**
- Router updates provider's festival on navigation
- Add guard in ProviderInitializer to sync festival from URL
- Consider: `provider.setFestivalFromUrl(festivalId)`

### Challenge 3: Breadcrumb Long Names

**Problem:** Festival or brewery names might be too long

**Solution:**
- Use `Expanded` with `overflow: TextOverflow.ellipsis`
- Consider abbreviating on small screens
- Show full name in tooltip on hover

### Challenge 4: Bottom Nav Festival Context

**Problem:** Bottom nav needs to know current festival ID

**Solution:**
- Extract festival ID from current route using GoRouter
- `GoRouterState.of(context).pathParameters['festivalId']`
- Fallback to provider's current festival if not in URL

### Challenge 5: Analytics Events

**Problem:** Need to update analytics to include festival context

**Solution:**
- Add `festivalId` parameter to all analytics events
- Update AnalyticsService methods to accept festival ID
- Track festival-specific engagement

## Migration Strategy

### Phase 1: Development
1. Implement all changes on feature branch
2. Test thoroughly locally
3. Update all documentation

### Phase 2: Testing
1. Deploy to test environment
2. Verify all deep links work
3. Test festival switching
4. Check analytics

### Phase 3: Deployment
1. Merge to main
2. Deploy to production
3. Update any external links (marketing materials, etc.)
4. Monitor for broken link reports

### Post-Deployment
1. Old URLs will break (acceptable per decision)
2. Monitor analytics for 404s
3. Consider adding generic 404 page with link to festival selector

## Success Criteria

- [ ] All routes are festival-scoped
- [ ] Root `/` redirects to current festival
- [ ] Breadcrumbs show on all detail pages
- [ ] Category filter has dedicated route
- [ ] All navigation uses helper functions
- [ ] No hardcoded URLs in code
- [ ] All tests pass
- [ ] No analyzer warnings
- [ ] Screenshot tests updated and passing
- [ ] Manual testing checklist completed
- [ ] Documentation updated

## Timeline Estimate

**Phase 1 (Foundation):** 1 hour
- Create navigation helpers
- Create barrel exports

**Phase 2 (New Screens):** 2 hours
- Create CategoryScreen
- Test and style

**Phase 3 (Router):** 2 hours
- Update router configuration
- Add festival validation
- Test routing logic

**Phase 4 (Screen Updates):** 3 hours
- Update all screen constructors
- Update all navigation calls
- Test each screen

**Phase 5 (Breadcrumbs):** 3 hours
- Create BreadcrumbBar widget
- Add to all detail screens
- Style and test

**Phase 6 (Filters):** 1 hour
- Update category filter button
- Test navigation

**Phase 7 (Testing):** 2 hours
- Update screenshot config
- Run full test suite
- Manual testing

**Total:** ~14 hours

## Architecture Discussion: Screen Unification

### Problem

Many screens (DrinkDetail, Brewery, Style, Category) share similar patterns:
- SliverAppBar with custom header
- Breadcrumbs
- Home button logic (`_canPop()`)
- List of drink cards
- Similar layout structure

This leads to code duplication and maintenance overhead.

### Options

#### Option 1: Base Screen Widget (Abstract Class)

Create an abstract base class with common functionality:

```dart
abstract class DetailScreen extends StatefulWidget {
  final String festivalId;

  const DetailScreen({super.key, required this.festivalId});

  // Subclasses implement these
  Widget buildHeader(BuildContext context);
  List<Drink> getDrinks(BeerProvider provider);
  List<BreadcrumbItem> getBreadcrumbs(BeerProvider provider);
}
```

**Pros:**
- Clear contract for detail screens
- Enforces consistency
- DRY for common logic

**Cons:**
- Inheritance can be limiting
- Not Flutter's idiomatic approach
- Hard to customize when needs diverge

#### Option 2: Composition with Shared Widgets (RECOMMENDED)

Create reusable widget components that screens compose:

```dart
// Shared header widget
class DetailScreenHeader extends StatelessWidget {
  final String title;
  final Widget decorativeContent;
  final List<Widget> stats;
  // ...
}

// Shared scaffold
class DetailScreenScaffold extends StatelessWidget {
  final String festivalId;
  final Widget header;
  final List<BreadcrumbItem> breadcrumbs;
  final List<Drink> drinks;
  final BeerProvider provider;
  // ...
}
```

Screens use composition:
```dart
class BreweryScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return DetailScreenScaffold(
      festivalId: widget.festivalId,
      breadcrumbs: [/* ... */],
      header: DetailScreenHeader(/* ... */),
      drinks: breweryDrinks,
      provider: provider,
    );
  }
}
```

**Pros:**
- Flutter's preferred approach (composition over inheritance)
- Flexible - screens can customize or skip widgets
- Easy to test individual components
- Can mix and match components

**Cons:**
- Requires careful API design
- More files to manage

#### Option 3: Screen Template Widget

Single widget that handles entire screen layout:

```dart
class DetailScreenTemplate extends StatelessWidget {
  final String festivalId;
  final String title;
  final Widget Function(BuildContext) headerBuilder;
  final List<Drink> drinks;
  final List<BreadcrumbItem> breadcrumbs;
  // ... many parameters
}
```

**Pros:**
- Maximum DRY
- Single source of truth for layout

**Cons:**
- Parameter explosion
- Hard to customize edge cases
- Less flexible than composition

#### Option 4: Hybrid Approach

Combination of composition + helper mixins:

```dart
// Mixin for common screen behavior
mixin DetailScreenBehavior<T extends StatefulWidget> on State<T> {
  bool canPop(BuildContext context) { /* ... */ }
  void navigateHome(BuildContext context, String festivalId) { /* ... */ }
}

// Reusable widgets for composition
class DetailScreenLayout extends StatelessWidget {
  final Widget header;
  final Widget breadcrumbs;
  final Widget content;
  // ...
}
```

**Pros:**
- Best of both worlds
- Mixins for behavior, widgets for UI
- Flexible and DRY

**Cons:**
- More complex architecture
- Steeper learning curve

### Recommendation: Option 2 (Composition)

**Why:**
1. **Flutter-idiomatic:** Composition is Flutter's preferred pattern
2. **Flexible:** Screens can use what they need, customize the rest
3. **Testable:** Each widget can be tested independently
4. **Maintainable:** Clear separation of concerns
5. **Incremental adoption:** Can refactor gradually

**Shared Components to Create:**

1. **DetailScreenLayout** - Common scaffold with SliverAppBar, breadcrumbs, content
2. **DetailHeader** - Reusable header with decorations, stats, gradients
3. **ScreenBreadcrumbs** - Already planned as BreadcrumbBar
4. **HomeButton** - Reusable home button with can-pop logic
5. **DrinkList** - Reusable list of drink cards (already exists as multiple cards)

**Migration Strategy:**

1. **Phase 1:** Create shared widgets alongside existing screens
2. **Phase 2:** Update new CategoryScreen to use shared widgets
3. **Phase 3:** Gradually refactor existing screens (StyleScreen, BreweryScreen, etc.)
4. **Phase 4:** Remove duplicated code from old screens

**Example Structure:**

```
lib/widgets/
├── breadcrumb_bar.dart           # ✅ Already planned
├── detail_screen_layout.dart     # NEW: Common layout scaffold
├── detail_screen_header.dart     # NEW: Reusable header widget
├── home_button.dart              # NEW: Home button with can-pop logic
└── drink_list_sliver.dart        # NEW: Reusable drink list
```

**Implementation in Phase 5.5 (Optional, After Phase 5):**

If time permits, add this phase between breadcrumbs and filters:

**Phase 5.5: Screen Component Refactoring**
1. Create DetailScreenLayout widget
2. Create DetailScreenHeader widget
3. Create HomeButton widget
4. Update CategoryScreen to use new widgets
5. Document pattern for future refactoring of other screens

**Benefits:**
- New CategoryScreen uses best practices from day 1
- Establishes pattern for future refactoring
- Reduces duplication incrementally
- Doesn't block initial deep linking implementation

### Decision Needed

Should we include Phase 5.5 (screen component refactoring) in this implementation, or defer to a separate refactoring task?

**Option A:** Include now (adds ~3 hours)
- Cleaner result
- Sets good foundation
- More work upfront

**Option B:** Defer to separate task (recommended)
- Get deep linking working first
- Refactor separately with proper testing
- Allows for iteration on component API

## Next Steps

1. Review this implementation plan
2. **Decide:** Include screen refactoring (Phase 5.5) or defer?
3. Get approval for approach
4. Begin Phase 1 (Foundation)
5. Commit incrementally after each phase
6. Test thoroughly before moving to next phase
