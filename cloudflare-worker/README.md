# Cloudflare Worker - CORS Proxy

This Cloudflare Worker proxies requests to `data.cambridgebeerfestival.com` and adds CORS headers, allowing the Flutter web app to access the API data.

## How It Works

1. The Flutter app makes requests to `https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025/beer.json`
2. The worker fetches data from `https://data.cambridgebeerfestival.com/cbf2025/beer.json`
3. The worker adds CORS headers and returns the response to the app

## Setup on Cloudflare

### Prerequisites
- A Cloudflare account (free tier works)
- `CLOUDFLARE_API_TOKEN` secret added to GitHub repository

### Creating the API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **My Profile** → **API Tokens**
3. Click **Create Token**
4. Use the **Edit Cloudflare Workers** template, or create a custom token with:
   - **Account** → **Workers Scripts** → **Edit**
   - **Zone** → **Workers Routes** → **Edit** (if using custom domain)
5. Copy the token and add it as `CLOUDFLARE_API_TOKEN` in GitHub repository secrets

### Manual Deployment (First Time)

If you want to deploy manually first:

```bash
cd cloudflare-worker
npm install
npx wrangler login
npx wrangler deploy
```

The worker URL will be displayed after deployment (e.g., `https://cbf-data-proxy.<account>.workers.dev`).

### CI/CD Deployment

The GitHub Actions workflow automatically deploys the worker on push to `main`. Ensure:
1. `CLOUDFLARE_API_TOKEN` is set in repository secrets (Settings → Secrets and variables → Actions → New repository secret)

**Troubleshooting**: If you see "Unable to authenticate request [code: 10001]", your API token may be:
- Missing from GitHub secrets
- Expired or revoked
- Missing required permissions (needs "Workers Scripts: Edit" at minimum)

## API Endpoints

The worker provides several endpoints:

### Proxy Endpoints

Proxies requests to `data.cambridgebeerfestival.com` with CORS headers:

- `/{festivalId}/{beverageType}.json` - Get beverage data (e.g., `/cbf2025/beer.json`)

### Metadata Endpoints

Dynamic API endpoints that provide festival metadata:

- `/festivals.json` - Returns the festivals registry with all festival metadata
- `/{festivalId}/available_beverage_types.json` - **NEW!** Dynamically discovers available beverage types for a festival

Example:
```bash
# Get available beverage types for CBF 2025
curl https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025/available_beverage_types.json

# Response:
{
  "festival_id": "cbf2025",
  "available_beverage_types": [
    "apple-juice",
    "beer",
    "cider",
    "international-beer",
    "low-no",
    "mead",
    "perry",
    "wine"
  ],
  "timestamp": "2025-12-02T10:30:00.000Z"
}
```

This endpoint:
- Dynamically fetches the directory listing from the upstream API
- Parses the HTML to find all `.json` files
- Returns them as a sorted array
- Caches the result for 1 hour

### "My festival" API (v1alpha)

Personal drink reviews and shared aggregates, backed by D1 (SQLite). The first
step towards an online "my festival". The API is resource-oriented following
[Google's AIPs](https://google.aip.dev) — the proto contract is in `proto/`
and an OpenAPI spec can be generated from it (see `proto/README.md`).

Writes are local-first on the client; the server holds the shared aggregate.
Every row and query is scoped by a `bucket` (`test` or `prod`, derived from the
request origin; only `https://cambeerfestival.app` → `prod`) so test traffic
never mixes with production data. A `RATINGS_BUCKET` worker var can pin it.

The **Review** is a singleton per (caller, drink). Caller identity comes from
the `X-Device-Id` request header (anonymous phase); the device ID never appears
in resource names, so the sign-in upgrade is transparent to clients.

| Method   | Path                                                             | Purpose                          |
| -------- | ---------------------------------------------------------------- | -------------------------------- |
| `PATCH`  | `/v1alpha/festivals/{f}/drinks/{d}/review`                       | Upsert review (`starRating` and/or `wouldRecommend`) |
| `GET`    | `/v1alpha/festivals/{f}/drinks/{d}/review`                       | Get caller's review              |
| `DELETE` | `/v1alpha/festivals/{f}/drinks/{d}/review`                       | Remove caller's review           |
| `GET`    | `/v1alpha/festivals/{f}/reviews`                                 | List caller's reviews at festival |
| `GET`    | `/v1alpha/festivals/{f}/reviewSummaries/{d}`                     | Aggregate for one drink          |
| `GET`    | `/v1alpha/festivals/{f}/reviewSummaries?page_size=&page_token=`  | Paginated list of aggregates     |

`PATCH` body: `{ starRating?: 1-5, wouldRecommend?: bool, updateMask?: "starRating,wouldRecommend" }`.
Both signals are independently optional; use `updateMask` to update one without
clearing the other. `DELETE` is `NOT_FOUND` when the review is absent (AIP-135).
Errors use the structured `google.rpc.Status` shape (AIP-193).

```bash
# Upsert a review (star rating + recommendation)
curl -X PATCH https://data.cambeerfestival.app/v1alpha/festivals/cbf2025/drinks/beer-1/review \
  -H 'Content-Type: application/json' \
  -H 'X-Device-Id: my-device-id' \
  -d '{"starRating":4,"wouldRecommend":true}'
# -> {"name":"festivals/cbf2025/drinks/beer-1/review","starRating":4,"wouldRecommend":true,"updateTime":"..."}

# Update only the star rating (keep wouldRecommend as-is)
curl -X PATCH https://data.cambeerfestival.app/v1alpha/festivals/cbf2025/drinks/beer-1/review \
  -H 'Content-Type: application/json' \
  -H 'X-Device-Id: my-device-id' \
  -d '{"starRating":5,"updateMask":"starRating"}'

# Aggregate for one drink
curl https://data.cambeerfestival.app/v1alpha/festivals/cbf2025/reviewSummaries/beer-1
# -> {"name":"...","ratingCount":3,"averageRating":4.0,"responseCount":2,"recommendCount":1,"recommendRate":0.5}
```

#### D1 provisioning (one-time, before first deploy)

The `database_id` in `wrangler.toml` is a placeholder. Local `wrangler dev` and
the vitest test pool use a simulated local D1 and ignore it, so the full test
suite runs with no real database. Before deploying:

```bash
cd cloudflare-worker
wrangler d1 create cbf-myfestival              # prints the database_id
# paste the id into wrangler.toml ([[d1_databases]].database_id)
wrangler d1 migrations apply cbf-myfestival   # applies migrations/*.sql
```

The deploy `CLOUDFLARE_API_TOKEN` must include **D1: Edit** in addition to
Workers Scripts: Edit. To wipe test data: `DELETE FROM reviews WHERE bucket='test'`.

### Health Check

- `/health` - Returns `{"status": "ok"}` for monitoring

## Testing

After deployment, test the proxy:

```bash
# Test beverage data proxy
curl https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025/beer.json

# Test dynamic beverage types discovery
curl https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025/available_beverage_types.json

# Test festivals registry
curl https://cbf-data-proxy.<your-subdomain>.workers.dev/festivals.json
```

## Updating the Flutter App

Once deployed, update `lib/models/festival.dart` to use the proxy URL:

```dart
dataBaseUrl: 'https://data.cambeerfestival.app/cbf2025',
```

Or configure it dynamically based on the platform (see `lib/services/beer_api_service.dart`).
