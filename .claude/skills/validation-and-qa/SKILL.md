---
name: validation-and-qa
description: Load before writing or judging ANY test in the Cambridge Beer Festival app, before claiming a change is "tested" or "verified," before updating golden screenshots, or when deciding what kind of test a change needs. Triggers — "write a test for X", "is this test good enough", "update the goldens", "add a semantics test", "what counts as done here", "TDD this bug fix", "does this need a widget test or a unit test", "the coverage dropped", "can I say this was manually tested". Provides the evidence hierarchy (unit/widget > goldens > worker vitest > Playwright smoke > manual — with Playwright's hard canvas-rendering limitation spelled out), the deep-vs-shallow test doctrine, verified copy-paste skeletons for every test type in this repo (model JSON, pure controller, mockito provider, GoRouter-wrapped widget, golden, semantics, worker vitest, functions vitest), the TDD red/green/refactor workflow with the `@visibleForTesting` extraction pattern, acceptance thresholds (coverage, analyzer, format), and the definition of done including what an agent can never verify.
---

# Validation and QA

How to decide a change is actually correct in this repo, and how to write the
test that proves it. Every skeleton below is copied from a real, currently
passing test file — file:line citations let you go read the full context.

## When NOT to use this skill

- **Running test infrastructure** (installing Flutter/mise, `TEST_LOG`/`ANALYZE_LOG`
  mechanics, CI parity) → skill `build-and-env` for setup, skill
  `run-and-operate` for running tasks.
- **Coverage tooling mechanics** (lcov inspection, per-file coverage, source-map
  crash decoding) → skill `diagnostics-and-tooling`.
- **UI-change policy** (incremental widget changes, redesign scar tissue,
  navigation-helper usage, festival-flash guard) → skill `ui-and-accessibility`.
  This skill only covers *how to test* UI, not *how to change* it.
- **Debugging a specific failing test** (pumpAndSettle/copyWith/GoRouter/
  semantics/golden flakiness) → skill `debugging-playbook` has the symptom
  table; come back here for the *correct pattern* once you know the cause.

---

## 1. The evidence hierarchy

Ranked by how much it actually proves, strongest first. A change is not "tested"
until it clears the layer appropriate to what changed — reaching for a weaker
layer when a stronger one applies is the shallow-test failure mode in §2.

| Rank | Layer | Proves | Command |
|---|---|---|---|
| 1 | **Unit / widget tests** (`test/`, `flutter_test`) | Actual logic and rendered behavior, in-process | `./bin/mise run test` |
| 2 | **Golden screenshots** (`test/goldens/`) | Pixel-level layout regressions | `./bin/mise run test`, update via `./bin/mise run goldens:update` |
| 3 | **Worker vitest** (`cloudflare-worker/test/`, workerd runtime) | Real HTTP/D1 behavior of the API worker | `./bin/mise run test:worker` |
| 4 | **Playwright URL/ARIA smoke** (`test-e2e/`) | Routing mechanics and gross console errors on a *deployed-shape* build | `MISE_ENV=dev ./bin/mise run test:e2e` |
| 5 | **Manual device testing** | Real user experience | Human only — see below |

### The Playwright hard limitation (read this before trusting an e2e pass)

Flutter web renders the entire UI to a single `<canvas>` element. Playwright
drives the DOM/accessibility tree, not the canvas pixels. This means Playwright
**can never verify what the UI actually looks like or says** — it can only
prove URL/routing mechanics, gross JS errors, and the ARIA/`lang` baseline
Flutter exposes around the canvas.

Concretely: **a route can return HTTP 200 and Playwright can pass, while the
screen underneath is rendering a full-page error state.** A 200 + "no critical
console errors" is not evidence the feature works — it is evidence the app
booted. This is codified in `docs/adr/0005-e2e-testing-strategy.md`, which also
records why the alternative (Patrol + Firebase Test Lab — native device E2E)
was evaluated and rejected: 4-5 week setup cost, Firebase Test Lab free-tier cap
of 15 tests/day, and Flutter widget tests already covering interaction flows.
Reconsider Patrol only if the triggers in that ADR fire (device-specific
concerns: permissions, system dialogs, push notifications).

What `test-e2e/` actually covers today (verify against the files, not memory):
- `app.spec.ts` — page loads, title, `flt-glass-pane` present, viewport meta,
  ≤2 "critical" console errors tolerated, `main.dart.js` loaded, ARIA/`lang`
  baseline.
- `routing.spec.ts` — URL mechanics: `/`, `/{festival}`, `/{festival}/favorites`,
  `/about`, `/{festival}/info`, deep links to drink/brewery, style-name
  lowercasing, invalid-festival redirect, back/forward/refresh.
- `csp-smoke.spec.ts` — zero `securitypolicyviolation` events. **Only meaningful
  run against a deployed Pages URL** — CI's `smoke-test-preview` job is the only
  place this is exercised (a local `http-server` doesn't reproduce Cloudflare's
  CSP headers).

None of these read rendered text, tap a button, or fill a form. If your change
needs "does clicking Favorite actually toggle the star", that is a widget test
in `test/`, never an e2e spec.

### Manual device testing — human-only, never claim it

An agent cannot open a phone, tap a real screen, or judge visual polish. Per
AGENTS.md's Definition of Done: **"manual browser/device testing cannot be
performed by an agent and should be flagged as outstanding."** Never write
"manually tested on Android" or similar in a commit, PR description, or
completion summary — if it wasn't run through a tool call you can show output
for, say "not verified; needs manual confirmation" instead.

---

## 2. Deep vs shallow test doctrine

A test that only inspects a state variable is not proof the user sees anything
different. Assert what render on screen, not what the provider privately holds.

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

Apply the same standard everywhere: a provider test that only checks
`provider.someFlag` when a widget consumes that flag to change rendered text
is testing half the contract. Prefer asserting on `find.text(...)`,
`find.byIcon(...)`, or a `SemanticsNode`'s `label`/`value` over a raw field
read, whenever a widget test is in scope at all.

---

## 3. Test-type recipes

Every skeleton below is trimmed from a real file — read the cited file for
full context (imports, teardown, more cases) before copying.

### 3.1 Model JSON parsing (type variants)

API fields vary in type across festivals/years (`abv` as string or number,
`allergens` as int/bool, etc — see skill `reference` for the full data-feed
reality). Test every variant plus the missing/null case.

`test/models_test.dart:6-66` (`Product.fromJson`):

```dart
test('fromJson parses correctly', () {
  final json = {
    'id': 'test-id-123', 'name': 'Test Beer', 'category': 'beer',
    'style': 'IPA', 'dispense': 'cask', 'abv': '5.5',
    'is_vegan': true, 'allergens': {'gluten': 1},
  };
  final product = Product.fromJson(json);
  expect(product.abv, 5.5);          // string → double
  expect(product.isVegan, isTrue);
});

test('fromJson handles missing optional fields', () {
  final product = Product.fromJson({
    'id': 'test-id', 'name': 'Basic Beer', 'category': 'beer',
    'dispense': 'cask', 'abv': '4.0',
  });
  expect(product.style, isNull);
  expect(product.allergens, isEmpty);
});

test('fromJson maps missing id and name to empty strings', () {
  final product = Product.fromJson({'id': null, 'name': null, ...});
  expect(product.id, '');   // never .toString() a nullable id — see #272 below
});
```

`test/models_test.dart:68-120` covers `availabilityStatus`: exact-match string
map (`'Sold out'` → `AvailabilityStatus.out`), plus the explicit unknown-phrase
case (`'Not yet available'` → `AvailabilityStatus.unknown`, not a substring
guess). This exact-match discipline exists because substring matching used to
mis-bucket `"Some beer remaining"` as `low` (issue #348) — never regress to
`.contains('out')`-style matching on free-text status fields.

### 3.2 Pure controller unit tests (no Flutter, no mocks)

Domain controllers (`lib/domain/controllers/`) are plain synchronous Dart —
they take input via `setSource`/setters and expose derived getters. No
`WidgetTester`, no mock repositories.

`test/domain/controllers/festival_controller_test.dart:1-46`:

```dart
Festival createSampleFestival({
  String id = 'cbf2025',
  List<String> beverageTypes = const ['beer'],
}) => Festival(
  id: id, name: 'Test Festival',
  availableBeverageTypes: beverageTypes,
  dataBaseUrl: 'https://data.example.com/$id',
);

void main() {
  group('FestivalController', () {
    late FestivalController controller;
    setUp(() => controller = FestivalController());

    test('isFestivalsDataStale is true when no refresh recorded', () {
      expect(controller.isFestivalsDataStale, isTrue);
    });

    test('sets currentFestival to defaultFestival when none previously selected', () {
      final festivals = [createSampleFestival(id: 'cbf2025')];
      controller.setSource(festivals, defaultFestival: festivals.first);
      expect(controller.currentFestival.id, equals('cbf2025'));
    });
  });
}
```

Same pattern for `DrinkFilterController`
(`test/domain/controllers/drink_filter_controller_test.dart`),
`UserDrinkStateController`, `UserPreferencesController`. These files
deliberately push filter/sort *semantics* down to
`test/domain/services/drink_filter_service_test.dart` and
`drink_sort_service_test.dart` — the controller test only covers what the
controller adds (criteria state, derived facets, lifecycle), per the comment
at the top of `drink_filter_controller_test.dart:6-15`. Don't duplicate
semantics coverage at the wrong layer.

### 3.3 Provider tests (mockito `@GenerateNiceMocks`)

`BeerProvider` takes repositories via constructor injection (no singletons),
so tests mock `DrinkRepository`/`FestivalRepository`/`AnalyticsService`.

`test/provider_test.dart:1-53`:

```dart
import 'provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DrinkRepository>(),
  MockSpec<FestivalRepository>(),
  MockSpec<AnalyticsService>(),
])
void main() {
  late MockDrinkRepository mockDrinkRepository;
  late MockFestivalRepository mockFestivalRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockDrinkRepository = MockDrinkRepository();
    mockFestivalRepository = MockFestivalRepository();
    mockAnalyticsService = MockAnalyticsService();
    SharedPreferences.setMockInitialValues({});

    when(mockFestivalRepository.getFestivals()).thenAnswer(
      (_) async => FestivalsResponse(
        festivals: [DefaultFestivals.cambridge2025],
        defaultFestivalId: DefaultFestivals.cambridge2025.id,
        version: '1.0', baseUrl: 'https://data.cambeerfestival.app',
      ),
    );
    when(mockFestivalRepository.getSelectedFestivalId())
        .thenAnswer((_) async => null);
  });

  test('shows user-friendly message for 404 error', () async {
    final provider = BeerProvider(
      drinkRepository: mockDrinkRepository,
      festivalRepository: mockFestivalRepository,
      analyticsService: mockAnalyticsService,
    );
    await provider.initialize();
    when(mockDrinkRepository.getDrinks(any))
        .thenThrow(BeerApiException('Not found', 404));
    await provider.loadDrinks();
    expect(provider.error, contains('Festival data not found'));
  });
}
```

After adding `@GenerateNiceMocks`/`@GenerateMocks` annotations, run
`./bin/mise run generate` (`dart run build_runner build
--delete-conflicting-outputs`) to produce `<file>.mocks.dart`.

> **Doc drift, verify before trusting `test/README.md`**: that file claims
> generated `.mocks.dart` files are gitignored and never committed. That is
> false today — `.gitignore:151-153` explicitly *un-ignores*
> `test/*.mocks.dart` and `test/**/*.mocks.dart`, and six are committed:
> `provider_test.mocks.dart`, `services_test.mocks.dart`,
> `utf8_encoding_test.mocks.dart`,
> `domain/repositories/api_drink_repository_test.mocks.dart`,
> `domain/repositories/api_festival_repository_test.mocks.dart`,
> `widgets/festival_menu_sheets_test.mocks.dart`. Trust `.gitignore` and
> `git ls-files test | grep mocks.dart` over the README.

### 3.4 Widget tests: GoRouter wrapping + async provider calls

Any screen using `context.go()`/`context.push()` throws a routing error if
pumped as a bare widget. Wrap in a real `GoRouter` with the screen's route
**and a stub `/` route** so any internal `context.go('/')` doesn't throw.

`test/festival_info_screen_test.dart:80-110` (verified working skeleton):

```dart
Future<void> pumpScreen(WidgetTester tester, Festival festival) async {
  when(mockFestivalRepository.getFestivals()).thenAnswer(
    (_) async => FestivalsResponse(
      festivals: [festival], defaultFestivalId: festival.id,
      version: '1.0', baseUrl: 'https://data.cambeerfestival.app',
    ),
  );
  await provider.initialize();

  final router = GoRouter(
    initialLocation: '/${festival.id}/info',
    routes: [
      GoRoute(
        path: '/:festivalId/info',
        builder: (context, state) => ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: FestivalInfoScreen(
            festivalId: state.pathParameters['festivalId']!,
          ),
        ),
      ),
      GoRoute(path: '/', builder: (_, _) => const Scaffold()), // stub for back/home nav
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}
```

**`pumpAndSettle()` does not guarantee an in-flight `Future` has completed.**
Always `await` provider mutator calls directly before asserting — do not rely
on pump alone. And after any mutation that goes through `Drink.copyWith`
(favourite/rating/tasted), the pre-mutation `Drink` reference you captured
earlier is a stale snapshot — re-read the drink from the provider by id.

`test/beer_provider_test.dart:2696-2714` (both gotchas in one example):

```dart
final drink = provider.allDrinks.first;

when(mockDrinkRepository.toggleTasted(any, any)).thenAnswer(
  (_) async => UserDrinkState(tastingEvents: [DateTime.now()], ...),
);
await provider.toggleTasted(drink);                              // await, not pump
expect(provider.getDrinkById(drink.id)!.userState, isNotNull);

when(mockDrinkRepository.toggleTasted(any, any)).thenAnswer((_) async => null);
await provider.toggleTasted(provider.getDrinkById(drink.id)!);    // re-read, not `drink`
expect(provider.getDrinkById(drink.id)!.userState, isNull);
```

Stable identity for list lookups is `id + festivalId` (see
`Drink.==`/`hashCode`, `drink.dart:312-323`) — never `indexOf` or an object
reference, both of which break after `copyWith` produces a new instance.

### 3.5 Golden (screenshot) tests

Repo-wide golden inventory is exactly **4 PNGs**, all in `test/goldens/`:
`drink_detail_screen_long_name_light.png`,
`drink_detail_screen_medium_name_light.png`,
`style_screen_with_description_dark.png`,
`style_screen_with_description_light.png` — produced by
`test/drink_detail_screen_screenshot_test.dart` and
`test/style_screen_screenshot_test.dart`. There is no `test/widgets/goldens/`.

`test/drink_detail_screen_screenshot_test.dart:82-119`:

```dart
testWidgets('DrinkDetailScreen with long drink name - light theme', (tester) async {
  when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drinkLongName]);
  await provider.loadDrinks();

  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(createTestWidget('drink1'));
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(DrinkDetailScreen),
    matchesGoldenFile('goldens/drink_detail_screen_long_name_light.png'),
  );
});
```

Update goldens with:

```bash
./bin/mise run goldens:update                                              # all
./bin/mise run goldens:update test/drink_detail_screen_screenshot_test.dart # one file
```

**Never blind-regenerate.** `goldens:update` overwrites the reference PNGs with
whatever the current build renders — if the current build has the bug you're
trying to catch, regenerating bakes the bug in as the new "correct" answer.
Always view the diff (or the regenerated PNG) before committing an updated
golden, and explain in the PR *why* the visual changed.

### 3.6 Semantics (accessibility) tests — 3 strategies

Every interactive element needs a `Semantics` wrapper per AGENTS.md's
accessibility section (WCAG 2.1 AA / ADA / Section 508). Three ways to assert
it, in order of preference:

**1. Widget predicate** — find the `Semantics` widget directly by its
`properties.label`. Most reliable when you added the wrapper yourself.
`test/festival_info_screen_test.dart:217`, `test/widgets/festival_menu_sheets_test.dart:364,423,749,861`:

```dart
expect(
  find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == 'Open location in maps',
  ),
  findsOneWidget,
);
```

**2. Rendered semantics label** — enable the a11y tree, search it, dispose.
`test/festival_info_screen_test.dart:290-301`:

```dart
final handle = tester.ensureSemantics();
try {
  await pumpScreen(tester, createSampleFestival());
  expect(find.bySemanticsLabel('View app source code on GitHub'), findsOneWidget);
} finally {
  handle.dispose();
}
```

**3. Semantics node properties** — read `label`/`value` off a specific node;
needed for compound widgets like `StarRating` where the label alone doesn't
capture the current rating. `test/widgets/star_rating_test.dart:49-53,59,69`:

```dart
SemanticsNode outerSemantics(WidgetTester tester) => tester.getSemantics(
  find.ancestor(of: find.byType(Row), matching: find.byType(Semantics)).first,
);
expect(outerSemantics(tester).label, 'Rating');
expect(outerSemantics(tester).value, '3 out of 5 stars');
```

**Gotcha: duplicate semantics nodes.** Button widgets (`FilledButton.icon`,
etc) synthesise a semantics node from their own visible text label. If you also
wrap the button in an explicit `Semantics(label: '...')` with the *same* text,
two nodes now share that label and `findsOneWidget` fails spuriously. Use
`findsWidgets` instead, verified live at
`test/festival_info_screen_test.dart:334-344` (`'Donate to Water Aid'` uses
`findsWidgets`, not `findsOneWidget`), or prefer strategy 1 (widget predicate),
which doesn't have this ambiguity.

### 3.7 Worker tests (`cloudflare-worker/`)

Real workerd runtime via `@cloudflare/vitest-pool-workers` — not a Node mock.
D1 migrations are applied automatically to a simulated database; no live D1
needed for tests.

`cloudflare-worker/vitest.config.js`: `readD1Migrations('./migrations')` is
read at config time, exposed as the `TEST_MIGRATIONS` binding, and applied by
the `setupFiles: ['./test/apply-migrations.js']` hook — every test run starts
from a clean, fully-migrated simulated D1.

`cloudflare-worker/test/reviews.test.js:1-46`:

```javascript
import { env, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import worker from "../worker.js";

async function send(method, path, { body, origin = TEST_ORIGIN, device = DEVICE } = {}) {
  const request = new Request(`https://worker.example.com${path}`, {
    method, headers: { Origin: origin, "X-Device-Id": device },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM reviews").run(); // real D1 query, real reset
});
```

Run with `./bin/mise run test:worker` (`npm ci && npm run typecheck && npm test`
in `cloudflare-worker/`, base env — no `MISE_ENV=dev` needed).

### 3.8 Functions tests (`functions/`) — the honest gap

`functions/[festivalId]/drink/[category]/[drinkId].js` is a Cloudflare Pages
Function that injects Open Graph meta tags for social-media crawlers using the
real `HTMLRewriter` API at runtime. Its tests (`functions/test/*.test.js`) run
under **plain Node vitest**, not workerd — `HTMLRewriter` doesn't exist in
Node, so `functions/test/handler.test.js:5` hand-rolls a `MockHTMLRewriter`
class and `vi.stubGlobal("HTMLRewriter", MockHTMLRewriter)`.

This is a real, accepted gap: **the actual Cloudflare `HTMLRewriter` behavior
is never exercised by any automated test** — only the mock's approximation of
it. If you change the OG-tag injection logic, treat this layer as necessary
but not sufficient; a change here has no automated proof against the real
runtime (functions ship colocated with the Pages web build with no separate
workerd-based test harness, unlike `cloudflare-worker/`).

Run locally with `cd functions && npm ci && npm test` (`vitest run` — there is
no mise task wrapping this; CI's `ci.yml` `test` job runs it directly after the
Flutter test step).

### 3.9 E2E — pointer only

Full run/build/serve recipe (setup:playwright, build:web, serve, `test:e2e`) is
owned by skill `run-and-operate`. This skill only covers what e2e can and
cannot prove — see §1 above.

---

## 4. TDD workflow for bug fixes

Preferred for bug fixes, especially in pure Dart domain logic
(`lib/domain/`, `lib/services/`):

1. **Red** — write the failing test first, against the smallest testable unit.
   If the real code path is blocked by a platform guard (`kIsWeb`, `Uri.base`),
   don't try to fake the platform — extract the logic first (see below).
2. **Green** — the minimal code change that makes the failing test(s) pass.
3. **Refactor** — clean up with tests still green (defaults, dead branches,
   naming) — no behavior change at this step.

### Testability extraction pattern (`kIsWeb` / platform guards)

Prefer extracting a named pure `@visibleForTesting` helper over adding an
optional parameter to the public method signature. Real, shipped example —
issue **#269** (unknown hostnames were defaulting to "production", polluting
analytics from Cloudflare Pages preview deploys):

`lib/services/environment_service.dart` (verified against
`test/environment_service_test.dart:1-72`):

```dart
// Public API — unchanged signature, delegates to the pure helper.
static bool isProduction() {
  if (!kIsWeb) return true;
  return isProductionHost(Uri.base.host);
}

// Pure helper — all real logic, testable on the Dart VM without a browser.
@visibleForTesting
static bool isProductionHost(String hostname) { ... }
```

Tests call `isProductionHost(...)` directly on the VM, bypassing the `kIsWeb`
guard entirely:

```dart
test('unknown host → false', () {
  // Safe default: unknown hosts should not be treated as production
  // to avoid accidentally logging staging/test traffic.
  expect(EnvironmentService.isProductionHost('mystery.example.com'), isFalse);
});
```

**Expected-uncovered note**: the one line that delegates to `Uri.base.host`
inside `isProduction()` will show as uncovered in Codecov, because VM tests
never execute the `kIsWeb` branch. This is expected and acceptable — the real
logic is fully covered via the helper; don't add a web-only test harness just
to paint that delegation line green.

---

## 5. Acceptance thresholds

| Gate | Requirement | Enforced by |
|---|---|---|
| Coverage (project) | ≥70%, 1% threshold | `codecov.yml` `coverage.status.project.default` |
| Coverage (patch) | ≥70%, 1% threshold | `codecov.yml` `coverage.status.patch.default` |
| Analyzer | clean at `flutter analyze --no-fatal-infos` | CI `analyze` job / `./bin/mise run analyze` |
| Dart format | `dart format --output=none --set-exit-if-changed .` | CI `fmt` job (`dart:format:check`) |
| Prettier (JS/TS) | `prettier --check` | CI `fmt` job |
| Shell scripts | `shfmt -d` clean | CI `fmt` job |

Run the local pre-commit gate with `./bin/mise run check` (format → analyze →
test), per AGENTS.md — this is the same sequence CI runs, so a clean local
`check` should mean a clean CI run.

### What is NOT blocking

- **Codecov PR *comments*** are informational only. The gate is the
  `codecov/patch` and `codecov/project` **status checks** — if those pass,
  a comment noting a coverage drop does not require action.
  (`fail_ci_if_error:false` is also set on the CI upload step itself.)
- **Coverage on pure refactors.** Code that was untested before a move/rename
  is not a new gap just because Codecov's diff view shows it as "added" lines.
  Don't write tests solely to satisfy a coverage comment on logic that didn't
  change.
- Per AGENTS.md's CI-is-ground-truth rule: if analyzer and tests pass, a
  reviewer comment claiming "this won't compile" or "this is untested" is
  wrong — skip it rather than act on it. (This does not excuse skipping a
  failing `codecov/patch` *check* — only the *comment* is informational.)

---

## 6. Definition of done

Per AGENTS.md's Engineering Standards:

- **Code complete** — passes automated checks: compiles, `./bin/mise run test`
  passes, `./bin/mise run analyze` is clean, formatting gates pass.
- **Production ready** — code complete **+** edge cases handled **+** error
  handling **+** accessibility verified (semantics tests, not just visual
  inspection). Only use the phrase "production ready" when all of these hold.

### What an agent genuinely cannot verify — say so, don't fake it

- Manual device/browser behavior (§1) — flag as outstanding, never claim it.
- Real visual appearance beyond the 4 committed goldens — Playwright cannot
  see the canvas (§1); a passing e2e run is not evidence of correct rendering.
- The real Cloudflare `HTMLRewriter` behavior in `functions/` (§3.8) — only the
  Node mock is exercised.
- CSP header behavior anywhere except a deployed Pages URL (`csp-smoke.spec.ts`
  only runs in CI's `smoke-test-preview` job).
- Whether a real D1 database in production behaves like the simulated D1 in
  `cloudflare-worker/test/` — migrations are exercised, but `wrangler.toml`'s
  `database_id` is still the placeholder `00000000-...` until a real
  `wrangler d1 create` + `wrangler d1 migrations apply` has run.

---

## 7. Conventions

- **`createSample{Model}()` factories are per-file, not shared.** Every test
  file that needs a `Festival`/`Drink`/`Product` builds its own local factory
  function with sensible defaults and named-parameter overrides (see §3.1's
  `createSampleFestival` in `festival_controller_test.dart` vs the differently
  shaped one in `festival_info_screen_test.dart`). Don't extract a shared
  fixtures file — each test file owns the shape it needs.
- **Test layout mirrors `lib/`.** `test/domain/controllers/` ↔
  `lib/domain/controllers/`, `test/domain/services/` ↔ `lib/domain/services/`,
  `test/widgets/` ↔ `lib/widgets/`, etc. A minority of legacy top-level files
  (`provider_test.dart`, `beer_provider_test.dart`, `models_test.dart`,
  `services_test.dart`, screen tests) live flat in `test/` rather than mirrored
  subdirectories — follow the existing sibling file's location for the module
  you're touching rather than inventing a new subdirectory.
- **Asset loading needs `testWidgets()`.** Use `testWidgets()` (not plain
  `test()`) whenever a test loads assets — it ensures the asset bundle is
  available. Don't reach for `TestWidgetsFlutterBinding.ensureInitialized()` in
  a plain `test()` as a workaround.

---

## Provenance and maintenance

Written 2026-07-02. Verified against the working tree at that date: read
`test/models_test.dart`, `test/domain/controllers/festival_controller_test.dart`,
`test/domain/controllers/drink_filter_controller_test.dart`,
`test/provider_test.dart`, `test/festival_info_screen_test.dart`,
`test/beer_provider_test.dart`, `test/drink_detail_screen_screenshot_test.dart`,
`test/widgets/star_rating_test.dart`, `test/environment_service_test.dart`,
`test/constants/preference_keys_test.dart`, `test/README.md`, `.gitignore`,
`codecov.yml`, `mise.toml`, `cloudflare-worker/vitest.config.js`,
`cloudflare-worker/test/reviews.test.js`, `functions/test/handler.test.js`,
`functions/package.json`, `docs/adr/0005-e2e-testing-strategy.md`, and
`git ls-files test | grep mocks.dart`.

Re-verify facts likely to drift:

```bash
# Golden inventory (currently exactly 4 files)
ls test/goldens/

# Committed mock files (currently 6 — contradicts test/README.md, trust this)
git ls-files test | grep mocks.dart

# Coverage thresholds
cat codecov.yml

# Whether functions/ has gained a mise task
grep -n functions mise.toml mise.dev.toml

# Worker test runtime confirmation (workerd pool, not Node)
grep -n "vitest-pool-workers" cloudflare-worker/vitest.config.js

# ADR 0005 still the accepted e2e strategy (status line at top of file)
head -5 docs/adr/0005-e2e-testing-strategy.md
```
