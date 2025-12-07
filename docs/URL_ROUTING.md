# URL Routing Strategy

This document explains how URL routing works in the Cambridge Beer Festival app.

## Overview

The app uses **path-based routing** (e.g., `/favorites`, `/drink/123`) instead of **hash-based routing** (e.g., `/#/favorites`, `/#/drink/123`).

## Implementation

### Flutter Side

The app uses [go_router](https://pub.dev/packages/go_router) version 14.6.2 (or later) for routing. Starting from go_router 7.0.0, path-based URL strategy is the default on web platforms, so no additional configuration is needed in the Flutter code.

### Web Server Configuration

For path-based routing to work correctly on deployed web apps, the web server must be configured to serve `index.html` for all routes (SPA fallback). This is because when a user navigates directly to a route like `/favorites`, the web server needs to serve the main `index.html` file, which then loads the Flutter app that handles the routing internally.

We support two deployment targets:

#### 1. Cloudflare Pages (Production & Staging)

**File**: `web/_redirects`

```
/* /index.html 200
```

This tells Cloudflare Pages to serve `index.html` for all routes with a 200 status code. Cloudflare Pages natively supports the `_redirects` file format.

#### 2. GitHub Pages (Development)

**File**: `web/404.html`

GitHub Pages doesn't support the `_redirects` format, so we use a 404.html fallback that redirects to the root URL using a meta refresh tag. 

**Note**: This approach has a limitation - direct links to specific routes (e.g., `/favorites`) will redirect to the home page `/` on GitHub Pages. This is acceptable for the development environment. For production and staging deployments, use Cloudflare Pages which properly handles path-based routing.

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