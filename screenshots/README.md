# A-Z Jump Navigation Screenshots

## Feature Overview

The A-Z Jump Navigation feature adds an alphabet scrollbar to the drinks list when sorted by name (A-Z or Z-A).

### Visual Elements

**Alphabet Scrollbar:**
- Positioned on the right edge of the screen
- 24px wide, semi-transparent background
- Letters A-Z displayed vertically
- Available letters: Full opacity, tappable
- Unavailable letters: Reduced opacity (30%), non-interactive
- Active letter: Highlighted with primary color and bold font

### Behavior

1. **Visibility:** Only shown when sort order is "Name (A-Z)" or "Name (Z-A)"
2. **Interaction:** Tap any available letter to jump to drinks starting with that letter
3. **Animation:** Smooth scroll animation (300ms) to target position
4. **Feedback:** Letter highlights briefly (500ms) when tapped

### Accessibility

- Each letter has Semantics label: "Jump to letter X"
- Available letters: Hint "Double tap to scroll to drinks starting with X"
- Unavailable letters: Hint "No drinks starting with X"
- Full screen reader support

### Technical Details

- Widget: `AlphabetScrollbar` (lib/widgets/alphabet_scrollbar.dart)
- Integration: `DrinksScreen` uses Stack to overlay scrollbar
- Scroll control: Uses `ScrollController.animateTo()` for smooth navigation
- State management: Tracks active letter with temporary highlight
- Test coverage: 6 unit tests covering all scenarios

### Code Example

```dart
AlphabetScrollbar(
  onLetterTapped: (letter) => _jumpToLetter(letter, provider),
  availableLetters: _getAvailableLetters(provider),
)
```

