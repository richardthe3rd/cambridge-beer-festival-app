# Online Rating Service — Design Plan

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend | Cloudflare Workers + D1 | Existing Worker infra, SQL aggregation, unified stack |
| Identity | Firebase Anonymous Auth (client-side only) | Cross-device upgrade path, no Firebase backend needed |
| Rating model | Simple star rating (1-5) | Matches existing UI, low complexity |
| API response | Average + count + distribution + user's own rating | Full data for rich UI |
| Endpoints | Single-drink + batch | Stars on list screen without N+1 requests |
| Anti-abuse | DB UNIQUE constraint (one rating per user per drink) | Sufficient for festival scale; upgrade to rate-limit table if needed |
| Batch endpoint | Aggregates only (no per-user data) | Fully cacheable; client uses local ratings for "my rating" |
| Festival metadata | Embed `festivals.json` at build time (same as data proxy) | Single source of truth for IDs, end dates, validation |
| Drink ID validation | Trust client (don't validate) | No incentive to fabricate; orphan rows are harmless |
| Offline | Optimistic local + background sync | Festival venues have patchy signal |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App                                            │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Firebase Auth │  │ RatingsService│  │ BeerProvider │  │
│  │ (Anonymous)   │  │ (local cache) │  │              │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                  │          │
│         │    ┌────────────┴──────────────┐   │          │
│         │    │  OnlineRatingService       │   │          │
│         └───►│  - sends Firebase UID      │◄──┘          │
│              │  - optimistic local update │              │
│              │  - background sync queue   │              │
│              └────────────┬──────────────┘              │
└───────────────────────────┼─────────────────────────────┘
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────┐
│  Cloudflare Worker (ratings-api)                        │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Auth         │  │ Rate Limiter │  │ Router       │  │
│  │ Middleware   │  │ (per-UID)    │  │              │  │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                │                  │          │
│         └────────────────┴──────────────────┘          │
│                          │                              │
│                    ┌─────▼─────┐                       │
│                    │ D1 SQLite │                       │
│                    │ Database  │                       │
│                    └───────────┘                       │
└─────────────────────────────────────────────────────────┘
```

---

## 1. Cloudflare Worker — Ratings API

### 1.1 New Worker or Extend Existing?

**Recommendation: New Worker (`cbf-ratings-api`)**

Reasons:
- Existing worker is a stateless CORS proxy — different concern
- Ratings worker needs D1 database binding
- Separate deployment lifecycle (ratings API can change without touching the data proxy)
- Separate rate limiting and auth middleware
- Can share the same CORS utility code

### 1.2 D1 Database Schema

```sql
-- Individual ratings (one per user per drink per festival)
CREATE TABLE ratings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  festival_id TEXT NOT NULL,
  drink_id TEXT NOT NULL,
  user_id TEXT NOT NULL,          -- Firebase Anonymous UID
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (festival_id, drink_id, user_id)
);

-- Indexes for common queries
CREATE INDEX idx_ratings_drink ON ratings (festival_id, drink_id);
CREATE INDEX idx_ratings_user ON ratings (user_id, festival_id);

-- Pre-computed aggregates (updated on write via trigger or application code)
CREATE TABLE rating_aggregates (
  festival_id TEXT NOT NULL,
  drink_id TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  sum INTEGER NOT NULL DEFAULT 0,
  dist_1 INTEGER NOT NULL DEFAULT 0,
  dist_2 INTEGER NOT NULL DEFAULT 0,
  dist_3 INTEGER NOT NULL DEFAULT 0,
  dist_4 INTEGER NOT NULL DEFAULT 0,
  dist_5 INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (festival_id, drink_id)
);
```

**Why pre-computed aggregates?**
- The batch endpoint would otherwise require `GROUP BY` across all drinks per request
- Pre-computed table makes batch reads a simple `SELECT *` — fast and cheap
- Updated atomically with each rating insert/update via application logic

### 1.3 API Endpoints

Base URL: `https://ratings.cambeerfestival.app` (or `cbf-ratings-api.<subdomain>.workers.dev`)

#### `PUT /api/v1/{festivalId}/drinks/{drinkId}/rating`

Submit or update a rating.

**Request:**
```json
{
  "rating": 4
}
```

**Headers:**
```
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Response (200):**
```json
{
  "userRating": 4,
  "average": 4.2,
  "count": 37,
  "distribution": { "1": 2, "2": 3, "3": 5, "4": 12, "5": 15 }
}
```

**Why PUT?** Idempotent — same user rating the same drink twice just updates. Safe to retry on network failure.

#### `DELETE /api/v1/{festivalId}/drinks/{drinkId}/rating`

Remove the user's rating.

**Headers:**
```
Authorization: Bearer <firebase-id-token>
```

**Response (200):**
```json
{
  "userRating": null,
  "average": 4.1,
  "count": 36,
  "distribution": { "1": 2, "2": 3, "3": 5, "4": 11, "5": 15 }
}
```

#### `GET /api/v1/{festivalId}/drinks/{drinkId}/rating`

Get rating stats for a single drink (includes user's own rating if authenticated).

**Headers:**
```
Authorization: Bearer <firebase-id-token>  (optional)
```

**Response (200):**
```json
{
  "userRating": 4,
  "average": 4.2,
  "count": 37,
  "distribution": { "1": 2, "2": 3, "3": 5, "4": 12, "5": 15 }
}
```

#### `GET /api/v1/{festivalId}/ratings`

Batch endpoint — community aggregates for all drinks at a festival. No auth required. No per-user data.

**Response (200):**
```json
{
  "festivalId": "cbf2025",
  "ratings": {
    "drink-id-1": {
      "average": 4.2,
      "count": 37,
      "distribution": { "1": 2, "2": 3, "3": 5, "4": 12, "5": 15 }
    },
    "drink-id-2": {
      "average": 3.8,
      "count": 12,
      "distribution": { "1": 0, "2": 1, "3": 3, "4": 5, "5": 3 }
    }
  }
}
```

**Caching:** Fully cacheable — `Cache-Control: public, max-age=60`. Same response for all users. The client already knows the user's own ratings from local storage (SharedPreferences).

**Upgrade path (Phase 4 — cross-device):** Add `GET /api/v1/{festivalId}/ratings/mine` to return the user's ratings from the server, for syncing across devices.

### 1.4 Auth Middleware

The Worker verifies Firebase ID tokens using [`firebase-auth-cloudflare-workers`](https://github.com/Code-Hex/firebase-auth-cloudflare-workers):

```js
import { Auth } from 'firebase-auth-cloudflare-workers';

// In request handler:
const auth = Auth.getOrInitialize(env.FIREBASE_PROJECT_ID, env.PUBLIC_JWK_CACHE_KV);
const token = await auth.verifyIdToken(jwt);
const userId = token.uid;
```

**How it works under the hood:**
1. Extracts token from `Authorization: Bearer <token>`
2. Fetches Google's public keys (cached in Workers KV — auto-refreshes on rotation)
3. Verifies JWT signature (RS256) using Web Crypto API
4. Validates claims: `iss`, `aud`, `exp`, `sub`
5. Returns decoded token with `uid` (the Firebase Anonymous UID)

**Requirements:**
- KV namespace binding (`PUBLIC_JWK_CACHE_KV`) for public key caching
- `FIREBASE_PROJECT_ID` env var
- Supports Firebase Auth Emulator for local dev/testing

No Firebase Admin SDK, no Node.js runtime dependency.

### 1.5 Rate Limiting

**Launch approach:** Rely on the DB `UNIQUE` constraint (one rating per user per drink). No additional rate limiting for v1.

The constraint prevents duplicate ratings. At festival scale (~2K writes/day), even a bot hammering updates on the same rating can't corrupt data or exhaust D1's free tier (100K writes/day).

**Upgrade path:** If abuse is observed in Cloudflare Analytics, add a D1 `rate_limits` table with per-user sliding window. Backwards-compatible — just an extra middleware check.

### 1.6 Write Path (Rating Submission)

```
1. Validate auth token → extract user_id
2. Validate festivalId against embedded festivals.json → reject if unknown or ended
3. Validate request body (rating 1-5)
4. UPSERT into ratings table
5. Update rating_aggregates table:
   - If new rating: increment count, add to sum, increment dist_N
   - If update: adjust sum and dist_N columns (subtract old, add new)
   - If delete: decrement count, subtract from sum, decrement dist_N
6. Return updated aggregate + user's rating
```

All done in a single D1 transaction for consistency.

---

## 2. Flutter App Changes

### 2.1 New Dependencies

```yaml
# pubspec.yaml
dependencies:
  firebase_auth: ^5.3.0    # For anonymous auth (already have firebase_core)
```

No other new dependencies needed — HTTP calls use existing Dart `http` package.

### 2.2 New Service: `OnlineRatingService`

**Location:** `lib/services/online_rating_service.dart`

```dart
class OnlineRatingService {
  final String baseUrl;
  final FirebaseAuth _auth;

  /// Submit or update a rating, returns updated aggregates
  Future<DrinkRatingResult> ratedrink(String festivalId, String drinkId, int rating);

  /// Remove a rating
  Future<DrinkRatingResult> removeRating(String festivalId, String drinkId);

  /// Get rating for a single drink
  Future<DrinkRatingResult> getDrinkRating(String festivalId, String drinkId);

  /// Get all ratings for a festival (batch)
  Future<Map<String, DrinkRatingResult>> getFestivalRatings(String festivalId);
}
```

### 2.3 New Model: `DrinkRatingResult`

**Location:** `lib/models/drink_rating_result.dart`

```dart
class DrinkRatingResult {
  final int? userRating;      // Current user's rating (null if not rated)
  final double average;        // Community average
  final int count;             // Total number of ratings
  final Map<int, int> distribution;  // { 1: n, 2: n, 3: n, 4: n, 5: n }
}
```

### 2.4 Offline Sync Queue

**Location:** `lib/services/rating_sync_service.dart`

```dart
class RatingSyncService {
  final OnlineRatingService _onlineService;
  final RatingsService _localService;      // Existing SharedPreferences service
  final SharedPreferences _prefs;

  /// Queue a rating for sync (called when offline or as fire-and-forget)
  Future<void> queueRating(String festivalId, String drinkId, int rating);

  /// Process pending sync queue (called on connectivity restore)
  Future<void> syncPendingRatings();

  /// Get pending ratings that haven't synced yet
  List<PendingRating> getPendingRatings();
}
```

**Sync strategy:**
1. User taps a star → local rating saved immediately (existing `RatingsService`)
2. `RatingSyncService.queueRating()` called → adds to pending queue
3. If online: sends to API immediately, clears from queue on success
4. If offline: stays in queue
5. On connectivity change: `syncPendingRatings()` processes the queue
6. On app launch: check and sync any pending ratings

**Conflict resolution:** Last-write-wins (server timestamp). Simple and appropriate — a user's latest rating is always their intent.

### 2.5 Firebase Anonymous Auth Integration

**Location:** `lib/services/auth_service.dart`

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in anonymously (called on app startup)
  Future<User> ensureAuthenticated() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!;
    }
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Get current ID token for API calls
  Future<String> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return await user.getIdToken() ?? '';
  }
}
```

### 2.6 BeerProvider Changes

Add community rating data alongside existing personal rating:

```dart
// New state
Map<String, DrinkRatingResult> _communityRatings = {};

// Enhanced setRating method
Future<void> setRating(Drink drink, int? rating) async {
  // 1. Save locally immediately (optimistic)
  if (rating == null) {
    await _drinkRepository!.removeRating(currentFestival.id, drink.id);
    drink.rating = null;
  } else {
    await _drinkRepository!.setRating(currentFestival.id, drink.id, rating);
    drink.rating = rating;
  }
  notifyListeners();  // UI updates immediately

  // 2. Sync to server in background
  _ratingSyncService.queueRating(currentFestival.id, drink.id, rating);
}

// New method to load community ratings
Future<void> loadCommunityRatings() async {
  _communityRatings = await _onlineRatingService
      .getFestivalRatings(currentFestival.id);
  notifyListeners();
}
```

### 2.7 UI Changes

**Drink list screen** — Show community average as small stars/number next to each drink.

**Drink detail screen** — Show:
- User's personal rating (existing star widget, interactive)
- Community average + count (e.g., "4.2 avg from 37 ratings")
- Distribution bar chart (optional, nice-to-have)

---

## 3. Wrangler Configuration

```toml
# cloudflare-worker/ratings/wrangler.toml
name = "cbf-ratings-api"
main = "src/index.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "RATINGS_DB"
database_name = "cbf-ratings"
database_id = "<generated-on-create>"

[vars]
FIREBASE_PROJECT_ID = "your-firebase-project-id"
ENVIRONMENT = "production"
```

---

## 4. Staged Releases

### Environments

The ratings Worker follows the same staging model as the existing app:

| Environment | Worker Name | D1 Database | URL | Deployed When |
|-------------|-------------|-------------|-----|---------------|
| **Dev/Preview** | `cbf-ratings-api-dev` | `cbf-ratings-dev` | `ratings-dev.cambeerfestival.app` | PR branches, local dev |
| **Staging** | `cbf-ratings-api-staging` | `cbf-ratings-staging` | `ratings-staging.cambeerfestival.app` | Merge to `main` |
| **Production** | `cbf-ratings-api` | `cbf-ratings` | `ratings.cambeerfestival.app` | Version tags (`v*`) |

**Each environment gets its own D1 database** — no risk of test data polluting production.

### Wrangler Multi-Environment Config

```toml
# cloudflare-worker/ratings/wrangler.toml
name = "cbf-ratings-api"
main = "src/index.js"
compatibility_date = "2024-01-01"

[vars]
FIREBASE_PROJECT_ID = "your-firebase-project-id"

# Production (default)
[[d1_databases]]
binding = "RATINGS_DB"
database_name = "cbf-ratings"
database_id = "<production-db-id>"

[env.staging]
name = "cbf-ratings-api-staging"
[env.staging.vars]
FIREBASE_PROJECT_ID = "your-firebase-project-id"
[[env.staging.d1_databases]]
binding = "RATINGS_DB"
database_name = "cbf-ratings-staging"
database_id = "<staging-db-id>"

[env.dev]
name = "cbf-ratings-api-dev"
[env.dev.vars]
FIREBASE_PROJECT_ID = "your-firebase-project-id"
[[env.dev.d1_databases]]
binding = "RATINGS_DB"
database_name = "cbf-ratings-dev"
database_id = "<dev-db-id>"
```

### Flutter Environment Routing

The app already detects environment via `EnvironmentService`. The ratings API base URL follows the same pattern:

```dart
String get ratingsApiBaseUrl {
  if (EnvironmentService.isProduction()) {
    return 'https://ratings.cambeerfestival.app';
  } else if (EnvironmentService.isStaging()) {
    return 'https://ratings-staging.cambeerfestival.app';
  } else {
    return 'https://ratings-dev.cambeerfestival.app';
  }
}
```

### Database Migrations

D1 schema changes need care across environments:

- Keep a `cloudflare-worker/ratings/migrations/` folder with numbered SQL files
- Migrations run **dev → staging → production** (never skip)
- Migrations must be **backwards-compatible** (add columns, don't remove/rename) so the old Worker code still works during rollout
- CI validates migration syntax before deployment

```
migrations/
├── 0001_create_ratings.sql
├── 0002_create_aggregates.sql
└── 0003_add_index.sql
```

### Deployment Flow

```
PR opened/updated:
  1. Run Worker unit tests (Vitest + Miniflare)
  2. Deploy to cbf-ratings-api-dev
  3. Run integration tests against dev Worker
  4. PR preview app (staging-cambeerfestival.pages.dev) hits dev ratings API

Merge to main:
  1. Run Worker unit tests
  2. Run D1 migrations on staging DB
  3. Deploy to cbf-ratings-api-staging
  4. Run integration tests against staging
  5. App deploys to staging.cambeerfestival.app (hits staging ratings API)

Version tag (v*):
  1. Run D1 migrations on production DB
  2. Deploy to cbf-ratings-api (production)
  3. App deploys to cambeerfestival.app (hits production ratings API)
```

---

## 5. Testing Strategy

### 5.0 Phase 0 — Tests for Existing Data Proxy Worker

The existing `cloudflare-worker/worker.js` has no tests. Adding tests here first:
- Establishes the Worker testing pattern (Vitest + Miniflare) before building the ratings Worker
- Catches regressions in CORS logic (security-relevant)
- Enables safe extraction of shared code (CORS utils) for the ratings Worker

**Test areas for existing Worker:**

| Area | Priority | What to test |
|------|----------|-------------|
| CORS origin matching | **High** | Allowed origins accepted, wildcard `.pages.dev` patterns, unknown origins rejected |
| CORS preflight | **High** | Correct headers returned, max-age differs for staging vs production |
| Beverage type parsing | Medium | HTML directory listing correctly parsed to JSON array |
| Festivals endpoint | Medium | Returns valid JSON, correct cache headers |
| Upstream proxy | Low | Error handling (502), charset enforcement, header passthrough |
| Health check | Low | Returns `{ status: "ok" }` |

**Setup:**

```
cloudflare-worker/
├── worker.js                   # Existing (unchanged)
├── wrangler.toml               # Existing (unchanged)
├── package.json                # NEW — add vitest, miniflare
├── vitest.config.js            # NEW — Miniflare environment
└── test/
    ├── cors.test.js            # Origin matching, preflight
    ├── festivals.test.js       # festivals.json endpoint
    ├── beverage-types.test.js  # Directory listing parser
    └── proxy.test.js           # Upstream proxy behaviour
```

**Example test (CORS origin matching):**

```js
import { describe, it, expect } from 'vitest';
import worker from '../worker.js';

describe('CORS', () => {
  it('allows production origin', async () => {
    const request = new Request('https://worker.example.com/health', {
      headers: { 'Origin': 'https://cambeerfestival.app' },
    });
    const response = await worker.fetch(request);
    expect(response.headers.get('Access-Control-Allow-Origin'))
      .toBe('https://cambeerfestival.app');
  });

  it('allows Cloudflare Pages preview URLs', async () => {
    const request = new Request('https://worker.example.com/health', {
      headers: { 'Origin': 'https://abc123.cambeerfestival.pages.dev' },
    });
    const response = await worker.fetch(request);
    expect(response.headers.get('Access-Control-Allow-Origin'))
      .toBe('https://abc123.cambeerfestival.pages.dev');
  });

  it('rejects unknown origins', async () => {
    const request = new Request('https://worker.example.com/health', {
      headers: { 'Origin': 'https://evil.example.com' },
    });
    const response = await worker.fetch(request);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
  });

  it('returns short max-age for staging preflight', async () => {
    const request = new Request('https://worker.example.com/', {
      method: 'OPTIONS',
      headers: { 'Origin': 'https://staging.cambeerfestival.app' },
    });
    const response = await worker.fetch(request);
    expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
  });
});
```

**CI integration:** Add a `test-worker` job to the existing `deploy-worker.yml` workflow, running before the deploy step.

### 5.1 Ratings Worker — Unit Tests

**Framework:** Vitest + Miniflare (standard for Cloudflare Workers)

Miniflare provides local D1 (in-memory SQLite), so tests run without network calls.

```
cloudflare-worker/ratings/
├── src/
│   ├── index.js          # Worker entry, router
│   ├── auth.js           # JWT verification
│   ├── ratings.js        # Rating CRUD + aggregation
│   ├── rate-limit.js     # Frequency limiting
│   └── cors.js           # Shared CORS utilities
├── test/
│   ├── auth.test.js      # JWT verification, token edge cases, expired tokens
│   ├── ratings.test.js   # CRUD, aggregate math, upsert behaviour
│   ├── rate-limit.test.js # Frequency limiting, window reset
│   ├── batch.test.js     # Batch endpoint, empty festival, large result sets
│   ├── cors.test.js      # Origin matching (shared with data proxy)
│   └── integration.test.js # Full request→response cycle with D1
├── migrations/
│   └── 0001_initial.sql
├── vitest.config.js
├── package.json
└── wrangler.toml
```

**Key test scenarios:**

| Test | What it verifies |
|------|-----------------|
| Submit first rating | Creates rating + aggregate row, returns correct stats |
| Update existing rating | Aggregate adjusts (old subtracted, new added) |
| Delete rating | Aggregate decrements, userRating returns null |
| Concurrent ratings on same drink | Aggregates stay consistent |
| Rating out of range (0, 6, -1) | Returns 400 |
| Missing/invalid auth token | Returns 401 |
| Expired auth token | Returns 401 |
| Rate limit exceeded | Returns 429 with retryAfter |
| Batch with no ratings | Returns empty map |
| Batch with 500 drinks | Returns within reasonable time |

### 5.2 Ratings Worker — Integration Tests

Run against a live Worker (dev environment) with real HTTP requests:

```bash
# Deploy to dev
wrangler deploy --env dev

# Run integration tests against live endpoint
RATINGS_API_URL=https://ratings-dev.cambeerfestival.app npm run test:integration
```

Tests use a real Firebase Anonymous Auth token to verify the full auth flow end-to-end.

### 5.3 Flutter — Unit Tests

Mock `OnlineRatingService` (follows existing pattern used for `BeerApiService`):

| Test file | What it tests |
|-----------|--------------|
| `test/services/online_rating_service_test.dart` | HTTP calls, JSON parsing, error handling |
| `test/services/rating_sync_service_test.dart` | Queue/dequeue, retry logic, conflict resolution |
| `test/services/auth_service_test.dart` | Anonymous sign-in, token refresh |
| `test/models/drink_rating_result_test.dart` | JSON deserialization, edge cases |
| `test/providers/beer_provider_rating_test.dart` | Optimistic update, sync trigger, community ratings |

### 5.4 Flutter — Widget Tests

| Test | What it tests |
|------|--------------|
| Community rating display | Average + count render correctly on drink detail |
| Star rating interaction | Tap star → local update → sync queued |
| Offline indicator | Rating saved locally when offline, no error shown |
| List screen averages | Community stars appear on drink cards |

### 5.5 E2E Tests

Extend existing Playwright suite:

```typescript
// test-e2e/ratings.spec.ts
test('drink detail shows community rating', async ({ page }) => {
  await page.goto('/drink/some-drink-id');
  // Verify community rating section renders
  await expect(page.getByLabel(/community rating/i)).toBeVisible();
});

test('star rating is interactive', async ({ page }) => {
  await page.goto('/drink/some-drink-id');
  // Verify star rating widget has correct ARIA labels
  await expect(page.getByLabel(/rate this drink/i)).toBeVisible();
});
```

E2E tests run against the dev ratings API in CI.

### 5.6 CI Pipeline for Ratings Worker

**New workflow: `.github/workflows/deploy-ratings-worker.yml`**

```yaml
name: Ratings Worker
on:
  push:
    branches: [main]
    paths: ['cloudflare-worker/ratings/**']
  pull_request:
    paths: ['cloudflare-worker/ratings/**']

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
        working-directory: cloudflare-worker/ratings
      - run: npm test
        working-directory: cloudflare-worker/ratings

  deploy-dev:
    if: github.event_name == 'pull_request'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: wrangler deploy --env dev
      - run: npm run test:integration  # Against live dev endpoint

  deploy-staging:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: wrangler d1 migrations apply cbf-ratings-staging --env staging
      - run: wrangler deploy --env staging
      - run: npm run test:integration  # Against live staging endpoint

  # Production deployment triggered by release-web.yml or separate release workflow
```

---

## 6. Implementation Phases

### Phase 0: Test Existing Data Proxy Worker
1. Add `package.json` with Vitest + Miniflare to `cloudflare-worker/`
2. Write CORS, preflight, and origin matching tests
3. Write beverage type parsing tests
4. Write festivals endpoint tests
5. Add `test-worker` job to `deploy-worker.yml` CI workflow
6. Extract shared CORS utilities for reuse by ratings Worker

### Phase 1: Ratings Worker Backend
1. Create D1 databases (dev, staging, production)
2. Write and run schema migrations
3. Build ratings Worker with PUT/DELETE/GET single-drink endpoints
4. Add Firebase JWT verification middleware
5. Add rate limiting
6. Write unit tests (Vitest + Miniflare)
7. Set up CI workflow (`deploy-ratings-worker.yml`)
8. Deploy to dev, test with curl/integration tests
9. Add batch GET endpoint
10. Deploy to staging

### Phase 2: Flutter — Auth + Online Rating
1. Add `firebase_auth` dependency
2. Create `AuthService` with anonymous sign-in
3. Create `OnlineRatingService` (HTTP client)
4. Create `DrinkRatingResult` model
5. Wire into `BeerProvider` — send ratings to API after local save
6. Display community ratings on detail screen
7. Write unit + widget tests

### Phase 3: Flutter — Offline Sync + Batch
1. Create `RatingSyncService` with pending queue
2. Add connectivity listener for auto-sync
3. Integrate batch endpoint — load community ratings on festival load
4. Show community averages on drink list cards
5. Extend Playwright E2E tests

### Phase 4: Future — Cross-Device
1. Add Google/Apple sign-in option in settings
2. Firebase Auth `linkWithCredential` to upgrade anonymous → authenticated
3. Server merges ratings from old anonymous UID to new authenticated UID
4. Ratings follow the user across devices

---

## 8. Data Sizing Estimates

For a typical festival:
- ~500 drinks
- ~5,000 active users
- ~10,000 ratings per festival

**D1 free tier ([confirmed](https://developers.cloudflare.com/d1/platform/pricing/)):**

| Resource | Free Tier Limit | Our Estimate | Headroom |
|----------|----------------|-------------|----------|
| Storage | 5 GB | ~2 MB / festival | ~2,500x |
| Rows read | 5M / day | ~25K / day | ~200x |
| Rows written | 100K / day | ~2K / day | ~50x |

Batch endpoint is now cacheable (60s TTL), so actual D1 reads will be significantly lower than the estimate — most requests served from Cloudflare edge cache.

---

## 9. Security Considerations

| Threat | Mitigation |
|--------|------------|
| Token forgery | JWT signature verification against Google's public keys |
| Rating spam | One rating per user per drink (DB constraint) + rate limiting |
| Data scraping | Aggregates only, no individual user data exposed |
| Token replay | Short-lived Firebase tokens (1 hour), verified server-side |
| SQL injection | D1 parameterized queries (no string concatenation) |
| CORS abuse | Same origin whitelist as existing worker |

---

## 10. Resolved Questions

1. **Custom domain?** Yes — `ratings.cambeerfestival.app` (+ `ratings-staging`, `ratings-dev`). Simplifies CORS since `*.cambeerfestival.app` patterns are already handled.

2. **Minimum ratings to show average?** Server-configurable threshold. The API returns the raw data (average, count, distribution) regardless. The **client** decides whether to display the average based on a configurable minimum (default: 0 for testing, raise to 3-5 for production). This keeps testing easy while allowing the threshold to be tuned without a code change.

   ```dart
   // Config: minimum ratings before showing community average
   static const int minRatingsToShowAverage = 0; // 0 for dev/testing, 3+ for production
   ```

3. **Festival archival?** Keep readable, block writes after festival end date. The API checks the festival's end date and returns `403 Festival ended` for PUT/DELETE requests after that date. GET requests (single + batch) remain available indefinitely so users can look back at what they enjoyed.

4. **Distribution bar chart?** Defer to v2. Not needed for launch — average + count is enough. Revisit once there's real usage data.

5. **Shared CORS module?** Start with duplication between the two Workers. Extract to a shared module later if they diverge or become a maintenance burden. Not a one-way door — easy to refactor.

---

## 11. Risk Assessment & Review

### Bugs in the Plan

**1. `EnvironmentService.isStaging()` doesn't exist**

The plan references `EnvironmentService.isStaging()` in the Flutter environment routing (section 4), but the actual class only has `isProduction()` and `getEnvironmentName()`. Need to either add `isStaging()` or use `getEnvironmentName() == 'staging'`.

**2. Mobile always routes to production**

`EnvironmentService` treats all mobile platforms as production (`return true` in `isProduction()`). This means there's no way to test the ratings API staging environment on Android without a code change. If mobile staging is needed, this needs addressing.

**3. ~~Festival end date — where does the Worker get it?~~ RESOLVED**

Embed `data/festivals.json` at build time — same pattern as the data proxy Worker. CI copies the file during build (`cp data/festivals.json cloudflare-worker/ratings/festivals.json`). The ratings Worker imports it and has access to festival IDs, end dates, and can validate requests. Ratings Worker redeploys when `data/festivals.json` changes (add path trigger to CI). Drink IDs are trusted from the client — no validation needed.

### High Risk

**4. ~~JWT verification in Cloudflare Workers — hardest piece of the backend~~ SPIKE COMPLETE**

The plan describes JWT verification as 6 clean steps, but hand-rolling this is non-trivial (Web Crypto API, X.509 PEM parsing, key rotation).

**Research finding:** [`firebase-auth-cloudflare-workers`](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) is a purpose-built library for exactly this:
- Zero dependencies, built with Web Standard APIs
- Designed specifically for Firebase token verification in CF Workers
- Caches Google's public keys in Workers KV (handles rotation automatically)
- Has Firebase Auth Emulator support (great for testing)
- ~5 lines to verify: `auth.verifyIdToken(jwt, env)`

**New requirement:** needs a KV namespace binding for public key caching. Free tier covers this easily.

**Spike results** ([PR #1](https://github.com/richardthe3rd/firebase-auth-cloudflare-workers/pull/1)): 16 edge case tests added, all passing:

| Edge case | Result |
|-----------|--------|
| Anonymous auth tokens | Fully supported. `sign_in_provider: "anonymous"`, empty `identities`. Same JWT structure as regular tokens. |
| Token expiry (1 hour) | Cleanly rejected with descriptive error. Tokens about to expire (30s left) still accepted. |
| Clock skew | Configurable tolerance (default ~5s). Tokens issued slightly in the future accepted within tolerance. |
| Emulator tokens | Supported via `FIREBASE_AUTH_EMULATOR_HOST` env var. Signature verification bypassed in emulator mode. |
| KV cold start | First request fetches from Google, caches in KV. Subsequent requests use cache. No extra latency after first call. |
| Concurrent cold start requests | Handled gracefully — all get same result. |
| Cache expiry | Re-fetches from Google when KV cache expires (TTL from `Cache-Control` header). |
| KV write failure | **Propagates to caller** — the library does NOT handle KV write failures gracefully. Need error handling in our Worker to catch this and still serve the request (degrade to uncached). |
| Key rotation (kid mismatch) | Correctly rejects tokens signed with unknown keys. In production, triggers re-fetch of public keys. |
| Multiple providers | All providers work (password, phone, Google, Facebook, GitHub, Twitter, anonymous). |

**Key finding — KV write failure:** The library throws if KV write fails after fetching keys. Our Worker should wrap `verifyIdToken` in a try/catch for this specific case, or accept the (very rare) failure. Not a blocker.

**Performance:** Cold start ~100-500ms (key fetch), cached <10ms.

**5. ~~Aggregate table consistency~~ RISK REDUCED**

The write path does: UPSERT rating → UPDATE aggregate in a `D1.batch()` call.

**Research finding:** [D1 `batch()` provides full transaction semantics](https://developers.cloudflare.com/d1/worker-api/d1-database/):
- All statements succeed or **all roll back**
- Sequential, non-concurrent execution
- Snapshot isolation (SQLite default)
- Explicit `BEGIN TRANSACTION` is not allowed — `batch()` is the intended mechanism

This means the aggregate can't drift from a partial batch failure. Still worth adding a `/admin/recompute-aggregates` endpoint as insurance against application bugs (e.g., incorrect aggregate math in code).

**6. Firebase Anonymous Auth persistence on web is fragile**

Firebase Auth on web stores identity in IndexedDB. This means:
- **Private/incognito browsing:** New anonymous user every session. They lose their "one vote per drink" identity.
- **Clearing browser data:** Identity lost, gets a new UID, can rate again.
- **Different browsers on same device:** Different identity per browser.

This weakens the "anonymous but tracked" guarantee on web. Not a dealbreaker for a festival app (determined fraudsters aren't the threat model), but worth knowing.

**Mitigation:** Accept the limitation. Document it. If duplicate voting becomes visible in the data, the min-ratings threshold hides the impact. For determined abuse, the rate limiter still applies per-session.

### Medium Risk

**7. ~~Batch endpoint + user ratings = caching problem~~ RESOLVED**

Batch endpoint now returns aggregates only (no per-user data). Fully cacheable with 60s TTL. Client uses local ratings for "my rating". Add `/mine` endpoint in Phase 4 for cross-device.

**8. ~~Rate limiting via in-memory storage won't work~~ RESOLVED**

Launch with DB constraint only (one rating per user per drink). Upgrade to D1 rate-limit table if abuse is observed. See section 1.5.

**9. D1 write concurrency under burst load**

D1 is built on SQLite (single-writer). At a festival, bursts could happen (e.g., a popular new beer tapped, 200 people rate it in 5 minutes). D1 should handle this fine — 200 writes over 5 minutes is ~0.7/second — but worth knowing the ceiling.

**Mitigation:** None needed at current scale. Monitor D1 latency in production. If it becomes an issue (unlikely), writes could be buffered through a Durable Object.

**10. Bundle size — adding `firebase_auth`**

The app is Flutter web-first. Adding `firebase_auth` adds the Firebase Auth JS SDK to the web bundle. This can add 50-100KB gzipped to the initial load. For a festival app on potentially slow mobile connections, this matters.

**Mitigation:** Measure before and after. Consider lazy-loading the auth initialization (don't block app startup on auth). Auth is only needed when the user first rates — not on initial page load.

### Low Risk (but worth noting)

**11. Drink ID stability**

Ratings are keyed by `drink_id` from the upstream API. If the festival data provider changes drink IDs between data refreshes (e.g., re-publishing the beer list), ratings would be orphaned. Looking at the current data, IDs appear to be `json['id'].toString()` from the API — likely stable, but we don't control this.

**Mitigation:** Accept the risk. If it happens, the aggregates recompute endpoint (from #5) can help clean up. Could also log a warning if we detect drink IDs changing.

**12. No monitoring/observability mentioned**

The plan has no mention of how we'll know if the ratings API is healthy, error rates, latency, or D1 approaching limits.

**Mitigation:** Add basic observability:
- Health check endpoint (like existing Worker)
- Cloudflare Analytics (built-in, free) for request rates and error rates
- Log errors to a simple D1 `error_log` table or use `console.error` (visible in Cloudflare dashboard)
- Alert on elevated 500 rates (Cloudflare Notifications, free)

**13. CORS for `ratings.cambeerfestival.app` — not actually in the existing whitelist**

The existing data proxy Worker allows `cambeerfestival.app` and `staging.cambeerfestival.app`. But `ratings.cambeerfestival.app` is a *different* origin serving the API, not calling it. The ratings Worker needs its own CORS config allowing the *app* origins to call it. This should work fine with the duplicated CORS code — just calling it out so it's not forgotten.

### Summary: What to do before starting Phase 1

| # | Action | Effort | Status |
|---|--------|--------|--------|
| 1 | **Spike JWT verification** — confirm `firebase-auth-cloudflare-workers` works with anonymous auth tokens, expiry, emulator, KV cold start. | ~1 hour | **COMPLETE** — [PR #1](https://github.com/richardthe3rd/firebase-auth-cloudflare-workers/pull/1). 16 tests, all passing. One finding: KV write failure propagates (needs error handling in Worker). |
| ~~2~~ | ~~**Decide festival end-date source**~~ | — | RESOLVED: embed `festivals.json` at build time, same as data proxy. |
| ~~3~~ | ~~**Decide batch endpoint caching strategy**~~ | — | RESOLVED: aggregates only, cacheable. Add `/mine` in Phase 4. |
| ~~4~~ | ~~**Decide rate limiting storage**~~ | — | RESOLVED: DB constraint only for launch. D1 table if needed later. |
