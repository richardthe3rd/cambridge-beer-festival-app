# Widget Coding Standards

Coding standards for Flutter widgets in the Cambridge Beer Festival app.

## 📝 Text Selectability

**Standard:** Content text must be selectable for better UX and accessibility.

### Use `SelectableText` for:

- ✅ **Content text**: Drink names, brewery names, descriptions
- ✅ **Data values**: ABV, ratings, styles, categories
- ✅ **User-generated content**: Reviews, notes, tasting notes
- ✅ **Long-form text**: Descriptions, festival info, about text
- ✅ **Informational text**: Any text users might want to copy

### Use regular `Text` for:

- ❌ **UI labels**: "Filter by:", "Sort by:", etc.
- ❌ **Button text**: Text inside buttons or interactive elements
- ❌ **Navigation elements**: Breadcrumbs, tabs, menu items
- ❌ **Short helper text**: Decorative or instructional text

### Examples

```dart
// ✅ GOOD - Selectable content
SelectableText(
  drink.name,
  style: Theme.of(context).textTheme.titleLarge,
)

// ✅ GOOD - Selectable data
SelectableText(
  '${drink.abv}% ABV',
  style: TextStyle(fontWeight: FontWeight.bold),
)

// ✅ GOOD - Selectable description
SelectableText(
  drink.description,
  maxLines: 3,
  style: Theme.of(context).textTheme.bodyMedium,
)

// ❌ GOOD - Non-selectable UI label
Text('Filter by:')  // Just a label, not content

// ❌ GOOD - Non-selectable navigation
Text(backLabel)  // Part of navigation control
```

### Testing

Always verify text selectability in widget tests:

```dart
testWidgets('drink name is selectable', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectableText('Sample IPA'),
      ),
    ),
  );

  // Verify SelectableText is used
  expect(find.byType(SelectableText), findsOneWidget);
});
```

---

## ♿ Accessibility Requirements

**See [`accessibility.md`](accessibility.md) for comprehensive accessibility standards.**

### Quick Checklist for Widgets

- [ ] All interactive elements have `Semantics` labels
- [ ] `Semantics` only wraps interactive elements (not decorative text)
- [ ] Touch targets are at least 48x48 pixels
- [ ] Color contrast meets WCAG AA standards (4.5:1)
- [ ] Text scales properly (test at 200%)
- [ ] No reliance on color alone for information

### Semantics Pattern

```dart
// ✅ GOOD - Only button has Semantics
Semantics(
  label: 'Add to favorites',
  button: true,
  child: IconButton(
    icon: Icon(Icons.favorite_border),
    onPressed: () => addToFavorites(),
  ),
)

// ❌ BAD - Entire row marked as button when only icon is tappable
Semantics(
  label: 'Drink card',
  button: true,
  child: Row(
    children: [
      IconButton(...),  // Only this is tappable
      Text(...),        // Not tappable but included in button semantics
    ],
  ),
)
```

---

## 🎨 Widget Patterns

### Text Overflow Handling

Always specify overflow behavior for constrained text:

```dart
// ✅ GOOD - Explicit overflow handling
Text(
  longText,
  overflow: TextOverflow.ellipsis,
  maxLines: 1,
)

// ✅ GOOD - Multi-line with fade
Text(
  description,
  overflow: TextOverflow.fade,
  maxLines: 3,
)

// ❌ BAD - No overflow handling (can cause layout issues)
Text(longText)
```

### Const Constructors

Use `const` wherever possible for performance:

```dart
// ✅ GOOD
const Text('Label')
const SizedBox(height: 16)
const Icon(Icons.star)

// ❌ BAD
Text('Label')
SizedBox(height: 16)
Icon(Icons.star)
```

### Widget Organization

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({
    required this.title,
    this.subtitle,
    super.key,
  });

  // Required parameters first
  final String title;

  // Optional parameters after
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildContent(),
      ],
    );
  }

  // Extract complex widgets into methods
  Widget _buildHeader() {
    return Text(title);
  }

  Widget _buildContent() {
    return Text(subtitle ?? '');
  }
}
```

---

## 🧪 Testing Requirements

### Every widget must have tests for:

1. **Rendering**: Widget renders without errors
2. **Content**: Expected text/icons appear
3. **Interaction**: Buttons/taps trigger callbacks
4. **Accessibility**: Semantics labels are correct
5. **Edge cases**: Long text, Unicode, empty states

### Test Template

```dart
testWidgets('MyWidget displays content correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyWidget(title: 'Test'),
      ),
    ),
  );

  // Test rendering
  expect(find.byType(MyWidget), findsOneWidget);

  // Test content
  expect(find.text('Test'), findsOneWidget);

  // Test interaction (if applicable)
  await tester.tap(find.byIcon(Icons.close));
  expect(onCloseCalled, isTrue);

  // Test accessibility
  final semantics = tester.widget<Semantics>(find.byType(Semantics));
  expect(semantics.properties.label, 'Close button');
});
```

---

## 📏 Code Style

### Imports

```dart
// Flutter SDK imports first
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports second
import 'package:provider/provider.dart';

// Local imports last
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
```

### Strings

Always use single quotes:

```dart
// ✅ GOOD
const text = 'Hello';

// ❌ BAD
const text = "Hello";
```

### Widget Properties Order

```dart
Widget build(BuildContext context) {
  return Container(
    // Layout properties first
    width: 100,
    height: 100,
    padding: EdgeInsets.all(16),
    margin: EdgeInsets.all(8),

    // Decoration properties
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(8),
    ),

    // Child/children always last
    child: Text('Content'),
  );
}
```

---

## 🔍 Input Validation

### Assertions for Debug Mode

Use assertions to catch developer errors early:

```dart
Widget build(BuildContext context) {
  assert(items.isNotEmpty, 'Items list cannot be empty');
  assert(maxCount > 0, 'Max count must be positive');

  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ...,
  );
}
```

### Null Safety

Prefer non-nullable types and handle nulls explicitly:

```dart
// ✅ GOOD - Explicit null handling
final displayText = text ?? 'Default';

// ✅ GOOD - Conditional rendering
if (subtitle != null)
  Text(subtitle!),

// ❌ BAD - Unsafe null access
Text(subtitle)  // Crashes if subtitle is null
```

---

## 📚 Documentation

### Widget Documentation

All public widgets must have doc comments:

```dart
/// A card displaying drink information.
///
/// Shows the drink name, ABV, brewery, and optional rating.
/// Tapping the card navigates to the drink detail screen.
///
/// Example usage:
/// ```dart
/// DrinkCard(
///   drink: myDrink,
///   onTap: () => navigateTo(drinkDetail),
/// )
/// ```
class DrinkCard extends StatelessWidget {
  /// Creates a drink card.
  const DrinkCard({
    required this.drink,
    this.onTap,
    super.key,
  });

  /// The drink to display.
  final Drink drink;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  // ...
}
```

---

## ✅ Pre-Commit Checklist

Before committing widget code:

- [ ] Used `SelectableText` for content (not UI labels)
- [ ] Added `Semantics` to interactive elements
- [ ] Used `const` constructors where possible
- [ ] Single quotes for strings
- [ ] Proper overflow handling (`maxLines`, `overflow`)
- [ ] Widget has doc comments
- [ ] Widget tests written and passing
- [ ] Analyzer passes with 0 warnings
- [ ] Accessibility tested (screen reader, large text)

---

## 📖 Related Documentation

- **Accessibility**: [`accessibility.md`](accessibility.md) - Comprehensive accessibility guide
- **Navigation**: [`../navigation.md`](../navigation.md) - Navigation utilities and patterns
- **UI Components**: [`../ui-components.md`](../ui-components.md) - Reusable widget catalog
- **API**: [`api/README.md`](api/README.md) - API integration patterns

---

**Last Updated**: December 2024
**Status**: ✅ Active - All new widgets must follow these standards
