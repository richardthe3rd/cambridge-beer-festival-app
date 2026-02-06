# Accessibility Guide

Comprehensive accessibility guidelines for the Cambridge Beer Festival app.

## Table of Contents

- [Overview](#overview)
- [Legal & Compliance Requirements](#legal--compliance-requirements)
- [Implementation Status](#implementation-status)
- [Quick Start Guide](#quick-start-guide)
- [Detailed Implementation Guide](#detailed-implementation-guide)
- [Testing Procedures](#testing-procedures)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Overview

**Accessibility is mandatory, not optional.** This app must be usable by everyone, including people with:
- Visual impairments (using screen readers)
- Motor impairments (using alternative input devices)
- Cognitive differences (requiring clear, simple interfaces)
- Hearing impairments (if audio is added)

### Why Accessibility Matters

1. **Legal Compliance** - Required by ADA, Section 508, and similar laws
2. **Ethical Responsibility** - Technology should be inclusive
3. **Better UX for Everyone** - Accessible design benefits all users
4. **Larger Audience** - ~15% of world population has some form of disability

---

## Legal & Compliance Requirements

### Standards We Must Meet

- ✅ **WCAG 2.1 Level AA** - Web Content Accessibility Guidelines (international standard)
- ✅ **ADA** - Americans with Disabilities Act (US legal requirement)
- ✅ **Section 508** - US Federal accessibility standards
- ✅ **EN 301 549** - European accessibility standard

### What Level AA Requires

1. **Perceivable**
   - Text alternatives for non-text content
   - Captions for audio/video
   - Content can be presented in different ways
   - Sufficient color contrast (4.5:1 for text)

2. **Operable**
   - All functionality available via keyboard
   - Users have enough time to read/use content
   - No content causes seizures
   - Users can navigate and find content

3. **Understandable**
   - Text is readable and understandable
   - Content appears and operates predictably
   - Help users avoid and correct mistakes

4. **Robust**
   - Content compatible with assistive technologies
   - Works across different devices/platforms

---

## Implementation Status

### Current Status: ✅ Implemented

**53+ `Semantics` widgets** are implemented across the app, with **9 dedicated accessibility tests** in `test/accessibility_test.dart`.

Coverage by file:
- ✅ `lib/widgets/drink_card.dart` -- card semantic labels, favorite button semantics
- ✅ `lib/screens/drinks_screen.dart` -- search clear button, filter chips
- ✅ `lib/screens/festival_info_screen.dart` -- map, website, and GitHub buttons
- ✅ `lib/main.dart` -- bottom navigation bar with descriptive labels for both tabs
- ✅ `lib/widgets/star_rating.dart` -- parent rating label, individual star semantics
- ✅ `lib/widgets/bottom_action_bar.dart` -- action button semantics
- ✅ `lib/widgets/breadcrumb_bar.dart` -- back navigation semantics
- ✅ `lib/widgets/overflow_menu.dart` -- menu button with `ExcludeSemantics` on decorative icons
- ✅ `lib/widgets/info_chip.dart` -- chip semantics
- ✅ `lib/widgets/festival_menu_sheets.dart` -- festival selector, settings, theme selector
- ✅ `lib/widgets/environment_badge.dart` -- environment indicator semantics
- ✅ `lib/screens/about_screen.dart` -- theme, GitHub, issues, licenses buttons
- ✅ `lib/screens/drink_detail_screen.dart` -- action buttons, brewery link

### Automated Tests

`test/accessibility_test.dart` verifies:
- Favorite button semantic labels (add/remove states)
- ABV chip `ExcludeSemantics` for decorative elements
- Card semantic structure and labels
- Environment badge semantics
- Button property (`button: true`) on interactive elements
- Hint instructions for screen reader users
- `ExcludeSemantics` usage on decorative icons
- Filter chip selection state announcements
- Retry button semantics on error states

---

## Quick Start Guide

### Adding Semantics to Your Widget

**Before:**
```dart
IconButton(
  icon: Icon(Icons.favorite),
  onPressed: () => toggleFavorite(),
)
```

**After:**
```dart
Semantics(
  label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
  button: true,
  hint: 'Double tap to toggle',
  child: IconButton(
    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
    onPressed: () => toggleFavorite(),
  ),
)
```

### Testing Your Changes

1. **Enable TalkBack (Android):**
   - Settings → Accessibility → TalkBack → Enable
   - Navigate with swipe gestures
   - Listen to announcements

2. **Enable VoiceOver (iOS):**
   - Settings → Accessibility → VoiceOver → Enable
   - Swipe to navigate
   - Verify all elements announce

3. **Test Large Text:**
   - Android: Settings → Display → Font size → Largest
   - iOS: Settings → Display & Brightness → Text Size → Largest
   - Ensure no text overflow or clipping

---

## Detailed Implementation Guide

### 1. Interactive Buttons (High Priority)

#### IconButtons

**Problem:** Icons don't convey meaning to screen readers.

**Solution:**
```dart
Semantics(
  label: 'Clear search query',
  button: true,
  child: IconButton(
    icon: Icon(Icons.close),
    onPressed: () => _clearSearch(),
  ),
)
```

**Key Points:**
- Use `label` to describe the action (not the icon)
- Set `button: true` to announce as a button
- Optionally add `hint` for usage instructions

#### Toggle Buttons

**For state-changing buttons (like favorites):**
```dart
Semantics(
  label: isFavorite
    ? 'Remove ${drink.name} from favorites'
    : 'Add ${drink.name} to favorites',
  button: true,
  toggled: isFavorite,
  child: IconButton(...),
)
```

**Key Points:**
- Label changes based on current state
- Use `toggled` property for toggle state
- Be specific - include what you're toggling

### 2. Filter Chips (High Priority)

**Problem:** Users don't know which filters are active.

**Solution:**
```dart
Semantics(
  label: 'Filter by $styleName',
  value: isSelected ? 'Selected' : 'Not selected',
  button: true,
  selected: isSelected,
  child: FilterChip(
    label: Text(styleName),
    selected: isSelected,
    onSelected: (value) => _toggleStyle(styleName),
  ),
)
```

**Key Points:**
- Use `value` to announce current state
- Set `selected` property for filter state
- Keep labels concise but descriptive

### 3. List Items (High Priority)

**Problem:** Screen readers read every element separately.

**Solution:**
```dart
Semantics(
  label: '${drink.name}, ${drink.abv}% ABV, brewed by ${drink.breweryName} from ${drink.breweryLocation}',
  hint: 'Double tap to view details',
  button: true,
  child: InkWell(
    onTap: () => _navigateToDetail(drink),
    child: DrinkCard(drink: drink),
  ),
)
```

**Alternative - Merge semantics inside the card:**
```dart
MergeSemantics(
  child: Column(
    children: [
      Text(drink.name),
      Text('${drink.abv}% ABV'),
      Text(drink.breweryName),
    ],
  ),
)
```

**Key Points:**
- Provide a concise summary of card content
- Add navigation hint for tappable items
- Balance detail vs brevity (3-5 key facts)

### 4. Star Ratings (High Priority)

**Problem:** Star icons meaningless to screen readers.

**Solution:**
```dart
Semantics(
  label: 'Rate ${drink.name}',
  value: rating > 0
    ? '$rating out of 5 stars'
    : 'Not rated',
  hint: 'Tap a star to set rating from 1 to 5',
  child: Row(
    children: List.generate(5, (index) {
      final starValue = index + 1;
      return Semantics(
        label: '$starValue stars',
        button: true,
        child: IconButton(
          icon: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
          ),
          onPressed: () => _setRating(starValue),
        ),
      );
    }),
  ),
)
```

**Key Points:**
- Parent Semantics announces overall rating
- Each star is individually tappable with label
- Include rating scale context (out of 5)

### 5. Navigation Bar (Medium Priority)

**Problem:** Icons alone don't describe destinations.

**Solution:**
```dart
NavigationBar(
  selectedIndex: _currentIndex,
  onDestinationSelected: (index) => setState(() => _currentIndex = index),
  destinations: [
    NavigationDestination(
      icon: Semantics(
        label: 'Drinks tab, browse festival drinks and search',
        excludeSemantics: true, // Prevent duplicate announcement
        child: Icon(Icons.local_bar),
      ),
      label: 'Drinks',
    ),
    NavigationDestination(
      icon: Semantics(
        label: 'Favorites tab, view saved drinks',
        excludeSemantics: true,
        child: Icon(Icons.favorite),
      ),
      label: 'Favorites',
    ),
  ],
)
```

**Key Points:**
- Describe what's in each tab, not just the label
- Use `excludeSemantics` on icon to prevent double-reading
- Keep descriptions action-oriented

### 6. Search Field (Medium Priority)

**Good news:** TextFields have built-in accessibility!

**Best practices:**
```dart
TextField(
  controller: _searchController,
  decoration: InputDecoration(
    labelText: 'Search', // ✅ Announced by screen reader
    hintText: 'Search drinks, breweries, styles...', // ✅ Read as hint
    prefixIcon: ExcludeSemantics( // ❌ Exclude decorative icon
      child: Icon(Icons.search),
    ),
    suffixIcon: Semantics(
      label: 'Clear search and close',
      button: true,
      child: IconButton(
        icon: Icon(Icons.close),
        onPressed: () => _clearSearch(),
      ),
    ),
  ),
  onChanged: (value) => _handleSearch(value),
)
```

**Key Points:**
- Use `labelText` or `hintText` for description
- Exclude decorative icons with `ExcludeSemantics`
- Add semantics to icon buttons inside decoration

### 7. Action Buttons (Medium Priority)

**For external actions (maps, websites):**
```dart
Semantics(
  label: 'Open ${festival.name} location in Google Maps',
  button: true,
  hint: 'Opens external app',
  child: ElevatedButton.icon(
    icon: Icon(Icons.map),
    label: Text('Open in Maps'),
    onPressed: () => _launchMaps(festival.latitude, festival.longitude),
  ),
)
```

**Key Points:**
- Describe the destination, not just the action
- Warn about external app launches
- Be specific about what opens

### 8. Sorting Dropdowns (Low Priority)

**Dropdowns have good built-in accessibility, but can improve:**
```dart
Semantics(
  label: 'Sort drinks',
  value: 'Currently sorted by $currentSort',
  child: DropdownButton<String>(
    value: sortOption,
    items: [
      DropdownMenuItem(
        value: 'name',
        child: Text('Name'),
      ),
      DropdownMenuItem(
        value: 'abv',
        child: Text('ABV'),
      ),
    ],
    onChanged: (value) => _updateSort(value),
  ),
)
```

---

## Testing Procedures

### Manual Testing Checklist

#### Pre-Testing Setup

- [ ] Install app on physical device (emulator acceptable for basic testing)
- [ ] Enable screen reader (TalkBack/VoiceOver)
- [ ] Disable screen (forces screen reader only navigation)

#### Test Scenarios

**1. Navigation Test**
- [ ] Launch app with screen reader enabled
- [ ] Swipe through all elements on home screen
- [ ] Verify each element announces clearly
- [ ] Switch to Favorites tab and verify announcement
- [ ] Return to Drinks tab

**2. Filtering Test**
- [ ] Focus on category filter
- [ ] Verify current state is announced
- [ ] Activate filter (double tap)
- [ ] Verify new state is announced
- [ ] Test style chips similarly

**3. Search Test**
- [ ] Focus on search button
- [ ] Activate search
- [ ] Type query and verify announcements
- [ ] Clear search and verify announcement

**4. List Navigation Test**
- [ ] Swipe through drink list
- [ ] Verify each card announces key info
- [ ] Activate a drink card
- [ ] Verify detail screen is accessible

**5. Favorites Test**
- [ ] Focus on favorite button
- [ ] Verify state (favorited or not)
- [ ] Toggle favorite
- [ ] Verify new state announcement
- [ ] Navigate to Favorites tab
- [ ] Verify drink appears

**6. Rating Test**
- [ ] Navigate to drink detail
- [ ] Focus on star rating
- [ ] Verify current rating announced
- [ ] Tap different stars
- [ ] Verify new rating announced

**7. Large Text Test**
- [ ] Enable largest system text size
- [ ] Navigate through all screens
- [ ] Verify no text overflow
- [ ] Verify no clipped content
- [ ] Verify buttons remain tappable

**8. Color Contrast Test**
- [ ] Use contrast checker on all text
- [ ] Verify minimum 4.5:1 ratio
- [ ] Check disabled state contrast (3:1)
- [ ] Test in both light and dark modes

### Automated Testing

**Add to widget tests:**
```dart
testWidgets('Favorite button has semantic label', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DrinkCard(drink: testDrink),
    ),
  );

  final semantics = tester.getSemantics(
    find.widgetWithIcon(IconButton, Icons.favorite_border),
  );

  expect(
    semantics,
    matchesSemantics(
      label: 'Add to favorites',
      isButton: true,
    ),
  );
});
```

**Run semantics-enabled tests:**
```bash
flutter test --enable-semantics
```

---

## Common Patterns

### Pattern: Conditional Labels

```dart
Semantics(
  label: isExpanded
    ? 'Collapse festival information'
    : 'Expand festival information',
  button: true,
  child: IconButton(
    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
    onPressed: () => setState(() => isExpanded = !isExpanded),
  ),
)
```

### Pattern: Excluding Decorative Elements

```dart
// Decorative images or icons that don't convey info
ExcludeSemantics(
  child: Image.asset('assets/decorative-pattern.png'),
)
```

### Pattern: Merging Complex Widgets

```dart
// When multiple Text widgets should be read as one
MergeSemantics(
  child: Column(
    children: [
      Text(drink.name, style: headlineStyle),
      Text('${drink.abv}% ABV', style: subtitleStyle),
      Text(drink.breweryName, style: captionStyle),
    ],
  ),
)
```

### Pattern: Custom Semantic Actions

```dart
Semantics(
  label: 'Filter options',
  button: true,
  onTap: () => _showFilterSheet(),
  customSemanticsActions: {
    CustomSemanticsAction(label: 'Reset filters'): () => _resetFilters(),
    CustomSemanticsAction(label: 'Save filter preset'): () => _savePreset(),
  },
  child: IconButton(...),
)
```

---

## Troubleshooting

### Issue: Screen Reader Reading Too Much

**Problem:** Every tiny element is announced separately.

**Solution:** Use `MergeSemantics` or `excludeSemantics`:
```dart
MergeSemantics(
  child: Row(
    children: [
      Text('Name'), // These merge into one announcement
      Text('Value'),
    ],
  ),
)
```

### Issue: Screen Reader Reading Nothing

**Problem:** Interactive elements are silent.

**Solution:** Add `Semantics` wrapper with `label`:
```dart
Semantics(
  label: 'Description of what this does',
  button: true,
  child: YourWidget(),
)
```

### Issue: Confusing Announcements

**Problem:** Labels unclear or technical.

**Solution:** Use plain language, describe action not implementation:
```dart
// ❌ Bad
label: 'Toggle boolean favorite state flag'

// ✅ Good
label: 'Add to favorites'
```

### Issue: Text Overflow at Large Sizes

**Problem:** Text cuts off when user increases font size.

**Solution:** Use flexible widgets:
```dart
// ❌ Bad - Fixed width
SizedBox(
  width: 200,
  child: Text('Long brewery name here'),
)

// ✅ Good - Flexible
Expanded(
  child: Text(
    'Long brewery name here',
    overflow: TextOverflow.ellipsis,
    maxLines: 2,
  ),
)
```

### Issue: Poor Color Contrast

**Problem:** Text hard to read on background.

**Solution:** Check contrast ratios, adjust colors:
```dart
// Use theme colors which have good contrast
Text(
  'Content',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface, // Good contrast
  ),
)
```

---

## Resources & Further Reading

### Official Documentation

- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design/overview)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

### Testing Tools

- [Android Accessibility Scanner](https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor)
- [Accessibility Inspector (iOS)](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [axe DevTools](https://www.deque.com/axe/devtools/)

### Screen Readers

- **Android**: TalkBack (built-in)
- **iOS**: VoiceOver (built-in)
- **Web**: NVDA (Windows, free), JAWS (Windows, paid), ChromeVox (Chrome extension)

### Courses & Guides

- [Web Accessibility by Google (free)](https://www.udacity.com/course/web-accessibility--ud891)
- [A11ycasts with Rob Dodson](https://www.youtube.com/playlist?list=PLNYkxOF6rcICWx0C9LVWWVqvHlYJyqw7g)
- [The A11Y Project](https://www.a11yproject.com/)

---

## Questions?

If you're unsure about accessibility implementation:

1. **Test with a screen reader** - Best way to understand user experience
2. **Consult WCAG guidelines** - Detailed technical requirements
3. **Ask the question**: "Can someone who can't see the screen complete this task?"

Remember: **Accessibility is not a feature, it's a requirement.**
