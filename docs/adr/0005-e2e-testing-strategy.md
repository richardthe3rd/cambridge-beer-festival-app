# ADR 0005: E2E Testing Strategy -- Playwright for URL Smoke Tests

**Status**: Accepted

**Date**: 2025-12-21

**Deciders**: Engineering Team

**Context**: The app needed automated end-to-end testing to validate routing and deep linking. Two approaches were evaluated: Patrol with Firebase Test Lab (native Flutter E2E on real Android devices) and Playwright (browser-based testing). Flutter web renders to a `<canvas>` element, which makes traditional DOM-based testing largely ineffective for UI interactions.

---

## Decision

We adopted **Playwright for URL and routing smoke tests only**, and deferred native E2E testing.

Playwright tests verify:
- URL routing works (correct URLs after navigation)
- Browser back/forward/refresh preserves routes
- No critical console errors on page load
- Basic ARIA label presence (accessibility smoke test)

Playwright tests **do not** verify:
- Visual appearance, layout, or rendered text
- Widget interactions (tapping buttons, filling forms)
- User flows (search, filter, favorite)
- Canvas-rendered content

Widget interactions are covered by Flutter's own `testWidgets` framework in `test/`.

---

## Alternatives Considered

### Patrol + Firebase Test Lab

A detailed plan was created (see `docs/planning/archive/patrol-firebase-testing/`) proposing:
- Native Flutter E2E tests using the Patrol framework
- Execution on real Android devices via Firebase Test Lab free tier (15 tests/day)
- 4-5 week implementation timeline across 5 phases

**Why it was not implemented:**
- Significant setup complexity (Firebase Test Lab, GCP service accounts, Android instrumentation builds)
- 4-5 week implementation investment for a pre-release app
- Free tier limit (15 tests/day) constrains CI usage
- Flutter widget tests already cover interaction flows effectively
- The immediate need was validating URL routing for the deep linking feature, not full native E2E

**When to reconsider:**
- If the app ships on Android/iOS and needs device-specific testing (permissions, system dialogs, push notifications)
- If visual regression testing becomes important
- If Flutter widget tests prove insufficient for catching real-world bugs

### Flutter Integration Tests

Flutter's built-in `integration_test` package was considered but not prioritised. It would run the full app in a test harness and can interact with widgets directly.

Reconsidered and declined again in August 2026 -- see the Amendment below.

---

## Consequences

### Positive

- Fast to implement (2 test files, ~440 lines)
- Validates the most critical web concern: URL routing works correctly
- Runs in CI without special infrastructure
- ARIA label checks enforce accessibility as a side effect
- No ongoing cost or quota limits

### Negative

- Cannot test actual user flows through the UI
- Cannot verify that the correct screen renders for a given URL
- Flutter canvas rendering means Playwright can never do meaningful UI testing for this app
- Gap between "URL works" and "screen works" -- a route could return 200 but render an error state

---

## Implementation

- **Config**: `playwright.config.ts`
- **Tests**: `test-e2e/app.spec.ts` (loading, console errors, ARIA), `test-e2e/routing.spec.ts` (URL routing, browser history)
- **Approach doc**: `docs/tooling/flutter-web-testing.md`
- **Journey tests**: `test/journeys/` (issue #314), over the shared
  harness in `test/support/app_harness.dart`

## Amendment (2026-08-26): `integration_test` reconsidered and declined

Issue #314 proposed adopting Flutter's `integration_test` package to cover six
key user journeys. It was reconsidered against this ADR and declined a second
time. The journeys were written as widget tests instead, in `test/journeys/`.

### Why declined

- **None of the reconsider-triggers above had fired.** No device-specific
  concern (permissions, system dialogs, push notifications) motivated the
  request, and widget tests had not proved insufficient -- the issue asked for
  journey coverage, not for device fidelity.
- **It buys the same API at a real CI cost.** `integration_test` uses the same
  `WidgetTester` API as `flutter_test`, so the tests would look identical. What
  it adds is a runner: chromedriver plus `flutter drive` for web, or an Android
  emulator (5-10 minutes to boot, and flaky). That is a recurring cost on every
  PR for no change in what the tests can express.
- **The widget layer already reaches app scope.** `buildAppRouter()` mounts the
  real production route table in-process, so a test can drive a multi-screen
  journey with real taps, drags and navigation in roughly a second. Two tests
  already did this before #314 (`drinks_screen_scroll_position_test.dart`,
  `navigation_stack_rebuild_test.dart`); the gap was breadth, not tooling.
- **A cold start needs no extra machinery.** Calling `go()` on a fresh router
  before the first `pumpWidget` resolves the route before the first frame --
  measured as one match in the stack, `canPop()` false, and the list screen
  never built. That is what a deep link does, and it needed no production
  change to arrange.

### What was measured

Line coverage before and after all six journeys, via `./bin/mise run coverage`:

| | lines hit / found | total |
|---|---|---|
| Before | 4518 / 4656 | 97.0% |
| After  | 4537 / 4656 | 97.4% |

The +19 lines fall in exactly three files -- `beer_festival_home.dart`,
`festival_menu_sheets.dart`, `overflow_menu.dart` -- all navigation *seams*,
the code that only runs when traversing between screens. Zero new lines in the
screens or the provider; those were already covered.

The conclusion this ADR records: **journey tests here buy composition
confidence, not coverage.** That is worth having -- both real findings in #314
were composition facts invisible to line coverage (a write path and a read path
that disagreed, and a "known limitation" that had silently been fixed) -- but it
is not a coverage argument, and should not be re-proposed as one.

### Consequence

The unused `integration_test` dev dependency was removed from `pubspec.yaml`.
It had been declared since before this ADR and never imported by a single Dart
file, which made the repo look like it used a runner it did not. Re-adding it
is a deliberate act requiring the triggers above to have fired.

---

## Related Documents

- `docs/tooling/flutter-web-testing.md` -- how Playwright works with Flutter's canvas renderer
- `docs/planning/archive/patrol-firebase-testing/` -- the Patrol evaluation that was not implemented
