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

### Ratings API (v1)

Aggregate drink ratings backed by a D1 (SQLite) database. This is the first
step towards an online "my festival". Writes are local-first on the client; the
server holds the shared aggregate. Every row and query is scoped by a `bucket`
(`test` or `prod`) so test traffic never mixes with production data.

| Method   | Path                                  | Purpose                                            |
| -------- | ------------------------------------- | -------------------------------------------------- |
| `POST`   | `/v1/ratings`                         | Upsert a device's rating (1–5)                     |
| `DELETE` | `/v1/ratings`                         | Remove a device's rating                           |
| `GET`    | `/v1/ratings/{festivalId}/{drinkId}`  | Aggregate for one drink                            |
| `GET`    | `/v1/ratings/{festivalId}`            | Aggregate for every rated drink (batch, keyed map) |

`POST`/`DELETE` take a JSON body `{ festivalId, drinkId, deviceId, rating }`
(`rating` omitted for `DELETE`). `GET` requests accept an optional
`?deviceId=` to include the caller's own `yourRating`. The bucket is derived
from the request origin (only `https://cambeerfestival.app` → `prod`; everything
else → `test`) and can be pinned with a `RATINGS_BUCKET` worker var.

```bash
# Submit a rating, get back the aggregate
curl -X POST https://data.cambeerfestival.app/v1/ratings \
  -H 'Content-Type: application/json' \
  -d '{"festivalId":"cbf2025","drinkId":"beer-1","deviceId":"dev-1","rating":4}'
# -> {"festivalId":"cbf2025","drinkId":"beer-1","count":1,"average":4,"yourRating":4}

# Read the aggregate for one drink
curl https://data.cambeerfestival.app/v1/ratings/cbf2025/beer-1?deviceId=dev-1
```

### Would-recommend API (v1)

A yes/no "would recommend" signal, separate from the star rating, surfacing a
`% would recommend` per drink. Same D1 database, shape and bucket rules as the
ratings API, in a `recommendations` table.

| Method   | Path                                          | Purpose                          |
| -------- | --------------------------------------------- | -------------------------------- |
| `POST`   | `/v1/recommendations`                         | Upsert a device's yes/no answer  |
| `DELETE` | `/v1/recommendations`                         | Remove a device's answer         |
| `GET`    | `/v1/recommendations/{festivalId}/{drinkId}`  | Aggregate for one drink          |
| `GET`    | `/v1/recommendations/{festivalId}`            | Aggregate for every drink (batch) |

`POST` takes `{ festivalId, drinkId, deviceId, recommend }` where `recommend`
is a JSON boolean (`DELETE` omits it). Responses report total responses, the
"yes" count, the percentage, and the caller's own answer:

```bash
curl -X POST https://data.cambeerfestival.app/v1/recommendations \
  -H 'Content-Type: application/json' \
  -d '{"festivalId":"cbf2025","drinkId":"beer-1","deviceId":"dev-1","recommend":true}'
# -> {"festivalId":"cbf2025","drinkId":"beer-1","count":1,"recommendCount":1,"recommendPercent":100,"youRecommend":true}
```

#### D1 provisioning (one-time, before first deploy)

The `database_id` in `wrangler.toml` is a placeholder. Local `wrangler dev` and
the vitest test pool use a simulated local D1 and ignore it, so the full test
suite runs with no real database. Before deploying:

```bash
cd cloudflare-worker
wrangler d1 create cbf-ratings            # prints the database_id
# paste the id into wrangler.toml ([[d1_databases]].database_id)
wrangler d1 migrations apply cbf-ratings  # applies migrations/*.sql
```

The deploy `CLOUDFLARE_API_TOKEN` must include **D1: Edit** in addition to
Workers Scripts: Edit. To wipe test data: `DELETE FROM ratings WHERE bucket='test'`.

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
