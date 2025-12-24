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
  contextLabel: 'Oakham Ales',
  onBack: () => context.pop(),
)
```

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
