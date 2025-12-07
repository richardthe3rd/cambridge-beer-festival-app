# URL Routing Strategy

This document explains how URL routing works in the Cambridge Beer Festival app.

## Overview

The app uses **path-based routing** (e.g., `/favorites`, `/drink/123`) instead of **hash-based routing** (e.g., `/#/favorites`, `/#/drink/123`).

## Implementation

### Flutter Side

The app uses [go_router](https://pub.dev/packages/go_router) version 14.6.2 (or later) for routing.

**Path-based URL strategy must be explicitly enabled** by calling `usePathUrlStrategy()` before running the app. This is done in `lib/main.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'url_strategy_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // Configure path-based URLs for web (removes # from URLs)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();
  // ... rest of initialization
}
```

**Important:** Despite go_router supporting path-based routing, Flutter web defaults to hash-based URLs unless you explicitly call `usePathUrlStrategy()`. The conditional import ensures the code works on all platforms (web, iOS, Android).

### Web Server Configuration

For path-based routing to work correctly on deployed web apps, the web server must be configured to serve `index.html` for all routes (SPA fallback). This is because when a user navigates directly to a route like `/favorites`, the web server needs to serve the main `index.html` file, which then loads the Flutter app that handles the routing internally.

#### Cloudflare Pages (Production & Staging)

**File**: `web/_redirects`

```
/* /index.html 200
```

This tells Cloudflare Pages to serve `index.html` for all routes with a 200 status code. Cloudflare Pages natively supports the `_redirects` file format.

#### Local Development with http-server

For local testing, the project uses `http-server` with the `--proxy` flag to handle SPA routing:

```bash
npx http-server build/web -p 8080 -c-1 -a 127.0.0.1 --proxy http://127.0.0.1:8080?
```

The `--proxy` flag tells http-server to fall back to serving `index.html` for routes that don't exist as physical files, enabling proper SPA behavior during local development and E2E testing.

## Routes

The app supports the following routes:

- `/` - Home screen (drinks list)
- `/favorites` - Favorites screen
- `/about` - About screen
- `/festival-info` - Festival information screen
- `/drink/:id` - Drink detail screen (parameterized)
- `/brewery/:id` - Brewery screen (parameterized)
- `/style/:name` - Style screen (parameterized, URL-encoded)

## Testing

E2E tests in `test-e2e/routing.spec.ts` verify:
- Path-based URLs work correctly
- Deep linking to specific routes works
- Browser back/forward buttons work
- Page refresh preserves the current route

## Benefits of Path-Based Routing

1. **Better SEO**: Search engines can properly index individual pages
2. **Clean URLs**: URLs look cleaner and more professional
3. **Shareable Links**: Users can share direct links to specific content
4. **Standard Web Behavior**: Works like traditional websites
5. **Better Analytics**: Analytics tools can track page views more accurately

## Migration Notes

If you were previously using the app with hash-based routing, existing bookmarks with hash URLs (e.g., `/#/favorites`) will continue to work because go_router handles the migration automatically.

## Future Enhancements

### Slug-Based URLs (Optional Slugs)

To improve SEO and URL readability, we could add optional slugs to drink and brewery URLs:

**Current:**
- `/drink/abc123`
- `/brewery/brew456`

**Future (with optional slugs):**
- `/drink/abc123/bishops-finger-bitter`
- `/brewery/brew456/adnams-brewery`

**Implementation Approach:**

The slug would be optional and purely cosmetic - the ID remains the source of truth:

```dart
// Route accepts both with and without slug
GoRoute(
  path: '/drink/:id/:slug?',  // ? makes slug optional
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    // Slug is ignored - ID is the source of truth
    return DrinkDetailScreen(drinkId: id);
  },
)
```

**Benefits:**
- ✅ Better SEO (search engines read the slug)
- ✅ More human-readable URLs
- ✅ Easier to share on social media
- ✅ ID remains source of truth (robust, no collisions)
- ✅ Backward compatible (both `/drink/abc123` and `/drink/abc123/slug` work)

**Requirements:**
1. Add `slug` getter to `Drink` and `Producer` models
2. Update routes in `lib/router.dart` to accept optional `:slug?` parameter
3. Update navigation calls to include slugs: `context.go('/drink/${drink.id}/${drink.slug}')`
4. Add slug generation logic (sanitize name to URL-safe format)

**Example slug generation:**
```dart
String get slug => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');  // trim dashes
```