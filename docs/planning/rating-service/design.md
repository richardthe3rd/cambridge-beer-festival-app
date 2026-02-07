# Online Rating Service — Design Plan

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend | Cloudflare Workers + D1 | Existing Worker infra, SQL aggregation, unified stack |
| Identity | Firebase Anonymous Auth (client-side only) | Cross-device upgrade path, no Firebase backend needed |
| Rating model | Simple star rating (1-5) | Matches existing UI, low complexity |
| API response | Average + count + distribution + user's own rating | Full data for rich UI |
| Endpoints | Single-drink + batch | Stars on list screen without N+1 requests |
| Anti-abuse | One rating per user per drink + frequency limiting | Proportionate for festival app |
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

Batch endpoint — all rating aggregates for a festival.

**Headers:**
```
Authorization: Bearer <firebase-id-token>  (optional — needed for userRating)
```

**Response (200):**
```json
{
  "festivalId": "cbf2025",
  "ratings": {
    "drink-id-1": {
      "userRating": 4,
      "average": 4.2,
      "count": 37,
      "distribution": { "1": 2, "2": 3, "3": 5, "4": 12, "5": 15 }
    },
    "drink-id-2": {
      "userRating": null,
      "average": 3.8,
      "count": 12,
      "distribution": { "1": 0, "2": 1, "3": 3, "4": 5, "5": 3 }
    }
  }
}
```

**Caching:** Response can be cached for 30-60s with `Cache-Control`. User-specific data (userRating) means this needs `Vary: Authorization` or should be handled client-side by merging batch aggregates with locally-known user ratings.

### 1.4 Auth Middleware

The Worker verifies Firebase ID tokens without the Firebase Admin SDK:

```
1. Extract token from Authorization: Bearer <token>
2. Decode JWT header to get key ID (kid)
3. Fetch Google's public keys from:
   https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
   (cache for 1 hour)
4. Verify JWT signature using the matching public key
5. Validate claims:
   - iss == "https://securetoken.google.com/<firebase-project-id>"
   - aud == "<firebase-project-id>"
   - exp > now
   - sub is non-empty (this is the user_id)
6. Extract user_id = token.sub
```

This keeps the Worker self-contained — no Firebase Admin SDK, no Node.js runtime dependency.

### 1.5 Rate Limiting

Implemented in-Worker using a simple sliding window per user ID:

```
Rule: Max 30 write requests per user per minute
Storage: Cloudflare Worker in-memory (reset per isolate) or D1 table

On exceeded:
  429 Too Many Requests
  { "error": "Rate limit exceeded", "retryAfter": 45 }
```

For a festival app, this is sufficient. If abuse becomes a problem, Cloudflare's built-in rate limiting (paid) can be added later.

### 1.6 Write Path (Rating Submission)

```
1. Validate auth token → extract user_id
2. Check rate limit → reject if exceeded
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

## 4. Implementation Phases

### Phase 1: Backend (Cloudflare Worker + D1)
1. Create D1 database and run schema migrations
2. Build ratings Worker with PUT/DELETE/GET single-drink endpoints
3. Add Firebase JWT verification middleware
4. Add rate limiting
5. Deploy and test with curl/Postman
6. Add batch GET endpoint

### Phase 2: Flutter — Auth + Online Rating
1. Add `firebase_auth` dependency
2. Create `AuthService` with anonymous sign-in
3. Create `OnlineRatingService` (HTTP client)
4. Create `DrinkRatingResult` model
5. Wire into `BeerProvider` — send ratings to API after local save
6. Display community ratings on detail screen

### Phase 3: Flutter — Offline Sync + Batch
1. Create `RatingSyncService` with pending queue
2. Add connectivity listener for auto-sync
3. Integrate batch endpoint — load community ratings on festival load
4. Show community averages on drink list cards

### Phase 4: Future — Cross-Device
1. Add Google/Apple sign-in option in settings
2. Firebase Auth `linkWithCredential` to upgrade anonymous → authenticated
3. Server merges ratings from old anonymous UID to new authenticated UID
4. Ratings follow the user across devices

---

## 5. Data Sizing Estimates

For a typical festival:
- ~500 drinks
- ~5,000 active users
- ~10,000 ratings per festival

**D1 storage:** ~2 MB per festival (trivial)
**D1 reads:** Batch endpoint = 1 query per page load. At 5K users × 5 loads/day = 25K reads/day (well within free tier of 5M reads/day)
**D1 writes:** 10K ratings over 5 days = ~2K/day (well within free tier of 100K writes/day)

---

## 6. Security Considerations

| Threat | Mitigation |
|--------|------------|
| Token forgery | JWT signature verification against Google's public keys |
| Rating spam | One rating per user per drink (DB constraint) + rate limiting |
| Data scraping | Aggregates only, no individual user data exposed |
| Token replay | Short-lived Firebase tokens (1 hour), verified server-side |
| SQL injection | D1 parameterized queries (no string concatenation) |
| CORS abuse | Same origin whitelist as existing worker |

---

## 7. Open Questions

1. **Custom domain?** `ratings.cambeerfestival.app` vs just `cbf-ratings-api.workers.dev`
2. **Minimum ratings to show average?** Hide average until N ratings (e.g., 3) to prevent one person skewing display?
3. **Festival archival?** Keep ratings readable after festival ends? Or archive/delete?
4. **Distribution bar chart?** Worth the UI effort in v1 or defer?
