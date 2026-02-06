# Testing Flutter Web Apps with Playwright

## The Challenge

Flutter web apps render their UI to a canvas element, which makes traditional DOM-based testing approaches ineffective. You cannot:
- ❌ Use CSS selectors to find buttons, text, or other UI elements
- ❌ Directly interact with Flutter widgets via Playwright
- ❌ Inspect the visual content rendered on the canvas

## The Solution: Accessibility-Based Testing

Flutter creates **DOM elements for accessibility** through the `Semantics` widget. These elements are specifically designed for screen readers but also serve as a reliable testing interface.

### How It Works

1. **Flutter Semantics Widget** → Creates ARIA labels in the DOM
2. **Screen readers** → Read these ARIA labels
3. **Playwright tests** → Can also read these ARIA labels

### Example

**Flutter Code:**
```dart
Semantics(
  label: 'Drinks tab, browse all festival drinks',
  child: const Icon(Icons.local_drink_outlined),
)
```

**Generated DOM (simplified):**
```html
<flt-semantics aria-label="Drinks tab, browse all festival drinks">
  <!-- Flutter renders icon to canvas -->
</flt-semantics>
```

**Playwright Test:**
```typescript
const drinksTabLabel = page.locator('[aria-label*="Drinks tab"]');
await expect(drinksTabLabel.first()).toBeAttached();
```

## What You CAN Test

✅ **Page loads successfully** - Check for Flutter embedder elements
✅ **URL routing** - Verify URLs change correctly during navigation
✅ **Browser history** - Test back/forward button functionality  
✅ **Console errors** - Monitor for JavaScript errors
✅ **Network requests** - Verify API calls are made
✅ **Screen verification** - Use ARIA labels to confirm which screen is displayed
✅ **Accessibility** - Ensure proper ARIA labels exist for screen readers

## What You CANNOT Test

❌ **Visual appearance** - Colors, fonts, layout (use visual regression testing or Flutter integration tests)
❌ **Canvas interactions** - Clicking specific points on the canvas
❌ **Gesture detection** - Swipes, drags, pinch-to-zoom
❌ **Text content** - Reading text rendered on canvas (unless it has ARIA labels)

## Best Practices

### 1. Add Semantics to Key UI Elements

Always wrap important UI elements with `Semantics` widgets:

```dart
// Good
Semantics(
  label: 'View source code on GitHub',
  hint: 'Double tap to open GitHub repository in browser',
  button: true,
  child: IconButton(
    icon: Icon(Icons.code),
    onPressed: _openGitHub,
  ),
)

// Bad - no Semantics, cannot be tested or used by screen readers
IconButton(
  icon: Icon(Icons.code),
  onPressed: _openGitHub,
)
```

### 2. Use Descriptive ARIA Labels

Make labels unique enough to identify specific screens:

```dart
// Good - unique to About screen
Semantics(
  label: 'View source code on GitHub',
  // ...
)

// Bad - too generic, could be on any screen
Semantics(
  label: 'Button',
  // ...
)
```

### 3. Test What Matters for Routing

For go_router navigation tests, focus on:

```typescript
test('should navigate to about screen', async ({ page }) => {
  await page.goto('http://localhost:8080/about');
  await waitForPageReady(page);
  
  // 1. Verify URL changed
  expect(page.url()).toBe('http://localhost:8080/about');
  
  // 2. Verify correct screen via unique ARIA label
  const aboutLabel = page.locator('[aria-label*="View source code on GitHub"]');
  await expect(aboutLabel.first()).toBeAttached();
  
  // 3. Verify no console errors
  // (setup error listeners before navigation)
});
```

### 4. Keep Tests Focused

Don't try to test complex user interactions in E2E tests. Use Flutter integration tests for those:

```dart
// This belongs in Flutter integration tests, not Playwright:
testWidgets('tapping favorite button adds drink to favorites', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.favorite_border));
  await tester.pump();
  expect(find.byIcon(Icons.favorite), findsOneWidget);
});
```

## Example Test Suite Structure

```
test-e2e/
├── app.spec.ts              # Basic app loading tests
├── routing.spec.ts          # Navigation/routing tests (uses ARIA labels)
└── network.spec.ts          # API request tests (optional)
```

## Benefits of This Approach

1. **Accessibility First** - Tests ensure the app is usable by screen readers
2. **Stable Selectors** - ARIA labels are less likely to change than internal Flutter DOM structure
3. **Meaningful Tests** - Verifies actual user-facing behavior (navigation, errors)
4. **Dual Purpose** - Same Semantics widgets benefit both testing and accessibility
5. **Fast Feedback** - Catch routing issues in CI before manual testing

## References

- [Flutter Semantics Documentation](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [Playwright Accessibility Testing](https://playwright.dev/docs/accessibility-testing)
- [Flutter Web Rendering](https://docs.flutter.dev/platform-integration/web/renderers)

## Current Usage in This App

This app has **53+ Semantics widgets** across all screens and widgets.
See [../code/accessibility.md](../code/accessibility.md) for the full inventory.
These provide both accessibility and testability.
