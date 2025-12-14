# Widget Keys Guide for Screenshot Tests

## 🎯 Quick Reference

This guide shows **exact code examples** for adding Keys to widgets in the Cambridge Beer Festival app to make them findable in integration tests.

## 📋 Widget Keys Checklist

Based on the screenshot test requirements, these widgets need Keys:

### ✅ Already Have Keys (No Changes Needed)

- [x] DrinkCard widgets - Use `key: ValueKey(drink.id)`
- [x] Main app widget - Uses `super.key`

### 🔧 Need Keys Added

- [ ] Info/About button in drinks screen app bar
- [ ] Favorites navigation tab
- [ ] Drinks navigation tab
- [ ] First drink card for detail screen navigation
- [ ] Brewery links in detail screens

## 📝 Exact Code Changes Needed

### 1. Info Button (Drinks Screen)

**File:** `lib/screens/drinks_screen.dart`

**Current code (around line 66-78):**
```dart
Widget _buildInfoButton(BuildContext context) {
  return Semantics(
    label: 'About app',
    hint: 'Double tap to view app information and version',
    button: true,
    child: IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'About',
      onPressed: () {
        context.go('/about');
      },
    ),
  );
}
```

**Change to:**
```dart
Widget _buildInfoButton(BuildContext context) {
  return Semantics(
    label: 'About app',
    hint: 'Double tap to view app information and version',
    button: true,
    child: IconButton(
      key: const Key('info_button'),  // ← ADD THIS LINE
      icon: const Icon(Icons.info_outline),
      tooltip: 'About',
      onPressed: () {
        context.go('/about');
      },
    ),
  );
}
```

**Test usage:**
```dart
await tester.tap(find.byKey(const Key('info_button')));
```

---

### 2. Navigation Tabs (Bottom Navigation Bar)

**File:** `lib/main.dart`

**Current code (around line 202-241):**
```dart
bottomNavigationBar: NavigationBar(
  height: 60,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
  selectedIndex: _currentIndex,
  onDestinationSelected: _onDestinationSelected,
  destinations: [
    NavigationDestination(
      icon: Semantics(
        label: 'Drinks tab, browse all festival drinks',
        child: Opacity(
          opacity: 0.6,
          child: Image.asset(
            'assets/app_icon.png',
            width: 24,
            height: 24,
          ),
        ),
      ),
      selectedIcon: Semantics(
        label: 'Drinks tab, browse all festival drinks',
        child: Image.asset(
          'assets/app_icon.png',
          width: 24,
          height: 24,
        ),
      ),
      label: 'Drinks',
    ),
    NavigationDestination(
      icon: Semantics(
        label: 'Favorites tab, view your favorite drinks',
        child: const Icon(Icons.favorite_outline),
      ),
      selectedIcon: Semantics(
        label: 'Favorites tab, view your favorite drinks',
        child: const Icon(Icons.favorite),
      ),
      label: 'Favorites',
    ),
  ],
),
```

**Change to:**
```dart
bottomNavigationBar: NavigationBar(
  key: const Key('bottom_navigation'),  // ← ADD THIS LINE
  height: 60,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
  selectedIndex: _currentIndex,
  onDestinationSelected: _onDestinationSelected,
  destinations: [
    NavigationDestination(
      key: const Key('drinks_tab'),  // ← ADD THIS LINE
      icon: Semantics(
        label: 'Drinks tab, browse all festival drinks',
        child: Opacity(
          opacity: 0.6,
          child: Image.asset(
            'assets/app_icon.png',
            width: 24,
            height: 24,
          ),
        ),
      ),
      selectedIcon: Semantics(
        label: 'Drinks tab, browse all festival drinks',
        child: Image.asset(
          'assets/app_icon.png',
          width: 24,
          height: 24,
        ),
      ),
      label: 'Drinks',
    ),
    NavigationDestination(
      key: const Key('favorites_tab'),  // ← ADD THIS LINE
      icon: Semantics(
        label: 'Favorites tab, view your favorite drinks',
        child: const Icon(Icons.favorite_outline),
      ),
      selectedIcon: Semantics(
        label: 'Favorites tab, view your favorite drinks',
        child: const Icon(Icons.favorite),
      ),
      label: 'Favorites',
    ),
  ],
),
```

**Test usage:**
```dart
// Navigate to favorites
await tester.tap(find.byKey(const Key('favorites_tab')));

// Navigate to drinks
await tester.tap(find.byKey(const Key('drinks_tab')));
```

---

### 3. Alternative: Use Semantic Labels

If adding Keys is not desired, the test can use the existing semantic labels:

**Test code (no source changes needed):**
```dart
// Find by semantic label
await tester.tap(find.bySemanticsLabel('Favorites tab, view your favorite drinks'));
await tester.tap(find.bySemanticsLabel('About app'));
```

**Pros:**
- ✅ No source code changes needed
- ✅ Uses existing accessibility labels
- ✅ Works with screen readers

**Cons:**
- ⚠️ Longer, more fragile selectors
- ⚠️ Breaks if label text changes
- ⚠️ May find multiple matches if labels aren't unique

**Recommendation:** Use Keys for navigation elements, semantic labels for verification.

---

## 🎨 Key Naming Conventions

Follow these patterns for consistency:

### Navigation Elements
```dart
Key('drinks_tab')
Key('favorites_tab')
Key('about_button')
Key('info_button')
Key('back_button')
Key('bottom_navigation')
```

### List Items
```dart
Key('drink_card_${drink.id}')
Key('brewery_card_${brewery.id}')
Key('producer_item_${producer.id}')
```

### Screens
```dart
Key('drinks_screen')
Key('favorites_screen')
Key('about_screen')
Key('drink_detail_screen')
```

### Actions
```dart
Key('favorite_button_${drink.id}')
Key('share_button')
Key('filter_button')
Key('search_button')
```

## 🔍 Finding Widgets in Tests

### By Key
```dart
await tester.tap(find.byKey(const Key('info_button')));
```

### By Type
```dart
await tester.tap(find.byType(IconButton).first);
```

### By Icon
```dart
await tester.tap(find.byIcon(Icons.favorite_outline));
```

### By Semantic Label
```dart
await tester.tap(find.bySemanticsLabel('About app'));
```

### By Text
```dart
await tester.tap(find.text('Submit'));
```

### Combination
```dart
await tester.tap(
  find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.info_outline),
  ),
);
```

## ⚡ Best Practices

### 1. Use `const` for Static Keys
```dart
// ✅ Good - const reduces memory allocation
Key('info_button')

// ❌ Avoid - creates new object each time
Key('info_button')
```

### 2. Use ValueKey for Dynamic Items
```dart
// ✅ Good - unique per item
ValueKey(drink.id)

// ❌ Bad - all items have same key
Key('drink_card')
```

### 3. Prefer Keys Over Text/Icon Selectors
```dart
// ✅ Good - stable, won't break if icon changes
find.byKey(Key('info_button'))

// ❌ Fragile - breaks if we change icon
find.byIcon(Icons.info_outline)
```

### 4. Keep Keys Descriptive
```dart
// ✅ Good - clear what it does
Key('navigate_to_about_button')

// ❌ Bad - unclear purpose
Key('button1')
```

### 5. Document Why Keys Exist
```dart
IconButton(
  key: const Key('info_button'), // Used by integration tests
  icon: const Icon(Icons.info_outline),
  // ...
)
```

## 🧪 Testing After Adding Keys

After adding Keys, verify they work:

### 1. Minimal Test
```dart
testWidgets('Can find widget by key', (tester) async {
  await tester.pumpWidget(MyApp());
  expect(find.byKey(Key('info_button')), findsOneWidget);
});
```

### 2. Integration Test
```dart
// In integration_test/screenshot_test.dart
final infoButton = find.byKey(const Key('info_button'));
expect(infoButton, findsOneWidget);
await tester.tap(infoButton);
```

### 3. Run Full Screenshot Test
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d web-server
```

## 🐛 Troubleshooting Keys

### Problem: "Expected exactly one matching node, found 0"

**Cause:** Key doesn't exist or widget hasn't rendered

**Solutions:**
1. Verify key was added to source code
2. Wait for widget to render:
   ```dart
   await tester.pumpAndSettle();
   await Future.delayed(Duration(seconds: 1));
   ```

### Problem: "Expected exactly one matching node, found 2"

**Cause:** Multiple widgets have the same key

**Solution:**
Make keys unique:
```dart
// Instead of:
Key('drink_card')

// Use:
Key('drink_card_${drink.id}')
```

### Problem: Key works locally but fails in CI

**Cause:** Timing issue - widget renders slower in CI

**Solution:**
Add longer wait in test:
```dart
await tester.pumpAndSettle(Duration(seconds: 10));
await Future.delayed(Duration(seconds: 2));
```

## 📚 Additional Resources

- [Flutter Keys Documentation](https://api.flutter.dev/flutter/foundation/Key-class.html)
- [ValueKey vs ObjectKey vs UniqueKey](https://api.flutter.dev/flutter/foundation/ValueKey-class.html)
- [Widget Testing Best Practices](https://docs.flutter.dev/cookbook/testing/widget/introduction)

## 🎯 Summary

**For this migration, you minimally need to add Keys to:**

1. ✅ Info button (`Key('info_button')`) - Already in test, uses icon
2. ✅ Favorites tab (`Key('favorites_tab')`) - Already in test, uses icon
3. ✅ Drinks tab (`Key('drinks_tab')`) - Already in test, uses image

**Current test uses icon/image finders. If those fail, add the Keys above.**

**Test will fall back to:**
- Semantic labels for buttons
- Type-based finding (find.byType)
- Icon-based finding for tabs

**The test is written to be flexible and work without Keys, but Keys make it more reliable.**
