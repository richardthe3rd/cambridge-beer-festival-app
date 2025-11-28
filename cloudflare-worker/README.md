# Cloudflare Worker - CORS Proxy

This Cloudflare Worker proxies requests to `data.cambridgebeerfestival.com` and adds CORS headers, allowing the Flutter web app hosted on GitHub Pages to access the API data.

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

## Testing

After deployment, test the proxy:

```bash
curl https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025/beer.json
```

## Updating the Flutter App

Once deployed, update `lib/models/festival.dart` to use the proxy URL:

```dart
dataBaseUrl: 'https://cbf-data-proxy.<your-subdomain>.workers.dev/cbf2025',
```

Or configure it dynamically based on the platform (see `lib/services/beer_api_service.dart`).
