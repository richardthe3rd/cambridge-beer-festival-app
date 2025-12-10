# Deep Linking Design Document

## Overview

This document outlines the design for festival-scoped deep linking in the Cambridge Beer Festival app.

## Design Decisions

### Festival ID Format
- ✅ User-friendly slugs (`cbf2025`, `cbfw2025`, `cbf2024`)
- Already implemented in `Festival.id` field

### URL Structure
- Festival-scoped URLs with festival ID at root: `/{festivalId}/...`
- Clean, short URLs that clearly show festival context

### Data Assumptions
- Drink IDs are globally unique across all festivals
- Producer IDs are globally unique across all festivals
- Data does NOT support cross-festival consistent IDs (same real-world drink at multiple festivals = different IDs)

### User Experience
- Last selected festival is remembered (existing behavior preserved)
- Default to current/most recent festival if no saved selection
- Breadcrumbs show context: `Festival > Producer > Drink`
- Breadcrumbs are clickable navigation (except current page)

### Backwards Compatibility
- ❌ No backwards compatibility required (not v1 yet)
- Old URLs like `/drink/123` will break
- Fresh start with new URL structure

## Proposed URL Structure

### Core Routes

```
/{festivalId}                          → Festival home (drinks list, no filters)
/{festivalId}/favorites                → Favorites for this festival
/{festivalId}/drink/{drinkId}          → Drink detail page
/{festivalId}/brewery/{breweryId}      → Brewery detail + drinks at this festival
/{festivalId}/info                     → Festival info page (shareable!)
/{festivalId}/style/{styleName}        → Drinks filtered by style
```

### Pending Routes (User Decision Required)

```
/{festivalId}/category/{categoryName}  → Drinks filtered by category (Q4)
/{festivalId}/search?q={query}         → Search results (Q4)
/                                      → Root behavior (Q6: redirect? selector?)
/about                                 → About app (global, not festival-specific)
```

### Example URLs

```
https://yourapp.com/cbf2025
  → CBF 2025 drinks list

https://yourapp.com/cbf2025/drink/abc123
  → Specific drink at CBF 2025

https://yourapp.com/cbf2025/brewery/brew456
  → Brewery details and their drinks at CBF 2025

https://yourapp.com/cbf2025/info
  → CBF 2025 festival info (dates, location, website) - now shareable!

https://yourapp.com/cbf2025/style/IPA
  → All IPAs at CBF 2025

https://yourapp.com/cbf2025/favorites
  → User's favorite drinks from CBF 2025
```

## Breadcrumb Navigation

### Structure

```
Festival Name > Producer Name > Drink Name
               └─ Clickable   └─ Current page (not clickable)
└─ Clickable
```

### Examples

**On Drink Detail Page:**
```
Cambridge Beer Festival 2025 > Oakham Ales > Citra
[Clickable: /cbf2025]      [Clickable: /cbf2025/brewery/oakham-ales-id]  [Current page]
```

**On Brewery Detail Page:**
```
Cambridge Beer Festival 2025 > Oakham Ales
[Clickable: /cbf2025]      [Current page]
```

**On Style Page:**
```
Cambridge Beer Festival 2025 > Style: IPA
[Clickable: /cbf2025]      [Current page]
```

## Implementation Plan

### Phase 1: Core Routing (Essential)

1. **Update Router Configuration** (`lib/router.dart`)
   - Add festival parameter to all routes
   - Implement nested routing structure
   - Add redirect from `/` to `/{currentFestivalId}`

2. **Update Navigation Calls** (5 files)
   - `lib/main.dart` - Bottom nav, favorites link
   - `lib/screens/drinks_screen.dart` - Drink card navigation
   - `lib/screens/drink_detail_screen.dart` - Brewery link
   - `lib/screens/brewery_screen.dart` - Drink cards
   - `lib/screens/style_screen.dart` - Drink cards, home button

3. **Create Navigation Helper**
   - Utility functions to build festival-scoped URLs
   - Example: `buildDrinkUrl(festivalId, drinkId) => '/$festivalId/drink/$drinkId'`

### Phase 2: Breadcrumbs (High Priority)

1. **Create BreadcrumbBar Widget** (`lib/widgets/breadcrumb_bar.dart`)
   - Show context path (Festival > Producer > Drink)
   - Clickable navigation (except current page)
   - Responsive design (collapse on small screens?)

2. **Add Breadcrumbs to Screens**
   - Drink detail screen
   - Brewery detail screen
   - Style screen
   - Category screen (if implemented)

### Phase 3: Festival Info Shareability

1. **Update FestivalInfoScreen Route**
   - Change from `/festival-info` to `/{festivalId}/info`
   - Update navigation links

2. **Test Shareability**
   - Verify deep links work correctly
   - Test with different festivals

### Phase 4: Category Routes (Optional, Q4 Dependent)

1. **Add Category Route** (`/{festivalId}/category/{categoryName}`)
   - Create CategoryScreen or reuse DrinksScreen with filter
   - Update category filter buttons to navigate

2. **Add Search Route** (Optional)
   - `/{festivalId}/search?q={query}`
   - Update search bar to update URL

### Phase 5: Testing

1. **Update Screenshot Tests**
   - Update `screenshots.config.json` with new URL structure
   - Test all festival-scoped deep links

2. **Manual Testing**
   - Test all navigation flows
   - Test breadcrumb clicks
   - Test direct deep links (copy/paste URLs)
   - Test festival switching behavior

## Files to Modify

### Critical Files (Phase 1)

- `lib/router.dart` - Route definitions
- `lib/main.dart` - Bottom nav, home route
- `lib/screens/drinks_screen.dart` - Drink navigation
- `lib/screens/drink_detail_screen.dart` - Brewery link
- `lib/screens/brewery_screen.dart` - Drink navigation, home button
- `lib/screens/style_screen.dart` - Drink navigation, home button
- `lib/screens/festival_info_screen.dart` - Update route

### New Files (Phase 2)

- `lib/widgets/breadcrumb_bar.dart` - Breadcrumb widget
- `lib/utils/navigation_helpers.dart` - URL building helpers

### Test Files

- `screenshots.config.json` - Update test URLs
- Add widget tests for breadcrumbs

## Open Questions

### Q4: Navigation Elements - Which should have URLs?

**Category filters:**
- `/{festivalId}/category/beer` - Filter to show only beers
- Pros: Shareable links, better SEO
- Cons: Adds complexity

**Style filters:**
- `/{festivalId}/style/IPA` - Already exists, just needs festival scope
- Status: **Approved**

**Search:**
- `/{festivalId}/search?q=hoppy` - Show search results
- Pros: Shareable searches
- Cons: Search is often transient, not frequently shared

**Sort order:**
- `/{festivalId}?sort=abv` - Sort drinks by ABV
- Pros: Preserve user preference in URL
- Cons: Usually not shared, local preference

### Q6: Root `/` Behavior

**Option A: Redirect to last-selected festival**
- `/` → `/cbf2025` (current/last-selected festival)
- Preserves existing "remember last festival" behavior
- User never sees `/`, immediately redirected

**Option B: Festival selector page**
- Shows list of all festivals at `/`
- User clicks one to go to `/{festivalId}`
- Requires new screen

**Option C: Always redirect to "current" festival**
- `/` → `/cbf2025` (live/upcoming/most recent festival)
- Ignores saved preference
- Always shows the most relevant festival

## Migration Notes

### Breaking Changes

Old URL structure (current):
```
/drink/{id}
/brewery/{id}
/style/{name}
/festival-info
/favorites
```

New URL structure:
```
/{festivalId}/drink/{id}
/{festivalId}/brewery/{id}
/{festivalId}/style/{name}
/{festivalId}/info
/{festivalId}/favorites
```

### No Backwards Compatibility

- App is not v1 yet, breaking changes acceptable
- Old shared links will stop working
- Users will need to share new links going forward

## Benefits of This Design

1. **Festival Context in URLs** - Clear which festival each drink/brewery is from
2. **Shareable Festival Info** - `/{festivalId}/info` can be shared
3. **Better Deep Linking** - Every screen has a unique, meaningful URL
4. **Cleaner Architecture** - Festival scope is explicit, not implicit
5. **Better Analytics** - Can track which festivals get the most traffic
6. **Future-Proof** - Easy to add more festivals over time

## Potential Challenges

1. **URL Length** - URLs are longer than before (but still reasonable)
2. **Navigation Updates** - Many files need updating (but manageable)
3. **Testing** - More URL patterns to test
4. **Documentation** - Need to update all docs with new URLs

## Next Steps

1. User answers Q4 and Q6
2. Create implementation plan with specific tasks
3. Update router.dart with new structure
4. Update navigation calls across all screens
5. Create breadcrumb widget
6. Test thoroughly with screenshots and manual testing
