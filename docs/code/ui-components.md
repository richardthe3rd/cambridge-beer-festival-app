# UI Components

## Overflow Menu

A shared three-dot menu providing access to global app features.

### Usage

```dart
import 'package:cambridge_beer_festival/widgets/widgets.dart';

// Add to AppBar actions
AppBar(
  title: Text('Screen Title'),
  actions: [
    buildOverflowMenu(context),
  ],
)
```

### Menu Options

The overflow menu provides access to:
- **Browse Festivals** - Opens festival selector bottom sheet
- **Settings** - Opens app settings bottom sheet
- **About** - Navigates to `/about` screen

### Where to Use

✅ **Include overflow menu on:**
- Drinks screen (`DrinksScreen`)
- Favorites screen (`FavoritesScreen`)
- Any screen where users need access to festival switching or settings

❌ **Do NOT include on:**
- About screen (already in the app menu)
- Festival info screen (festival-specific, not global)
- Detail screens (drink/brewery/style) - use back navigation only
- Modal bottom sheets (use sheet close instead)

### Implementation Details

**Pattern:** Shared function (not a widget) that returns a `PopupMenuButton`

```dart
Widget buildOverflowMenu(BuildContext context)
```

**Accessibility:**
- Main button has `Semantics` label: "Menu"
- Main button has tooltip: "Menu"
- Icons are decorative: wrapped in `ExcludeSemantics`
- Screen readers announce: "Browse Festivals", "Settings", "About" (icon is skipped)

**Navigation:**
- Festival browser and Settings open as modal bottom sheets
- About navigates to `/about` route using `context.go()`

### Related Widgets

The overflow menu triggers these modal sheets:
- `showFestivalBrowser(context)` - Shows `FestivalSelectorSheet`
- `showSettingsSheet(context)` - Shows `SettingsSheet`

Both sheets are defined in `lib/widgets/festival_menu_sheets.dart`.
