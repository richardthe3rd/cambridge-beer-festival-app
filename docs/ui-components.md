# UI Components

## BreadcrumbBar

A navigation breadcrumb bar for detail screens.

### Usage

```dart
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

// Breadcrumb for detail screens (back to festival home)
BreadcrumbBar(
  backLabel: provider.currentFestival.id,  // e.g., 'cbf2025'
  contextLabel: 'Oakham Ales',
  onBack: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(buildFestivalHome(festivalId));
    }
  },
  onBackLabelTap: () => context.go(buildFestivalHome(festivalId)),
)
```

**Current pattern (festival-scoped routing):**
- `backLabel`: Festival ID (e.g., `cbf2025`, `cbf2024`)
- `contextLabel`: Parent context (brewery name, style name, etc.)
- `onBack`: Pop if possible, otherwise navigate to festival home
- `onBackLabelTap`: Always navigate to festival home when clicking the festival ID

### Accessibility

- **Large touch target**: IconButton with 28px icon size (48x48 touch target)
- **Semantic labels**: Only the IconButton has `Semantics` (not the entire row)
  - Label: "Back to {backLabel}"
  - Marked as button for screen readers
- **Tooltip**: "Back to {backLabel}" on hover
- **Text overflow handling**: Single line with ellipsis for long text
- **Supports text scaling**: No overflow at 200% scale

### Implementation Details

- **Semantics structure**: Only the interactive IconButton is wrapped in `Semantics`
- **Text widget**: Non-interactive text is NOT marked as a button
- **Single-line constraint**: `maxLines: 1` with `TextOverflow.ellipsis`
- **No variable shadowing**: Uses `contextLabel` property (not `context`) to avoid Flutter BuildContext confusion

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
