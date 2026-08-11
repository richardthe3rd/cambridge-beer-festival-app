---
name: code-review-dart
description: Dart and Flutter language facts for reviewing this repository. Load before commenting on any .dart file — especially before claiming code "will not compile", "is not valid syntax", "is missing a break", or "is a type error". This package tracks recent Dart and Flutter releases, so modern language features (null-aware elements, pattern matching, switch expressions, records, sealed classes, class modifiers) are all valid here and are frequently mistaken for errors. Tells you where to read the current SDK constraint, and provides the language-feature table, the false positives this reviewer has already produced with their PR links, the local lint baseline, and the review areas that are actually useful on this codebase.
---

# Reviewing Dart in the Cambridge Beer Festival app

This repository's automated reviews have a single dominant failure mode:
**syntax and type claims made against an outdated mental model of Dart.**
Every "this will fail to compile" comment posted here so far has been wrong,
and each one cost a maintainer a round-trip to refute.

This skill exists to stop that. Read it before writing any comment about a
`.dart` file.

## 1. Look up the language version before you judge syntax

**Read it from the source. Do not trust a version restated in prose — including
anywhere in this file.**

| What | File | Look for |
|---|---|---|
| Dart SDK constraint | `pubspec.yaml` | `environment:` → `sdk:` |
| Flutter version | `mise.toml` | `flutter = "…"` |

Everything the Dart language gained up to and including that floor is available
and in active use here. Check the floor against the feature table in §4 before
calling anything a syntax error.

If a construct looks unfamiliar, the overwhelmingly likely explanation is that
it is a language feature newer than your prior, not a bug. This repository has
tracked recent Flutter releases closely — an outdated assumption about the
version is the single most common cause of a wrong review comment here.

## 2. The rule that outranks every other rule in this skill

**CI compiles this code before you review it.**

`./bin/mise run check` runs `generate → analyze → test`. The `analyze` job runs
`flutter analyze` **without** `--no-fatal-infos`, so *every* diagnostic — error,
warning, and info — fails the build. The test job runs the full suite (1300+
tests).

Therefore: **if the checks are green, the code compiles.** A comment asserting
otherwise is not a finding, it is a false positive. Do not post it. There is no
phrasing of "this should fail to compile" that is useful on a green commit —
verify against the checks first, and if they pass, review something else.

Corollary: a suggestion that would *introduce* a lint violation is a
regression, not an improvement (see §3.1 — reverting the null-aware entries
would have failed `analyze`).

## 3. Verified false positives — do not repeat these

Each entry below is a real comment posted on this repository, followed by the
fact that refuted it.

### 3.1 Null-aware elements are valid Dart

**Claimed** (PR #540, twice): *"`?description` is not valid Dart map-literal
syntax and will fail to compile."*

**Fact**: `key: ?value` is a **null-aware map entry**, stable since **Dart 3.8**.
It omits the entry entirely when the value is null. The list/set form is
`[?maybeNull]`. Live examples — `grep -rn "': ?" test/`:

- `test/domain/controllers/drink_filter_controller_test.dart`
- `test/widgets/drink_card_test.dart`

These are not stylistic. The `use_null_aware_elements` lint (from
`flutter_lints`) *flags* the older `if (x != null) 'key': x` form, and since
infos are fatal here, the old form fails `analyze`. The suggested "fix" would
have broken the build.

### 3.2 Non-empty `switch` cases do not need `break`

**Claimed** (PR #519): *"each `case` must end control flow; as written this
should fail to compile."*

**Fact**: **Dart 3.0** removed the fall-through requirement for non-empty
`switch` cases. `break` is unnecessary and often flagged as redundant. See the
`case AvailabilityStatus.*` bodies in `lib/screens/my_festival_screen.dart` for
the shipped pattern.

### 3.3 `dart:io` exception constructors are `const`

`SocketException`, `HttpException`, `TlsException` and friends have `const`
constructors. A comment claiming `const` cannot be used with them is wrong.

### 3.4 `CertificateException` and `HandshakeException` extend `TlsException`

A single `on TlsException` catch **subsumes both**. Do not suggest adding
separate catch clauses for them — that is dead code, and `dead_code: error` in
`analysis_options.yaml` makes it a build failure.

Related: do **not** suggest classifying exceptions by
`runtimeType.toString()` against a name set. That approach was implemented,
found fragile, and deliberately removed (issue #324, PR #376). Suggesting its
return re-opens a settled decision.

### 3.5 Conditional-import stubs stay out of barrel files

`lib/services/connectivity_io.dart` and `connectivity_web.dart` are paired
stubs selected at `lib/services/beer_api_service.dart:5` via
`import 'connectivity_web.dart' if (dart.library.io) 'connectivity_io.dart';`.

They are **intentionally absent** from `lib/services/services.dart`. Exporting
them from the barrel defeats the conditional selection and breaks the web
build. Do not suggest "you forgot to export these".

## 4. Modern Dart — check the SDK floor before flagging

These "since" versions are language history and never change. Compare them
against the floor you read from `pubspec.yaml` in §1; anything at or below it is
valid here. Before claiming any of the following is a syntax error, assume it is
correct:

> This table is not above correction. It shipped claiming null-aware elements
> landed in Dart 3.9; a Copilot review comment on PR #546 correctly pointed out
> they landed in **3.8**, and the row was fixed. If a "since" version here looks
> wrong, check <https://dart.dev/resources/language/evolution> and say so — that
> is a real finding, unlike a compile claim against green CI.

| Feature | Since | Form |
|---|---|---|
| Null-aware elements | 3.8 | `[?x]`, `{?x}`, `{'k': ?v}` |
| Records | 3.0 | `(int, String)`, `(name: 'x')` |
| Patterns / destructuring | 3.0 | `final (a, b) = pair;`, `if (x case Foo(:final y))` |
| Switch expressions | 3.0 | `final s = switch (x) { A() => 1, _ => 0 };` |
| Sealed / base / final / interface classes | 3.0 | `sealed class Status {}` |
| Non-fall-through switch cases | 3.0 | no `break` needed |
| Enhanced enums with members | 2.17 | `enum E { a; const E(); void m() {} }` |
| `super` parameters | 2.17 | `const Foo({super.key})` — **required** by lint |

## 5. This repo's enforced style — do not suggest against it

These are lint-enforced in `analysis_options.yaml`. Suggesting the opposite
creates a build failure:

- **Single quotes** (`prefer_single_quotes`)
- **`const` constructors wherever possible** (`prefer_const_constructors`,
  `prefer_const_declarations`)
- **`final` locals and fields** (`prefer_final_locals`, `prefer_final_fields`)
- **`super` parameters**, not `Key? key` forwarding (`use_super_parameters`)
- **`child`/`children` last** in widget argument lists
  (`sort_child_properties_last`)
- **Trailing commas required** (`require_trailing_commas`)
- **Every `Future` awaited or `unawaited(...)`** (`unawaited_futures`) — in
  `test/` exactly as in `lib/`
- **Relative imports within the package** (`prefer_relative_imports`)
- **No `print()`** (`avoid_print`) — use `debugPrint()`
- **No dynamic invocations** (`avoid_dynamic_calls`)

The analyzer also runs `strict-casts`, `strict-inference`, and
`strict-raw-types`. Bare `[]` / `{}` literals with uninferable element types
and raw generics (`PopupMenuButton` rather than `PopupMenuButton<String>`) are
already build failures — flagging them adds nothing.

## 6. Where review effort is actually worth spending

The comments that have landed well on this repository were about behaviour and
consistency, not syntax. Prioritise:

1. **Accessibility.** Every interactive element needs a `Semantics` wrapper
   with a meaningful `label` (plus `button` / `value` / `hint`). A new
   `IconButton`, `GestureDetector`, or tappable card without one is a real
   finding. Standard: WCAG 2.1 AA (`docs/code/accessibility.md`).
2. **Defensive JSON parsing.** Upstream API field types vary by festival year:
   `abv` may be `String`/`int`/`double`, `allergens` `int`/`bool`/`num`, year
   founded `int`/`String`. Parsing that assumes one type is a real bug.
3. **Provider access discipline.** `context.watch<T>()` only in `build()`;
   `context.read<T>()` in callbacks, `initState`, and post-frame callbacks.
   A `watch` in a callback or a `read` driving rebuild is a real finding.
4. **Navigation helpers.** Route paths are built with the typed helpers in
   `lib/utils/navigation_helpers.dart` (`buildFestivalPath()`,
   `buildDrinkDetailPath()`, …), never raw string interpolation. Drill-down
   navigation uses `navigateToRoute()`; root/tab navigation uses `context.go()`.
5. **Preference keys.** Every SharedPreferences key lives in
   `lib/constants/preference_keys.dart` and is pinned by
   `test/constants/preference_keys_test.dart`. An inline key string is a real
   bug — it reads back `null` and silently loses user data.
6. **Doc/comment accuracy.** Comments that no longer match the code they
   describe are worth flagging and cheap to fix.
7. **Test depth.** Assertions on what the user *sees*, not just a state
   variable — checking `provider.currentFestival.id` after a navigation is
   shallow; asserting the new festival's name is on screen is not.

## 7. Things that are settled — do not re-litigate

| Suggestion | Why it is closed |
|---|---|
| Rename the `/:festivalId/favorites` route | Deep links and bookmarks are a public contract (issue #414 states it verbatim). The screen, label, and icon change; the URL never does. |
| Broad error suppression by message string | `isBenignRestorationError()` did this and was removed for hiding real regressions (issue #386, PR #408). |
| Loosen `analysis_options.yaml` to fix a lint | The lint baseline is the enforced house style and is on the do-not-modify list. |
| Add tests solely to raise coverage on a pure refactor | Moved, unchanged code inherits prior coverage. Only a failing `codecov/patch` check blocks. |
| Suppress an api-linter rule to satisfy a proto suggestion | A fix needing a suppression is a strong signal the fix is wrong — check the AIP first. |

## 8. Comment hygiene

- Do not open with praise or a summary of the diff.
- One finding per comment, anchored to the line it concerns.
- State the concrete failure — inputs or state, and the wrong result. "Consider
  refactoring" without a failure mode is noise.
- If uncertain whether a construct is valid Dart, **say nothing**. A silent
  reviewer costs nothing; a confident wrong compile claim costs a maintainer a
  refutation round-trip, and this repo has paid that cost repeatedly.
