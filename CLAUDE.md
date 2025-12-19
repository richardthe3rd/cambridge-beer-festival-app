# Claude AI Instructions

Instructions for Claude AI when working on the Cambridge Beer Festival app.

## Repository Overview

**Cambridge Beer Festival App** - A Flutter application for browsing drinks at the Cambridge Beer Festival.

### Key Information

- **Language**: Dart/Flutter
- **Flutter Version**: 3.38.3+
- **Dart SDK**: >=3.2.0 <4.0.0
- **State Management**: Provider
- **Platforms**: Android, iOS, Web

## Essential Commands

```bash
# First-time setup
flutter pub get

# Verify code quality (run before and after changes)
flutter analyze --no-fatal-infos

# Run tests
flutter test

# Run the app locally
flutter run

# Build for web deployment
flutter build web --release --base-href "/cambridge-beer-festival-app/"
```

## Tool Management with Mise

This project uses [Mise](https://mise.jdx.dev) for managing development tools and task running.

### Important: Use ./bin/mise

**Always use `./bin/mise` (not plain `mise`)** when running mise commands in this repository.

### Environment-Specific Tools

Tools are split across two environments to optimize for different use cases:

**Base environment** (`mise.toml`):
- **Flutter 3.38.3** - Required in all environments (dev, CI, production)
- **Node.js 21** - For http_server and Playwright e2e tests
- **Tasks** - Available in all environments

**Developer environment** (`mise.dev.toml`):
- **Claude Code** - Only needed for human developers
- **Firebase Tools** - For deployment and testing

### Setup Instructions

**For CI/Automated Environments:**
```bash
# Install base tools (Flutter + Node)
./bin/mise install
```

**For Developer Environments:**
```bash
# Install base + developer tools (Flutter + Node + Claude + Firebase)
MISE_ENV=dev ./bin/mise install

# Or set permanently in your shell rc file:
export MISE_ENV=dev
./bin/mise install
```

### Known Issues and Workarounds

**Flutter Installation libgit2 Error:**

If you encounter a libgit2 error when mise tries to install Flutter:
```
Failed to configure the transport before connecting to "https://github.com/mise-plugins/mise-flutter.git"
```

Apply this workaround:

1. Manually clone the Flutter plugin:
```bash
mkdir -p .mise/plugins
git clone https://github.com/mise-plugins/mise-flutter.git .mise/plugins/flutter
```

2. Add Flutter install directory to git safe directories:
```bash
git config --global --add safe.directory /home/user/cambridge-beer-festival-app/.mise/installs/flutter/3.38.3-stable
```

3. Disable Flutter analytics (first run only):
```bash
./bin/mise exec flutter -- flutter --disable-analytics
```

4. Retry the installation:
```bash
./bin/mise install
```

**Note:** The `.mise/` directory is already gitignored, so the manually cloned plugin won't be committed.

### Using Mise Tasks

```bash
# Development
./bin/mise run dev              # Run Flutter dev server
./bin/mise run analyze          # Run code analysis

# Testing
./bin/mise run test             # Run all Flutter tests
./bin/mise run coverage         # Run tests with coverage

# Building & Serving
./bin/mise run build:web        # Build release version for local testing/e2e
./bin/mise run build:web:prod   # Build for production deployment
./bin/mise run serve:release    # Serve release build with SPA routing

# Screenshot Testing (requires Playwright setup)
./bin/mise run check-page <url> <output.png>    # Screenshot single page
./bin/mise run screenshots:batch                # Screenshot multiple pages from config
```

**Note:** CI workflows use Flutter directly (via `flutter-action`) and do not require mise.

### Testing Deep Links with Screenshots

The app uses path-based URLs (no `#` in URLs) for proper deep linking support. To test deep links:

**1. Setup Playwright (first time only):**
```bash
MISE_ENV=dev ./bin/mise run playwright-setup
```

**2. Build and serve the release version:**
```bash
# Build release version
./bin/mise run build:web

# Serve with SPA routing (in background or separate terminal)
./bin/mise run serve:release &
```

**3. Test all configured deep links:**
```bash
# Captures screenshots of all URLs in screenshots.config.json
./bin/mise run screenshots:batch
```

**Customizing URLs to test:**

Edit `screenshots.config.json` to add/modify test URLs:
```json
[
  { "path": "/", "name": "home" },
  { "path": "/brewery/[id]", "name": "brewery-detail" },
  { "path": "/drink/[id]", "name": "drink-detail" },
  { "path": "/style/IPA", "name": "style-ipa" }
]
```

**Why release build for testing?**
- Flutter dev server has issues with multiple Playwright sessions
- Release build is stable and reliable for automated testing
- `serve:release` includes `--proxy` flag for proper SPA routing (required for deep links)

## Development Container

This project includes a [Dev Container](https://containers.dev/) configuration for consistent development environments using VS Code, GitHub Codespaces, or any devcontainer-compatible tool.

### Quick Start

**VS Code:**
1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open the project in VS Code
3. Click "Reopen in Container" when prompted (or use Command Palette: "Dev Containers: Reopen in Container")
4. Wait for the container to build and tools to install

**GitHub Codespaces:**
1. Click "Code" → "Create codespace on main" in GitHub
2. Wait for the environment to initialize

### What's Included

The devcontainer automatically installs and configures:

- **Flutter 3.38.3** - From base mise.toml
- **Node.js 21** - For http_server and Playwright e2e tests
- **Claude Code** - AI development assistant
- **Firebase Tools** - For deployment
- **VS Code Extensions:**
  - Dart & Flutter support
  - Mise integration

### How It Works

The devcontainer uses:
- **Base Image**: Ubuntu (official Microsoft image)
- **Mise Feature**: [`ghcr.io/devcontainers-extra/features/mise:1`](https://github.com/devcontainers-extra/features)
- **Environment**: `MISE_ENV=dev` (developer tools)
- **Persistent Storage**: Mise cache persisted across container rebuilds

### Configuration Files

- `.devcontainer/devcontainer.json` - Container configuration
- `mise.toml` - Base tools (Flutter, Node)
- `mise.dev.toml` - Developer-specific tools (Claude, Firebase)

### Customization

To modify the devcontainer:
1. Edit `.devcontainer/devcontainer.json` for VS Code settings/extensions
2. Edit `mise.toml` or `mise.dev.toml` for tool versions
3. Rebuild container: Command Palette → "Dev Containers: Rebuild Container"

## Directory Structure

```
lib/
├── main.dart          # Entry point, app setup, home navigation
├── models/            # Data classes (Drink, Product, Producer, Festival)
├── providers/         # State management (BeerProvider)
├── screens/           # Full-page UI components
├── services/          # API calls and storage
└── widgets/           # Reusable UI components

test/                  # Unit and widget tests
web/                   # Web-specific assets
cloudflare-worker/     # API proxy worker
```

## Code Style Checklist

When writing or modifying Dart code:

- [ ] Use single quotes: `'string'` not `"string"`
- [ ] Use `const` constructors where possible
- [ ] Use `final` for local variables
- [ ] Include `{super.key}` in widget constructors
- [ ] Sort `child`/`children` properties last in widgets
- [ ] Avoid `print()` - use `debugPrint()` if needed
- [ ] Add new files to barrel exports (e.g., `models.dart`)
- [ ] **Add `Semantics` widgets for interactive elements** (buttons, filters, navigation)
- [ ] **Provide meaningful labels for screen readers** (see Accessibility Requirements below)
- [ ] **Test with large text settings** (ensure no overflow at 200% scale)

## Accessibility Requirements

**CRITICAL**: This app must be accessible to all users, including those using screen readers, large text, or other assistive technologies. Accessibility is NOT optional.

> 📖 **For complete implementation details, see [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md)**

### Compliance Standards

- **WCAG 2.1 Level AA** - Web Content Accessibility Guidelines
- **ADA** - Americans with Disabilities Act (US)
- **Section 508** - US Federal accessibility standards

### Key Principles

1. **Perceivable** - Users can perceive the information being presented
2. **Operable** - Users can operate the interface with various input methods
3. **Understandable** - Information and UI operation are understandable
4. **Robust** - Content works with current and future assistive technologies

### Required Semantics for Interactive Elements

**Every interactive element MUST have a `Semantics` widget with:**
- **label** - What the element is (e.g., "Add to favorites button")
- **hint** (optional) - How to use it (e.g., "Double tap to toggle")
- **value** (optional) - Current state (e.g., "3 out of 5 stars")

### Common Widget Patterns

#### Buttons and IconButtons

```dart
// ❌ BAD - No accessibility
IconButton(
  icon: Icon(Icons.favorite),
  onPressed: () => toggleFavorite(),
)

// ✅ GOOD - Screen reader accessible
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

#### Filter Chips and Buttons

```dart
// ✅ GOOD - Descriptive labels for filters
Semantics(
  label: 'Filter by $styleName',
  value: isSelected ? 'Selected' : 'Not selected',
  button: true,
  child: FilterChip(
    label: Text(styleName),
    selected: isSelected,
    onSelected: (value) => onStyleToggled(styleName),
  ),
)
```

#### List Items / Cards

```dart
// ✅ GOOD - Summary of card content
Semantics(
  label: '${drink.name}, ${drink.abv}% ABV, by ${drink.breweryName}',
  hint: 'Double tap for details',
  button: true,
  child: InkWell(
    onTap: () => navigateToDetail(drink),
    child: DrinkCard(drink: drink),
  ),
)
```

#### Star Ratings

```dart
// ✅ GOOD - Rating with context
Semantics(
  label: 'Rate this drink',
  value: '$rating out of 5 stars',
  hint: 'Tap a star to rate from 1 to 5',
  child: Row(children: starWidgets),
)
```

#### Navigation

```dart
// ✅ GOOD - Clear navigation labels
NavigationDestination(
  icon: Semantics(
    label: 'Drinks tab, browse all festival drinks',
    child: Icon(Icons.local_bar),
  ),
  label: 'Drinks',
)
```

#### Search Fields

```dart
// ✅ GOOD - TextField already has built-in semantics via decoration
TextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: 'Search drinks, breweries, styles...', // Used by screen readers
    label: Text('Search'), // Explicit label
    prefixIcon: Icon(Icons.search),
    suffixIcon: Semantics(
      label: 'Clear search',
      button: true,
      child: IconButton(
        icon: Icon(Icons.close),
        onPressed: () => clearSearch(),
      ),
    ),
  ),
)
```

### Accessibility Testing Checklist

When adding or modifying UI:

- [ ] **Add `Semantics` labels** to all interactive elements (buttons, chips, cards)
- [ ] **Test with TalkBack** (Android) or VoiceOver (iOS)
  - Enable: Settings → Accessibility → TalkBack/VoiceOver
  - Navigate using swipe gestures
  - Verify all elements announce correctly
- [ ] **Test with large text** (200% scale)
  - Android: Settings → Display → Font size → Largest
  - iOS: Settings → Display & Brightness → Text Size
  - Verify no text overflow or clipped content
- [ ] **Verify color contrast** (4.5:1 minimum for text)
  - Use WebAIM Contrast Checker or browser dev tools
  - Check buttons, icons, and text on all backgrounds
- [ ] **Test keyboard navigation** (web/desktop)
  - Verify logical tab order
  - Ensure all actions accessible via keyboard

### Files That Need Accessibility

**High Priority:**
- `lib/widgets/drink_card.dart` - Drink cards, favorite buttons
- `lib/screens/drinks_screen.dart` - Filter buttons, search, sort controls
- `lib/screens/festival_info_screen.dart` - Map and website buttons
- `lib/main.dart` - Bottom navigation bar
- `lib/widgets/star_rating.dart` - Star rating widgets

**Medium Priority:**
- `lib/screens/drink_detail_screen.dart` - Detail view interactions
- `lib/screens/brewery_screen.dart` - Brewery details

### Resources

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design/overview)
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Testing Tools

- **Android**: TalkBack, Accessibility Scanner app
- **iOS**: VoiceOver, Accessibility Inspector
- **Web**: NVDA, JAWS, ChromeVox, axe DevTools
- **Flutter**: `flutter test` (semantics are always enabled in tests)

### Automated Accessibility Testing

**REQUIRED**: All new interactive UI elements must have corresponding semantic tests.

When adding or modifying widgets with `Semantics`:

1. **Add tests to verify semantic properties** in the corresponding test file:
```dart
testWidgets('button has correct semantic label', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyButton(),
      ),
    ),
  );

  // Find the Semantics widget
  final semantics = tester.widget<Semantics>(
    find.byType(Semantics).first,
  );

  // Verify semantic properties
  expect(semantics.properties.label, 'Add to favorites');
  expect(semantics.properties.hint, 'Double tap to toggle');
  expect(semantics.properties.button, isTrue);
});
```

2. **Test semantic values for stateful elements**:
```dart
testWidgets('filter shows selection state in semantics', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FilterChip(
          label: Text('IPA'),
          selected: true,
        ),
      ),
    ),
  );

  final semantics = tester.widget<Semantics>(
    find.byType(Semantics).first,
  );

  expect(semantics.properties.value, 'Selected');
  expect(semantics.properties.selected, isTrue);
});
```

3. **Verify ExcludeSemantics for decorative elements**:
```dart
testWidgets('decorative icon is excluded from semantics', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExcludeSemantics(
          child: Icon(Icons.percent),
        ),
      ),
    ),
  );

  // Verify the ExcludeSemantics wrapper exists
  expect(find.byType(ExcludeSemantics), findsOneWidget);
});
```

**Test file locations** (mirror lib/ structure):
- `lib/widgets/drink_card.dart` → `test/drink_card_test.dart`
- `lib/screens/drinks_screen.dart` → Tests may be split into multiple files
- Add semantic tests to existing test files where applicable

## Working with Models

### JSON Parsing Pattern

API data types can vary. Always handle type variations:

```dart
// ABV can be String, int, or double
final abvValue = json['abv'];
double parsedAbv;
if (abvValue is num) {
  parsedAbv = abvValue.toDouble();
} else if (abvValue is String) {
  parsedAbv = double.tryParse(abvValue) ?? 0.0;
} else {
  parsedAbv = 0.0;
}
```

### Core Models

- **Festival**: Beer festival event with API data URL
- **Producer**: Brewery/cidery with location and products list
- **Product**: Individual beverage with ABV, style, category
- **Drink**: Combines Product + Producer for display purposes

## Working with State (Provider)

The app uses `BeerProvider` for all state:

```dart
// Reading state (triggers rebuild on changes)
final provider = context.watch<BeerProvider>();
final drinks = provider.drinks;

// One-time access (no rebuild)
final provider = context.read<BeerProvider>();
provider.setCategory('beer');
```

### Key Provider Methods

- `initialize()` - Load festivals and set up storage
- `loadDrinks()` - Fetch drinks from current festival
- `setFestival(Festival)` - Change active festival
- `setCategory(String?)` - Filter by category
- `setSearchQuery(String)` - Filter by search text
- `toggleFavorite(Drink)` - Toggle favorite status
- `setRating(Drink, int)` - Set drink rating

## Testing Requirements

When adding features or fixing bugs:

1. Check if existing tests cover the area
2. Add tests for new functionality
3. Ensure all tests pass: `flutter test`

### Test File Location

Tests go in `test/` mirroring `lib/` structure:
- `lib/models/drink.dart` → `test/models_test.dart`

## API Details

**Base URL**: `https://data.cambeerfestival.app`

**Endpoints**:
- `/{festivalId}/beer.json` - Beers
- `/{festivalId}/cider.json` - Ciders
- `/{festivalId}/perry.json` - Perry
- `/{festivalId}/mead.json` - Meads
- `/{festivalId}/wine.json` - Wines
- `/{festivalId}/international-beer.json` - International beers
- `/{festivalId}/low-no.json` - Low/no alcohol

**Response Format**: Array of Producer objects, each containing products

### API Documentation

Full API documentation and JSON schemas are available in `docs/api/`:

- **[docs/api/README.md](docs/api/README.md)** - Overview and quick reference
- **[docs/api/data-api-reference.md](docs/api/data-api-reference.md)** - Complete API reference
- **[docs/api/beer-list-schema.json](docs/api/beer-list-schema.json)** - JSON Schema for beverage data
- **[docs/api/festival-registry-schema.json](docs/api/festival-registry-schema.json)** - JSON Schema for festival config

These schemas define the expected API response structure and can be used for validation.

## Common Modifications

### Adding a Screen

1. Create `lib/screens/my_screen.dart`:
```dart
import 'package:flutter/material.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

2. Export in `lib/screens/screens.dart`:
```dart
export 'my_screen.dart';
```

### Adding Provider State

1. Add private field: `String? _myField;`
2. Add getter: `String? get myField => _myField;`
3. Add setter method:
```dart
void setMyField(String? value) {
  _myField = value;
  notifyListeners();
}
```

## Validation Workflow

After making changes:

1. `flutter analyze --no-fatal-infos` - Check for issues
2. `flutter test` - Run all tests
3. Review changes for const/final usage
4. Verify barrel exports are updated

## Do Not Change Without Request

- GitHub Actions workflows (`.github/workflows/`)
- Cloudflare Worker (`cloudflare-worker/`)
- Package versions in `pubspec.yaml`
- Analysis rules in `analysis_options.yaml`
