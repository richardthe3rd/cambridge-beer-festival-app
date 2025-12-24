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
