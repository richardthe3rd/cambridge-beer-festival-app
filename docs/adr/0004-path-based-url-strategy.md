# ADR 0004: Path-Based URL Strategy for Deep Linking

**Status**: Accepted

**Date**: 2025-12-21

**Deciders**: Engineering Team

**Context**: The app needed shareable, bookmarkable URLs for festival drinks, breweries, and styles. Two approaches were considered: hash-based URLs (`/#/drink/123`) and path-based URLs (`/drink/123`). The app was pre-release with no existing shared URLs or search engine indexing, so there were no backward-compatibility constraints.

---

## Decision

We adopted **festival-scoped, path-based URLs** with GoRouter and `usePathUrlStrategy()`.

### URL Structure

```
/{festivalId}                    → Festival home (drinks list)
/{festivalId}/favorites          → Favorites for this festival
/{festivalId}/drink/{drinkId}    → Drink detail
/{festivalId}/brewery/{id}       → Brewery detail
/{festivalId}/style/{styleName}  → Style detail (lowercase canonical)
/{festivalId}/info               → Festival info
/about                           → About (global, not festival-scoped)
```

### Key Design Choices

1. **Festival ID as URL root** -- every drink/brewery/style URL is scoped to a festival, enabling cross-festival deep links
2. **Lowercase canonical style URLs** -- `buildStylePath()` lowercases style names for consistent URLs
3. **URL encoding** -- all user-provided IDs are encoded via `Uri.encodeComponent()`
4. **Pre-release advantage** -- no redirect logic or legacy URL support needed

---

## Alternatives Considered

### Hash-Based URLs (`/#/drink/123`)

- Simpler: no server-side SPA routing config needed
- Rejected because: poor SEO, unprofessional appearance, not shareable on social media

### Flat URLs without festival scoping (`/drink/123`)

- Simpler routing, fewer path segments
- Rejected because: can't distinguish same drink ID across different festivals; can't share a link to "this year's festival"

---

## Consequences

### Positive

- Clean, shareable URLs that work on social media
- Festival context is always visible in the URL
- Browser back/forward works correctly
- Bookmarks and shared links are self-contained

### Negative

- Requires SPA fallback routing on the server (Cloudflare Pages `_redirects` or `--proxy` flag on http-server)
- Detail routes currently lack festival ID validation (documented as known limitation, see todos.md H3)
- Festival selector UI doesn't update the URL when switching festivals (see todos.md C3)

---

## Implementation

- **Router**: `lib/router.dart` (GoRouter configuration)
- **URL builders**: `lib/utils/navigation_helpers.dart`
- **E2E tests**: `test-e2e/routing.spec.ts` (Playwright URL smoke tests)
- **Server config**: `--proxy` flag on http-server for SPA fallback

## Related Documents

- `docs/code/routing.md` -- current routing implementation details
- `docs/code/navigation.md` -- navigation helper API reference
