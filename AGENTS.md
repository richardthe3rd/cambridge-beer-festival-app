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

## Skill Routing

This file is the always-on **spine**: universal rules and safety tripwires. The
**depth** lives in skills (loaded on demand). When your task matches a row, load
that skill — it has the file:line detail, the incident history, and the exact
commands.

| When you're… | Load skill |
|---|---|
| understanding how the app is built; deciding where state/logic lives; adding a screen, model, service, sort option, or persisted field | `architecture-contract` |
| writing or judging any test; updating goldens; TDD; semantics tests; "is this tested enough" | `validation-and-qa` |
| touching `lib/screens/**`, `lib/widgets/**`, `main.dart`, `app_theme.dart` — any visual change, restyle, new widget, or `Semantics` | `ui-and-accessibility` |
| aesthetic/visual-identity direction for a new UI or a from-scratch redesign — palette, typography pairing, layout concept, avoiding templated defaults (load *alongside* `ui-and-accessibility`, which governs this repo's Flutter/a11y rules) | `frontend-design` |
| committing, opening/merging a PR, deciding if a change is allowed, which CI gate fires, review-comment triage | `change-control` |
| running/building/serving/deploying, provisioning D1, cutting a release, editing `festivals.json` | `run-and-operate` |
| setting up the toolchain; mise/install failures; env vars; CI-vs-local parity; adding a mise task | `build-and-env` |
| measuring/decoding — test/analyze logs, minified web-crash stacks, coverage, headless page checks | `diagnostics-and-tooling` |
| figuring out what a symptom MEANS — stale drinks, festival flash, web crash, flaky test, CI/worker error | `debugging-playbook` |
| editing `proto/**` or `cloudflare-worker/reviews.ts` / `shared.ts`; any AIP / API-contract review comment | `api-contract` |
| the history behind a decision — "didn't we try this", "why was X removed", rejected alternatives, ADRs | `failure-archaeology` |
| what a domain term MEANS — dispense, allergens, `status_text`, D1, etag, AIP, CalVer | `reference` |
| any "My Festival" campaign work (#411/#413/#414/#415, cloud sync) | `my-festival-campaign` |
| `docs/**` taxonomy, ADRs, issue/commit/PR house style, completion summaries | `docs-and-writing` |

**Subagents inherit this file but NOT skills.** A spawned agent does not
auto-load a skill from the table above — when you spawn one, name the skills it
should read in its prompt (e.g. "READ FIRST: `.claude/skills/validation-and-qa/SKILL.md`").

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

The app uses a layered architecture (UI → provider → controllers → repositories
→ services → models). This is the component map; for the enforced layer
boundaries, the write-path invariants, and *where new logic belongs*, load skill
`architecture-contract`.

**Domain layer** (`lib/domain/`) — pure business logic, no Flutter dependencies:
- `DrinkFilterService` — filtering by category, style, favourites, availability, search
- `DrinkSortService` — sorting strategies (name, ABV, brewery, style)
- `DrinkSort` enum — `lib/domain/models/drink_sort.dart`
- Repository interfaces — `DrinkRepository`, `FestivalRepository`

**State management** (`lib/providers/`) — `BeerProvider` orchestrates domain services, manages UI state, and notifies listeners. Named `BeerProvider` for historical reasons but manages all drink types.

**Infrastructure** (`lib/services/`):
- `BeerApiService` — HTTP API calls
- `FestivalService` — festival metadata
- `UserDataStore` (`user_data_store.dart`) — unified, versioned SharedPreferences store for all per-user data (favourites/want-to-try, ratings, tasting log, notes). Replaced the former `FavoritesService`/`RatingsService`/`TastingLogService` (#391/#395). For the storage contract and schema-versioning rules, load skill `architecture-contract`.
- `FestivalStorageService` (`storage_service.dart`) — festival-selection persistence (the only remaining class in that file)
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

Discover tasks with `./bin/mise tasks ls` (add `MISE_ENV=dev` for build/serve
tasks, `--json` to parse). Task introspection, environment layering, CI-vs-local
parity, and adding a new task all live in skill `build-and-env`.

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

> **On Claude Code Web** (`CLAUDE_CODE_REMOTE=true`), `.miserc.toml` auto-selects the `claude-code-web` (`mise.claude-code-web.toml`) and `dev` envs, so plain `./bin/mise` already exposes the dev tasks (and pins Node to the baked `/opt/node22` + applies the git-transport fix). Do **not** prefix `MISE_ENV=dev` there — an explicit `MISE_ENV` overrides `.miserc.toml` and drops the web env. Locally and in CI, `MISE_ENV=dev` is still required.

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

The `Semantics` catalogue for every element type (filter chips, drink cards, star
ratings), the WCAG contrast rules, the screen patterns that must never regress,
and the golden-update protocol live in skill `ui-and-accessibility` — **load it
before touching anything under `lib/screens/**`, `lib/widgets/**`, `main.dart`,
or `app_theme.dart`.** Full standard: [`docs/code/accessibility.md`](docs/code/accessibility.md).

**Non-negotiable:** every new interactive element needs a `Semantics` wrapper
with a meaningful `label` (plus `button`/`value`/`hint` as appropriate) **and** a
semantic test verifying those properties. High-priority files:
`lib/widgets/drink_card.dart`, `lib/screens/drinks_screen.dart`,
`lib/screens/festival_info_screen.dart`, `lib/main.dart`,
`lib/widgets/star_rating.dart`.

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

Check existing patterns first; run `./bin/mise run check` for a baseline. For
*where* new state/logic belongs and the full layer contract, load skill
`architecture-contract`. Quick recipes:

- **New screen** — create `lib/screens/x.dart`, export from `screens.dart`, add a
  route in `router.dart`.
- **New model** — create under `lib/models/`, add `fromJson`/`toJson`, export from
  `models.dart`, add tests.
- **New service** — create under `lib/services/`, export from `services.dart`,
  inject dependencies (no singletons), add `dispose()`.
- **New sort option** — add a `DrinkSort` enum value, a case in
  `DrinkSortService`, and the option to the sort dropdown in `drinks_screen.dart`.
- **Provider state** — `context.watch<BeerProvider>()` in `build()` (subscribes to
  rebuilds); `context.read` in callbacks / `initState`. A new field = private
  backing + getter + setter that calls `notifyListeners()`.

**Adding a user preference:**
1. Add the key to `PreferenceKeys` (`lib/constants/preference_keys.dart`) and pin
   it in `test/constants/preference_keys_test.dart`. **Never use an inline
   SharedPreferences key string** — a mistyped key reads back `null` and silently
   loses the user's data.
2. Add the field to `UserDataStore` (per-user data), following its
   versioned-schema rules.
3. Load in `BeerProvider.initialize()`.

> **Changing an existing key's value** is a data migration, not a rename — the
> pinned test fails to force a deliberate decision.
> **Drink categories are dynamic** (from API data) — no code change to add one.

---

## Testing

Full test methodology, verified copy-paste skeletons for every test type in this
repo (model JSON, pure controller, mockito provider, GoRouter-wrapped widget,
golden, semantics, worker vitest), the TDD `@visibleForTesting` extraction
pattern, and the acceptance thresholds live in skill `validation-and-qa`. Load
it before writing or judging any test. The essentials that always apply:

**What to test** — model JSON parsing (all field-type variants), edge cases
(null / missing / wrong type), provider state changes, service API calls (with
mocks). Test files mirror `lib/` structure under `test/`.

**Deep, not shallow** — assert what the user *sees*, not just a state variable.
Checking `provider.currentFestival.id == 'cbf2024'` after a navigation is
insufficient; assert the new festival's name is on screen and the old one is
gone. This is the single most important test-quality rule here.

**Goldens** — update with `./bin/mise run goldens:update [test_file]`, review the
generated PNG by eye once; thereafter the diff is the regression guard. Screens
that navigate must be pumped inside a real `GoRouter` with a stub `/` route (see
`validation-and-qa`). Every new interactive element needs a `Semantics` label
**and** a semantic test.

---

## API Integration

**Base URL** `https://data.cambeerfestival.app` · **Pattern**
`/{festivalId}/{category}.json` · **Categories** `beer`, `cider`, `perry`,
`mead`, `wine`, `international-beer`, `low-no`. Full reference:
[`docs/code/api/`](docs/code/api/). For what fields *mean* and which are
type-unions → skill `reference`; for the v1alpha Review API + proto contract →
skill `api-contract`.

**Parse defensively — API field types vary.** Handle every variant and use
`?.`/`??` for nullables:

```dart
// ABV can be String, int, or double
final abvValue = json['abv'];
final double parsedAbv = abvValue is num
    ? abvValue.toDouble()
    : (abvValue is String ? double.tryParse(abvValue) ?? 0.0 : 0.0);
```

Other known variant fields: allergens (`int`/`bool`/`num`), year founded
(`int`/`String`). Validate the festival registry with
`./bin/mise run validate:festivals`.

---

## CI/CD and Release

CI runs on every PR and push to `main` (analyze, test, build web; a Cloudflare
Pages preview per PR; worker deploy when changed). **Merging to `main` deploys
to staging**; a CalVer tag (`vYYYY.M.patch`) triggers the production release
(`release-web.yml` → cambeerfestival.app, `release-android.yml` → Play
Internal). Which CI gate fires on which change → skill `change-control`; the
release-train runbook and its traps → skill `run-and-operate` (and
[`docs/processes/release.md`](docs/processes/release.md)).

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

**File manifests hide cross-file API coupling** — a tight manifest gives false confidence that the listed files are self-contained. Before fencing a manifest that *removes* a widget's constructor parameter, callback, public method, or export, grep for every call site first (`rg 'onFavoriteTap|DrinkCard\('`) — removing it breaks callers that are often outside the manifest, and the agent then either stalls or silently expands scope to fix them. If callers are out of scope, keep the parameter vestigial (unused) and delete it in a later pass. (2026-07-04: removing the drink-card heart in #413 would have broken four `onFavoriteTap` call sites; the fix was to retain the param.)

**Disjoint manifests ≠ safe union** — two agents on file-disjoint issues can each pass their own `check` yet break when merged, because neither tested against the other's changes (shared constructor params, renamed classes, dangling doc references). After integrating parallel branches, run one combined `analyze`+`test` on the union before pushing.

**Stuck agents** — a long-running agent with no commits is likely in a test-fix loop. If tests pass, the agent can commit and push; signing requires a path inside the repo directory.

**Format failures** — run `./bin/mise run --no-deps dart:format` before committing. Haiku agents doing substitutions sometimes produce formatting that CI rejects.

**Stale references after copyWith** — tests that capture a model reference before a mutation must re-read from the provider list after the mutation. The old reference is a snapshot of the pre-mutation object.

**Await async provider calls in widget tests** — `pumpAndSettle()` does not guarantee in-flight `Future`s have completed. Always `await provider.setRating(...)` etc. before asserting.

**Stable identity in list operations** — use `id + festivalId` (or equivalent domain key) to find items in lists, not object identity (`indexOf`). After `copyWith`, the old instance is no longer in the list.

**Verification agent** (optional, cheap) — after implementation, a haiku agent can cross-check: did every planned file change? did any unplanned file change? Catches drift before push.

---

## Review-Comment Defence Facts

Before acting on an automated review comment about the API contract or Dart
types, check the authoritative fact table first — many "this is wrong" comments
are themselves wrong when CI is green.

- **Proto / AIP contract** — etag `OUTPUT_ONLY`, soft-delete-returns-resource,
  List parent `type` vs `child_type`, batch `repeated google.rpc.Status
  statuses`, `optional` for signal fields: skill `api-contract` holds the full
  AIP table. **If a proposed fix needs to suppress an api-linter rule, that's a
  strong signal the fix is wrong** — look up the AIP first.
- **Dart / Flutter types** — `dart:io` exceptions have `const` constructors;
  `CertificateException` and `HandshakeException` both extend `TlsException`
  (so `e is TlsException` subsumes them); conditional-import stubs
  (`connectivity_io.dart` / `connectivity_web.dart`) stay out of barrel exports:
  skills `debugging-playbook` / `failure-archaeology`. If `flutter analyze`
  passes, a "this won't compile" comment is wrong (CI is ground truth).

---

## Debugging Flutter Web Crashes

A minified web-release stack (`main.dart.js:89998:16`) decodes to a Dart
file+line via a source map. Build with `--source-maps` (the default `build:web`
omits them), then decode — skill `diagnostics-and-tooling` has the full method
and ships a `decode-stack.mjs` helper (in that skill's own directory, not the
repo root). Traps it documents: CI's `--dart-define`s shift line numbers ~4 vs a
local build (try `line` and `line+4`); Flutter SDK sources live in the mise
tarball under `.mise/http-tarballs/`. What a crash *symptom* means (e.g. a web
"Null check operator" crash) → skill `debugging-playbook`.

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

For the full review-comment triage (when to act vs skip) and the CI-gate map, load skill `change-control`.

### Documentation Guidelines

Keep completion summaries under 150 lines. Focus on what changed and what needs testing. Don't repeat information already in code, use excessive emoji, or congratulate yourself.

---

## Do Not Modify

- `.github/workflows/` — without explicit request
- `cloudflare-worker/` — without explicit request
- `pubspec.yaml` — package versions without necessity
- `analysis_options.yaml`
