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

Flutter's built-in `integration_test` package was considered but not prioritised. It would run the full app in a test harness and can interact with widgets directly. This remains a valid option for future investment (tracked in todos.md item #1).

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

## Related Documents

- `docs/tooling/flutter-web-testing.md` -- how Playwright works with Flutter's canvas renderer
- `docs/planning/archive/patrol-firebase-testing/` -- the Patrol evaluation that was not implemented
