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

- **Flutter**: 3.44.0 | **Dart SDK**: >=3.10.0 <4.0.0 | **Platforms**: Android, iOS, Web

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

**CRITICAL**: Always use `./bin/mise` commands, never raw `flutter` commands. Mise ensures the correct Flutter version (3.44.0) and consistency with CI.

### Discover Available Tasks First

```bash
./bin/mise tasks ls                   # Base tasks (CI/testing)
MISE_ENV=dev ./bin/mise tasks ls      # All tasks including build/serve
```

Add `--json` when you need to parse the output rather than read it — most introspection commands support it, so prefer it over scraping the human-readable text:

```bash
./bin/mise tasks ls --json            # Task name, description, source, depends
./bin/mise ls --json                  # Installed tools + versions/paths
./bin/mise config ls --json           # Config files and their tools
./bin/mise env --json                 # Resolved environment variables
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

> **On Claude Code Web** (`CLAUDE_CODE_REMOTE=true`), `.miserc.toml` auto-selects the `sandboxed` and `dev` envs, so plain `./bin/mise` already exposes the dev tasks (and pins Node to the baked `/opt/node22` + applies the git-transport fix). Do **not** prefix `MISE_ENV=dev` there — an explicit `MISE_ENV` overrides `.miserc.toml` and drops the sandbox env. Locally and in CI, `MISE_ENV=dev` is still required.

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

### Screen Widget Tests

Screens that use navigation (`context.go()`, `context.push()`) must be wrapped in a real GoRouter in tests — pumping them as bare widgets throws a routing error. Use `MaterialApp.router` with a `GoRouter` that declares the initial route:

```dart
final router = GoRouter(
  initialLocation: '/${festival.id}/info',
  routes: [
    GoRoute(
      path: '/:festivalId/info',
      builder: (context, state) =>
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: FestivalInfoScreen(
              festivalId: state.pathParameters['festivalId']!,
            ),
          ),
    ),
    GoRoute(path: '/', builder: (_, __) => const Scaffold()),  // stub for back/home navigation
  ],
);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));
await tester.pumpAndSettle();
```

Always include a stub `/` route so any `context.go('/')` calls within the screen don't throw.

### Semantics Testing

Three strategies for asserting accessibility labels in widget tests, in order of use:

**1. Widget predicate** — finds a `Semantics` widget directly by its `properties.label`. Most reliable when you know the exact wrapper you added:

```dart
expect(
  find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == 'Open location in maps',
  ),
  findsOneWidget,
);
```

**2. Rendered semantics label** — searches the rendered a11y tree. Use `tester.ensureSemantics()` to enable semantics, assert, then dispose:

```dart
final handle = tester.ensureSemantics();
// ... pump widget ...
expect(find.bySemanticsLabel('Visit festival website'), findsOneWidget);
handle.dispose();
```

**3. Semantics node properties** — read `label`, `value`, `hint` off a specific node (useful for compound widgets like `StarRating`):

```dart
final semantics = tester.getSemantics(
  find.ancestor(of: find.byType(Row), matching: find.byType(Semantics)).first,
);
expect(semantics.label, 'Rating');
expect(semantics.value, '3 out of 5 stars');
```

**Gotcha: duplicate semantics nodes** — Flutter button widgets (e.g. `FilledButton.icon`) synthesise a semantics node from their visible text label. If you also wrap the button with an explicit `Semantics(label: '...')`, two nodes exist with the same label and `findsOneWidget` fails. Use `findsWidgets` instead, or prefer the widget predicate strategy.

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
chore: bump Flutter to 3.44.0
```

### GitHub MCP Notes

MCP tool parameters take plain strings — do not use `$(cat <<'EOF'...)` heredoc syntax in `body` fields; it will appear literally in the PR description or comment.

---

## Parallel Work with Subagents

Use `/ship-issues` for the full plan → implement → review → fix → PR → watch workflow. Use `/plan-issues` to plan only. Use `/address-review` to triage review comments on existing branches.

### Constraints (apply regardless of which command you use)

**Always use `isolation: "worktree"`** when spawning implementation agents. The managed environment's commit signing server only accepts commits from paths inside the repository directory — manual `/tmp/` worktrees cause signing to fail. Agent isolation creates worktrees at `.claude/worktrees/` automatically.

**Fix branches target `main` directly.** The session branch (`claude/session-*`) is for session-level changes only (AGENTS.md, commands, toolchain config).

### Model Selection

| Use haiku for | Use sonnet for |
|---|---|
| Single-file mechanical changes | Multi-file architectural changes |
| Tests following an established pattern | Nullable/sentinel patterns, type system changes |
| ≤2 files with a grep-based done signal | Cascading updates across 6+ files |

### Lessons Learned

**Scope creep** — the main failure mode. Hard file manifests + explicit "do not touch other files" instructions prevent it. Always diff against the base commit to confirm only planned files changed: `git diff $(git merge-base main fix/NNN)..fix/NNN --stat`

**Stuck agents** — a long-running agent with no commits is likely in a test-fix loop. If tests pass, the agent can commit and push; signing requires a path inside the repo directory.

**Format failures** — run `./bin/mise run --no-deps dart:format` before committing. Haiku agents doing substitutions sometimes produce formatting that CI rejects.

**Stale references after copyWith** — tests that capture a model reference before a mutation must re-read from the provider list after the mutation. The old reference is a snapshot of the pre-mutation object.

**Await async provider calls in widget tests** — `pumpAndSettle()` does not guarantee in-flight `Future`s have completed. Always `await provider.setRating(...)` etc. before asserting.

**Stable identity in list operations** — use `id + festivalId` (or equivalent domain key) to find items in lists, not object identity (`indexOf`). After `copyWith`, the old instance is no longer in the list.

**Verification agent** (optional, cheap) — after implementation, a haiku agent can cross-check: did every planned file change? did any unplanned file change? Catches drift before push.

---

## Proto / AIP Design Facts

Known facts to verify before acting on automated review comments about the proto API contract. **If a proposed fix would require suppressing an api-linter rule, treat that as a strong signal the fix is wrong** — look up the AIP first.

- **AIP-154 etag — OUTPUT_ONLY is correct; do not add a duplicate etag field to Update requests.** The `etag` field on a resource is `OUTPUT_ONLY` (server-managed). For If-Match concurrency control, AIP-154 routes the token differently by transport: proto-native clients echo `resource.etag` back in the resource field of the Update request body; REST/HTTP clients send it in the standard `If-Match` request header. A reviewer suggesting that `OUTPUT_ONLY` breaks OpenAPI clients is wrong — the correct fix is to document the `If-Match` header, not to add a `string etag` field to the request message (which the linter will reject with `0134::request-unknown-fields` and `0154::no-duplicate-etag`).

- **AIP-164 soft delete — Delete should return the resource, not Empty.** When a Delete method is a soft delete (sets `delete_time` rather than permanently removing the resource), it should return the updated resource so callers receive the tombstone's `delete_time` and new `etag` in one round-trip. Returning `google.protobuf.Empty` for a soft delete is an error.

- **AIP-132 List parent annotation — use `type` not `child_type` for grandparent-scoped Lists.** `child_type` on a `parent` field means the field holds the *immediate* parent of that resource type. If a List operates at a grandparent level (e.g. listing all `DrinkEntry` resources under `festivals/{festival}` when DrinkEntry's immediate parent is `drinks/{drink}`), the annotation should be `type = "api.cambeerfestival.app/Festival"`, not `child_type = "api.cambeerfestival.app/DrinkEntry"`.

- **AIP-235 batch responses must carry per-item status.** `BatchUpdateXxx` responses should include a parallel `repeated google.rpc.Status statuses` field (same length as the request list) so callers can identify which items failed and retry selectively. A response with only `repeated Resource items` cannot represent partial failure.

- **Proto `optional` keyword vs non-optional for signal fields.** Fields that represent "user has not yet set this" (star rating, pour count, favourite toggle) should be `optional T` so the absent state is distinguishable from an explicit zero/false on the wire. Non-optional fields where the zero value is meaningful (e.g. `string note` where `""` means "no note") are the exception, but document the zero-value semantics explicitly.

---

## Dart / Flutter Type Facts

Known facts to verify before acting on automated review comments:

- **`dart:io` exceptions have `const` constructors** — `SocketException`, `HandshakeException`, `HttpException`, `TlsException`, `CertificateException` all accept `const`. A reviewer claiming otherwise is wrong if `flutter analyze` passes.
- **`CertificateException extends TlsException`** — `e is TlsException` catches `CertificateException`. Both should be treated as connectivity failures.
- **`HandshakeException extends TlsException`** — `e is TlsException` subsumes `e is HandshakeException`; the latter is dead code when both appear in the same predicate.
- **Conditional import stubs** (`connectivity_io.dart` / `connectivity_web.dart`) must not be added to barrel exports (`services.dart`). They are only meaningful when imported together via the conditional import syntax in the file that uses them.

---

## Debugging Flutter Web Crashes

### Source maps

When a Flutter web release build crashes (e.g. from a Playwright console.error, a Crashlytics report, or a CI failure), the stack trace contains minified JS line numbers like `main.dart.js:89998:16`. Source maps decode these to original Dart file + line.

**Build with source maps:**
```bash
./bin/mise exec -- flutter build web --release --base-href "/" --source-maps
# Output: build/web/main.dart.js  +  build/web/main.dart.js.map
```

The standard `build:web` task does not pass `--source-maps`. Run the command above directly when you need them. Do **not** commit the source map — it is large (~3 MB) and not needed in production.

**Decode a position using the `source-map` npm package** (install temporarily, uninstall after):
```bash
npm install source-map   # temporary — uninstall when done

node -e "
const { SourceMapConsumer } = require('source-map');
const fs = require('fs');
const rawMap = JSON.parse(fs.readFileSync('build/web/main.dart.js.map', 'utf8'));
SourceMapConsumer.with(rawMap, null, (consumer) => {
  const pos = consumer.originalPositionFor({ line: 89998, column: 16 });
  console.log(pos.source + ':' + pos.line, pos.name);
});
"

npm uninstall source-map  # clean up
```

**Decode multiple frames at once:**
```javascript
const frames = [
  { line: 89998, column: 16, label: 'crash point' },
  { line: 89533, column: 25, label: 'caller' },
  // ...
];
SourceMapConsumer.with(rawMap, null, (consumer) => {
  for (const f of frames) {
    const pos = consumer.originalPositionFor({ line: f.line, column: f.column });
    const src = (pos.source || '?').replace(/.*packages\//, '');
    console.log(f.label, '->', src + ':' + pos.line, pos.name || '');
  }
});
```

### CI vs local line number offset

The CI web build passes `--dart-define=GIT_TAG=... --dart-define=GIT_COMMIT=... --dart-define=GIT_BRANCH=... --dart-define=BUILD_VERSION=... --dart-define=BUILD_TIME=...`. These inline different string constants than a local build (which has no dart-defines), shifting JS line numbers by roughly 4 lines. When decoding CI line numbers against a local source map, try both `line` and `line + 4` (the `SourceMapConsumer` returns null source for misses, so it's safe to try both).

To get line numbers that exactly match CI, rebuild locally with the same dart-defines:
```bash
./bin/mise exec -- flutter build web --release --base-href "/" --source-maps \
  --dart-define=GIT_TAG=local --dart-define=GIT_COMMIT=local \
  --dart-define=GIT_BRANCH=local --dart-define=BUILD_VERSION=local \
  --dart-define=BUILD_TIME=local
```

### Locating Flutter SDK source

When a crash decodes to `flutter/lib/src/widgets/navigator.dart:6047`, the SDK file lives inside the mise Flutter install tarball:

```
.mise/http-tarballs/<hash>/packages/flutter/lib/src/widgets/navigator.dart
```

There are usually two tarballs (old and new Flutter versions). Pick the one matching your current build.

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

### CI and Coverage

**CI is ground truth.** If tests and analyzer pass, a "this won't compile" or "this is wrong" review comment is incorrect — skip it rather than acting on it.

**Coverage warnings are informational** unless the `codecov/patch` check itself fails (not just the comment). A Codecov comment noting a drop does not require a fix.

**Pure refactors inherit prior coverage.** Moved code that was untested before is not a new gap — do not add tests solely to satisfy a coverage comment on unchanged logic.

### Documentation Guidelines

Keep completion summaries under 150 lines. Focus on what changed and what needs testing. Don't repeat information already in code, use excessive emoji, or congratulate yourself.

---

## Do Not Modify

- `.github/workflows/` — without explicit request
- `cloudflare-worker/` — without explicit request
- `pubspec.yaml` — package versions without necessity
- `analysis_options.yaml`
