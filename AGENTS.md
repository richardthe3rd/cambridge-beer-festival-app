# AI Agent Instructions

Instructions for AI coding agents (Claude, Copilot, etc.) working on the Cambridge Beer Festival app.

## Session Startup

**At the start of every session, kick off toolchain installation in the background before doing anything else.** Flutter, Dart, and pub dependencies are managed by mise and may not be present in a fresh environment. Installation can take 2–5 minutes; starting it immediately means it's ready by the time you need it.

```bash
# Run this first — before reading code, planning, or asking questions
./bin/mise run check &
```

`check` runs generate → analyze → test, which forces mise to install Flutter and fetch pub dependencies as a side effect. Running it in the background lets you proceed with reading files, understanding the task, and drafting a plan while tools install. When you're ready to run a command that needs Flutter, wait for the background job to finish or check its status.

If `check` fails due to missing system deps (e.g. no network, missing system libraries), fall back to just fetching deps:

```bash
./bin/mise deps &
```

Do not run raw `flutter` commands — they may use the wrong version. Always use `./bin/mise run <task>`.

---

## Project Context

A **Flutter mobile/web app** for browsing drinks (beer, cider, perry, mead, wine) at the Cambridge Beer Festival. Users browse, search, filter, favourite, rate, and view brewery details.

- **Flutter**: 3.38.3 | **Dart SDK**: >=3.2.0 <4.0.0 | **Platforms**: Android, iOS, Web

### Directory Structure

```
lib/
├── main.dart          # Entry point, app setup, home navigation
├── router.dart        # GoRouter configuration
├── app_theme.dart     # Theme definitions
├── domain/            # Business logic (pure Dart, no Flutter deps)
│   ├── models/        # DrinkSort, DrinkVisibilityFilter
│   ├── repositories/  # Repository interfaces and implementations
│   └── services/      # DrinkFilterService, DrinkSortService
├── models/            # Data classes (Drink, Festival; Product/Producer in drink.dart)
├── providers/         # BeerProvider — orchestrates domain + manages UI state
├── screens/           # Full-page UI components
├── services/          # Infrastructure: BeerApiService, StorageService, AnalyticsService, etc.
└── widgets/           # Reusable UI components
test/                  # Unit and widget tests (mirrors lib/ structure)
cloudflare-worker/     # API proxy worker
```

### Architecture

The app uses a layered architecture:

**Domain layer** (`lib/domain/`) — pure business logic, no Flutter dependencies:
- `DrinkFilterService` — filtering by category, style, favourites, availability, search
- `DrinkSortService` — sorting strategies (name, ABV, brewery, style)
- `DrinkSort` enum — `lib/domain/models/drink_sort.dart`
- Repository interfaces — `DrinkRepository`, `FestivalRepository`

**State management** (`lib/providers/`) — `BeerProvider` orchestrates domain services, manages UI state, and notifies listeners. Named `BeerProvider` for historical reasons but manages all drink types.

**Infrastructure** (`lib/services/`):
- `BeerApiService` — HTTP API calls
- `FestivalService` — festival metadata
- `FavoritesService`, `RatingsService`, `FestivalStorageService` — SharedPreferences (all in `storage_service.dart`)
- `TastingLogService` — tasting log persistence
- `EnvironmentService` — environment/config detection
- `AnalyticsService` — Firebase Analytics/Crashlytics

**Data layer** (`lib/models/`):
- `Drink` — composite of Product + Producer
- `Product` — individual beverage (ABV, style, category, dispense)
- `Producer` — brewery/cidery
- `Festival` — festival metadata

---

## ⚡ Commands — Always Use Mise

**CRITICAL**: Always use `./bin/mise` commands, never raw `flutter` commands. Mise ensures the correct Flutter version (3.38.3) and consistency with CI.

### Discover Available Tasks First

```bash
./bin/mise tasks ls                   # Base tasks (CI/testing)
MISE_ENV=dev ./bin/mise tasks ls      # All tasks including build/serve
```

### Common Tasks

| Task | Command | Notes |
|------|---------|-------|
| **Pre-commit gate** | `./bin/mise run check` | **Run before every commit** |
| **Format all code** | `./bin/mise run format` | Runs all three formatters below |
| Format Dart | `./bin/mise run --no-deps dart:format` | **Run after every Dart change** — `--no-deps` skips unnecessary `pub get` |
| Watch Dart format | `MISE_ENV=dev ./bin/mise watch --skip-deps dart:format` | Auto-formats on save — needs `MISE_ENV=dev ./bin/mise install` first |
| Format JS/TS | `./bin/mise run prettier:format` | After JS/TS changes |
| Format mise.toml | `./bin/mise run mise:format` | After editing mise.toml |
| Generate code (mocks) | `./bin/mise run generate` | After model changes |
| Analyze code | `./bin/mise run analyze` | generate → analyze |
| Run tests | `./bin/mise run test` | generate → test |
| Run tests with coverage | `./bin/mise run coverage` | Includes code generation |
| Update golden files | `./bin/mise run goldens:update [file]` | Optional file arg to limit scope |
| Run dev server | `MISE_ENV=dev ./bin/mise run dev` | |
| Build for web (local) | `MISE_ENV=dev ./bin/mise run build:web` | For e2e testing |
| Build for production | `MISE_ENV=dev ./bin/mise run build:web:prod` | |
| Serve release build | `MISE_ENV=dev ./bin/mise run serve:release` | |

### Two Environments

1. **Base (`mise.toml`)** — `./bin/mise`: generate, test, coverage, analyze, validate:festivals, test:worker
2. **Developer (`mise.dev.toml`)** — `MISE_ENV=dev ./bin/mise`: dev, build:web, build:web:prod, serve:release, setup:playwright, test:e2e

**Rule**: Building or running the app → always use `MISE_ENV=dev`.

### CI → Mise Mapping

| CI Command | Mise Equivalent |
|------------|-----------------|
| `flutter pub get` | automatic (`mise deps`) |
| `dart run build_runner build --delete-conflicting-outputs` | `./bin/mise run generate` |
| `flutter analyze --no-fatal-infos` | `./bin/mise run analyze` |
| `flutter test --coverage` | `./bin/mise run coverage` |
| `flutter test` | `./bin/mise run test` |
| `flutter build web --release` | `MISE_ENV=dev ./bin/mise run build:web:prod` |

### Common Mistakes

```bash
# ❌ Don't do this
flutter test              # may use wrong Flutter version
flutter build web         # missing mise environment
mise run build:web        # missing MISE_ENV=dev

# ✅ Do this
./bin/mise run test
MISE_ENV=dev ./bin/mise run build:web
```

### Live Format Watching

`mise watch` (powered by `watchexec`, installed via `MISE_ENV=dev`) re-runs `dart format` automatically whenever a watched Dart file is saved. The `dart:format` task has `sources = ['lib/**/*.dart', 'test/**/*_test.dart']` — `lib/` fully covered, test files limited to hand-edited `*_test.dart` (generated `.mocks.dart` files are intentionally excluded to avoid noisy re-triggers).

```bash
# 1. Ensure watchexec is installed (dev env only)
MISE_ENV=dev ./bin/mise install

# 2. Start the watcher, capture output to a log file
WATCH_LOG=/tmp/mise-watch-fmt.log
MISE_ENV=dev ./bin/mise watch --skip-deps dart:format > "$WATCH_LOG" 2>&1 &

# 3. Arm a Monitor (use the Monitor tool with this command) so you're notified when format runs trigger
tail -f /tmp/mise-watch-fmt.log | grep --line-buffered -E "\[Running|formatted|changed|error"
```

`--skip-deps` skips the `generate` step on every save (runs only `dart format .`). The Monitor fires on `[Running: ...]` (format started) and `Formatted N files (M changed)` (format done).

### Running Tests Efficiently

`test` and `analyze` automatically save output to a temp file, print the path before the run starts, and print a ready-to-use grep command at the end. Run once, grep the file as many times as needed — do not re-run to grep different things.

```bash
# Run a specific test file or directory
./bin/mise run test test/widgets/drink_card_test.dart

# Run a specific analysis path
./bin/mise run analyze lib/screens/
```

> `TEST_LOG` and `ANALYZE_LOG` env vars let you override the temp file path if you need a stable location across multiple runs.

---

## Code Style

```dart
// Single quotes
final message = 'Hello, world!';

// const constructors
const EdgeInsets.all(16);

// final for local variables
final drinks = provider.drinks;

// Widget keys
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
}

// child/children last
Container(
  padding: const EdgeInsets.all(8),
  child: Text('...'),
)
```

**Linter rules enforced** (among others): `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `prefer_final_fields`, `avoid_print`, `prefer_single_quotes`, `sort_child_properties_last`, `use_key_in_widget_constructors`.

### Patterns

**Provider reads** — `context.watch<BeerProvider>()` in `build()` only (subscribes to rebuilds). `context.read<BeerProvider>()` in callbacks, `initState`, and post-frame callbacks (one-shot, no rebuild subscription). Analytics calls in `initState` must be deferred via `WidgetsBinding.instance.addPostFrameCallback()`.

**Navigation** — for drill-down navigation to content (drink detail, brewery), use `navigateToRoute()` from `lib/utils/navigation_helpers.dart`; it selects `context.go()` (web) or `context.push()` (mobile) automatically. For root/tab navigation that replaces the route stack (bottom nav, home button), use `context.go()` directly. Build URL paths with the typed helpers (`buildFestivalPath()`, `buildDrinkDetailPath()`, etc.) — never interpolate raw strings.

**Loading/error states** — four mutually exclusive signals on `BeerProvider`:

| Field | Widget | Condition |
|---|---|---|
| `_isLoading` | `CircularProgressIndicator` (full-screen) | cold load, no cached data |
| `_isRefreshing` | `LinearProgressIndicator(minHeight: 2)` at top | background network refresh |
| `_refreshNotice` (non-null) | dismissible banner | network failed, cached data shown |
| `_error` (non-null) | full error view with Retry | blocking failure, no data |

`_error` and `_refreshNotice` are never both non-null simultaneously.

**Analytics** — always `unawaited(_analyticsService.logX(...))`. Don't log trivial/empty values (e.g. skip `logSearch` when the query is blank).

**Null vs empty-set semantics** — `null` means "not set by user" or "unknown from API". For filter fields, empty `Set {}` means no filter is applied (show all); a non-empty `Set` means the filter is active. Filter fields are always initialized to `{}`, never `null`. Never use `0` or `''` as a sentinel for "not set".

**Multiple toggles** — prefer `enum` + `Set<EnumValue>` over separate boolean fields. Persist as `prefs.setStringList('key', filters.map((f) => f.name).toList())`. See `DrinkVisibilityFilter` for the established pattern.

**Tests** — mock generation uses mockito with `@GenerateNiceMocks([MockSpec<Foo>()])` (run `./bin/mise run generate` after adding annotations). Name test-data factory helpers `createSample{Model}()`. In widget tests, use `find.byKey(const ValueKey('id'))` for tappable elements and `find.widgetWithText(WidgetType, 'label')` to find options within lists.

---

## Accessibility Requirements

**CRITICAL**: Accessibility is NOT optional. See [`docs/code/accessibility.md`](docs/code/accessibility.md).

Standards: **WCAG 2.1 Level AA**, **ADA**, **Section 508**.

Every interactive element **must** have a `Semantics` wrapper with a meaningful `label`:

```dart
// ❌ BAD
IconButton(icon: Icon(Icons.favorite), onPressed: () => toggleFavorite())

// ✅ GOOD
Semantics(
  label: isFavourite ? 'Remove from favourites' : 'Add to favourites',
  button: true,
  hint: 'Double tap to toggle',
  child: IconButton(
    icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
    onPressed: () => toggleFavorite(),
  ),
)
```

Common patterns:

```dart
// Filter chips
Semantics(
  label: 'Filter by $styleName',
  value: isSelected ? 'Selected' : 'Not selected',
  button: true,
  child: FilterChip(...),
)

// Drink cards
Semantics(
  label: '${drink.name}, ${drink.abv}% ABV, by ${drink.breweryName}',
  hint: 'Double tap for details',
  button: true,
  child: InkWell(onTap: () => navigateToDetail(drink), child: DrinkCard(drink: drink)),
)

// Star ratings
Semantics(
  label: 'Rate this drink',
  value: '$rating out of 5 stars',
  child: Row(children: starWidgets),
)
```

**High-priority files**: `lib/widgets/drink_card.dart`, `lib/screens/drinks_screen.dart`, `lib/screens/festival_info_screen.dart`, `lib/main.dart`, `lib/widgets/star_rating.dart`.

All new interactive elements must have semantic tests verifying `label`, `button`, and `value` properties.

---

## Issue Tracking

GitHub Issues is the single source of truth for bugs, features, and tasks. **Do not use `docs/todos.md`** — it is archived.

### Before starting work

Check open issues at `https://github.com/richardthe3rd/cambridge-beer-festival-app/issues` to avoid duplicating work or missing context. Issues have triage comments with exact file paths, root causes, and recommended fixes.

### When you discover a bug or improvement

Create a GitHub issue rather than adding to a doc. A good issue has:
- A plain-language title (no conventional-commit prefix)
- Root cause and affected file + line number
- A concrete fix approach
- Appropriate labels: `bug` or `enhancement`, plus `priority:high` / `priority:medium` / `priority:low`

### In commits and PRs

Reference the issue number in the commit body or PR description: `Fixes #123` or `Closes #123`. This auto-closes the issue on merge and creates a permanent link between the fix and its context.

### Priority labels

| Label | Meaning |
|-------|---------|
| `priority:high` | Fix next — real user impact or data correctness |
| `priority:medium` | Fix soon — meaningful but not urgent |
| `priority:low` | Backlog — latent, polish, or speculative |

---

## Making Changes

Check existing patterns before starting. Run `./bin/mise run check` to establish a baseline (generate → analyze + test).

### Adding a New Screen

1. Create `lib/screens/new_screen.dart`
2. Export from `lib/screens/screens.dart`
3. Add route in `lib/router.dart`

```dart
class NewScreen extends StatelessWidget {
  const NewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

### Adding a New Model

1. Create `lib/models/new_model.dart`
2. Include `fromJson` and `toJson` methods
3. Export from `lib/models/models.dart`
4. Add tests in `test/`

### Adding a New Service

1. Create `lib/services/new_service.dart`
2. Export from `lib/services/services.dart`
3. Inject dependencies — don't use singletons
4. Include `dispose()` for cleanup

### Working with Provider State

```dart
// Reactive (triggers rebuild)
final provider = context.watch<BeerProvider>();

// One-time read
final provider = context.read<BeerProvider>();
provider.setCategory('beer');
```

Key methods: `initialize()`, `loadDrinks()`, `setFestival(Festival)`, `setCategory(String?)`, `setSearchQuery(String)`, `toggleFavorite(Drink)`, `setRating(Drink, int)`.

Adding new state:

```dart
String? _myField;
String? get myField => _myField;

void setMyField(String? value) {
  _myField = value;
  notifyListeners();
}
```

### Adding a New Sort Option

1. Add enum value to `DrinkSort` in `lib/domain/models/drink_sort.dart`
2. Add case to `DrinkSortService` in `lib/domain/services/drink_sort_service.dart`
3. Add option to sort dropdown in `drinks_screen.dart`

### Adding User Preferences

1. Add the key to `PreferenceKeys` (`lib/constants/preference_keys.dart`) and pin its value in `test/constants/preference_keys_test.dart`. **Never use an inline SharedPreferences key string** — a mistyped key reads back `null` and silently loses the user's data. All `prefs.getX`/`setX` calls reference `PreferenceKeys.*`.
2. Add to appropriate service (`FavoritesService`, `RatingsService`, or new)
3. Load in `BeerProvider.initialize()`

> **Changing an existing key's value** breaks data already stored under the old key — treat it as a data migration, not a rename. The pinned test will fail to force a deliberate decision.

> **Drink categories are dynamic** — they come from API data, no code changes needed to support new ones.

---

## Testing

### Test Structure

```dart
void main() {
  group('ModelName', () {
    test('fromJson parses correctly', () {
      final json = {'id': '1', 'name': 'Test'};
      final model = ModelName.fromJson(json);
      expect(model.id, '1');
      expect(model.name, 'Test');
    });
  });
}
```

Test files go in `test/` mirroring `lib/` structure.

### What to Test

- Model JSON parsing (all field types including type variants)
- Edge cases (null, missing, wrong type)
- Provider state changes
- Service API calls (with mocks)

### Deep vs Shallow Tests

```dart
// ❌ Shallow — only checks state variable, not visible behavior
testWidgets('festival switches', (tester) async {
  appRouter.go('/cbf2024');
  await tester.pumpAndSettle();
  expect(provider.currentFestival.id, 'cbf2024'); // INSUFFICIENT
});

// ✅ Deep — verifies what the user actually sees
testWidgets('festival switches and UI updates', (tester) async {
  expect(find.text('Cambridge 2025'), findsOneWidget);
  appRouter.go('/cbf2024');
  await tester.pumpAndSettle();
  expect(find.text('Cambridge 2024'), findsOneWidget);
  expect(find.text('Cambridge 2025'), findsNothing);
});
```

### Screenshot Tests

```dart
testWidgets('screen - light theme', (WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(createTestWidget());
  await tester.pumpAndSettle();
  await expectLater(find.byType(MyScreen), matchesGoldenFile('goldens/my_screen_light.png'));
});
```

To update golden files:
```bash
./bin/mise run goldens:update                                    # all goldens
./bin/mise run goldens:update test/my_screen_screenshot_test.dart  # specific file
```

### Asset Loading in Tests

Use `testWidgets()` (not plain `test()`) when loading assets — it ensures the asset bundle is available. Don't use `TestWidgetsFlutterBinding.ensureInitialized()` in plain tests.

### TDD Workflow (preferred for bug fixes)

For bug fixes — especially on pure Dart services and domain logic — use red/green/refactor:

1. **Red** — write the failing test first. If the code isn't testable (e.g. a `kIsWeb` guard blocks the VM), extract the logic into a `@visibleForTesting` pure static helper _before_ writing the tests. Tests call the helper directly; public methods delegate to it.
2. **Green** — write the minimal code change to make the failing tests pass.
3. **Refactor** — clean up with tests still green (improve defaults, remove redundancy, etc).

**Testability pattern for static utility classes** — prefer extracting a named pure helper over adding an optional parameter to the public method:

```dart
// Public API — unchanged signature, delegates to helper
static bool isProduction() {
  if (!kIsWeb) return true;
  return isProductionHost(Uri.base.host);
}

// Pure helper — all real logic, testable without a browser
@visibleForTesting
static bool isProductionHost(String hostname) { ... }
```

Tests call `isProductionHost(...)` directly, bypassing any platform guards. Note: lines that delegate to `Uri.base.host` will show as uncovered in Codecov — this is expected and acceptable, since the logic itself is fully covered via the helper.

---

## API Integration

**Base URL**: `https://data.cambeerfestival.app`
**Pattern**: `/{festivalId}/{category}.json`
**Categories**: `beer`, `cider`, `perry`, `mead`, `wine`, `international-beer`, `low-no`

### Data Structures

```json
// Festival registry
{ "festivals": [{ "id": "cbf2025", "name": "Cambridge Beer Festival 2025", "dataBaseUrl": "https://..." }], "defaultFestivalId": "cbf2025" }

// Beverage list — array of Producer objects
{ "id": "brewery-123", "name": "Brewery Name", "location": "City",
  "products": [{ "id": "beer-1", "name": "Beer Name", "category": "beer", "style": "IPA", "abv": "5.5", "dispense": "cask" }] }
```

### JSON Parsing Pattern

API field types vary — always handle all variants:

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

Other variant fields: allergens (`int`/`bool`/`num`), year founded (`int`/`String`). Always use `?.` and `??` for nullables.

### Documentation and Validation

Full API reference: [`docs/code/api/`](docs/code/api/)

Validate `web/data/festivals.json` against schema:
```bash
./bin/mise run validate:festivals
```

---

## CI/CD and Release

### CI/CD Pipeline

GitHub Actions runs on every PR and push to `main`:
1. **Build**: analyze, test, build web
2. **Deploy**: Cloudflare Pages (staging on `main`, preview URL per PR)
3. **Worker**: deploy Cloudflare Worker when changed

### Release Process

CalVer (`YYYY.M.patch`). See [`docs/processes/release.md`](docs/processes/release.md).

```bash
# 1. Bump version in pubspec.yaml (build number = YYYYMMDD)
git add pubspec.yaml && git commit -m "chore: bump version to 2026.5.2"
git push origin main

# 2. Tag to trigger deployment
git tag v2026.5.2 && git push origin v2026.5.2
```

Pushing the tag triggers `release-web.yml` (→ cambeerfestival.app) and `release-android.yml` (→ Google Play Internal track).

---

## Git Commit Best Practices

Run `./bin/mise run check` before committing — it enforces the generate → analyze → test sequence.

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body — what and why, not how>

Fixes #123
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Rules**: subject under 72 chars, imperative mood, body wrapped at 72 chars, reference issues in footer. Keep the whole message under ~20 lines.

### PR Title Rules

PR titles must also follow conventional commits format. CI will reject PRs with non-conforming titles via the `PR Lint` check.

```
feat(drinks): add low-alcohol filter
fix(router): handle missing festival ID
chore: bump Flutter to 3.38.3
```

---

## Engineering Standards

### Definition of Done

**Code complete** — passes automated checks (compiles, tests pass, analyzer clean, style correct).

**Production ready** — code complete + edge cases handled + error handling + accessibility verified. Only claim "production ready" when all of these are met. Note: manual browser/device testing cannot be performed by an agent and should be flagged as outstanding.

### Error Handling

Every external interaction needs error handling:

```dart
Future<List<Drink>> fetchDrinks(Festival festival) async {
  try {
    final response = await http.get(Uri.parse(festival.dataBaseUrl));
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
    return _parseDrinks(response.bodyBytes);
  } on SocketException {
    throw NetworkException('No internet connection');
  } on FormatException {
    throw DataException('Invalid JSON format');
  }
}
```

Always handle: null/missing API data, network failures, race conditions, empty states, uninitialized providers.

### Abstraction Guidelines

Create a helper when: logic is repeated 3+ times, it encapsulates data transformation, or it prevents common errors. Don't create helpers that just wrap a constant string or save a few characters — inline is better.

### Documentation Guidelines

Keep completion summaries under 150 lines. Focus on what changed and what needs testing. Don't repeat information already in code, use excessive emoji, or congratulate yourself.

---

## Do Not Modify

- `.github/workflows/` — without explicit request
- `cloudflare-worker/` — without explicit request
- `pubspec.yaml` — package versions without necessity
- `analysis_options.yaml`
