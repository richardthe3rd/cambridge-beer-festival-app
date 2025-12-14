# Cloudflare Pages Deployment Setup

This document explains how to set up Cloudflare Pages deployment for the Cambridge Beer Festival app at `cambeerfestival.app`.

> **📖 For complete CI/CD workflow documentation, see [CICD.md](CICD.md)**
>
> This guide focuses on Cloudflare configuration. For workflow details, triggers, and deployment flows, refer to the CI/CD documentation.

## Overview

The app uses **two separate Cloudflare Pages projects** for clean separation between production and staging:

### Cloudflare Pages Projects

**Project 1: `cambeerfestival`** (Production only)
- Production branch: `release`
- Deploys: Git tags (e.g., `v2025.12.0`)
- Custom domain: `cambeerfestival.app`

**Project 2: `cambeerfestival-staging`** (Staging + PR previews)
- Production branch: `main` (serves staging)
- Preview branches: PR branches (serve PR previews)
- Deploys: Git main + all PRs
- Custom domain: `staging.cambeerfestival.app`

### Deployment Architecture

| Git Event | CF Project | CF Branch | URL | Purpose |
|-----------|------------|-----------|-----|---------|
| Version tag | `cambeerfestival` | `release` | `cambeerfestival.app` | Production |
| Push to `main` | `cambeerfestival-staging` | `main` | `staging.cambeerfestival.app` | Staging |
| Pull Request | `cambeerfestival-staging` | `<branch>` | `<branch>.cambeerfestival-staging.pages.dev` | PR previews |

### Cache Control Strategy

The app uses two Cloudflare Pages configuration files in the `web/` directory:

**`web/_redirects`** - Enables SPA routing (see [URL_ROUTING.md](URL_ROUTING.md)):
```
/* /index.html 200
```

**`web/_headers`** - Configures HTTP caching and security headers:

**Staging and PR Previews** (aggressive no-cache for quick iteration):
- `staging.cambeerfestival.app`: No-cache headers for all resources
- `*.cambeerfestival-staging.pages.dev`: No-cache headers for all resources
- `X-Robots-Tag: noindex` to prevent search engine indexing

**Production** (performance-optimized caching):
- Critical files (`index.html`, `flutter_service_worker.js`, etc.): No-cache
- Assets and CanvasKit: 1 day cache with revalidation
- JavaScript files: 1 hour cache with revalidation
- Icons and images: 1 week cache with revalidation

**Security headers** (all environments):
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ...`

> **Note**: Both `_headers` and `_redirects` files are automatically included in the Flutter web build output (`build/web/`) and deployed with the app. These files are processed by Cloudflare Pages during deployment to configure the platform - **they won't appear in the list of uploaded assets** in the Cloudflare dashboard, but they are applied to the deployment. Domain-specific rules for staging are placed at the end of the `_headers` file to ensure they override path-based production rules.

## Prerequisites

- Cloudflare account with access to manage Pages and DNS
- GitHub repository with appropriate permissions
- Domain `cambeerfestival.app` added to Cloudflare

## Cloudflare Configuration

### 1. Create Cloudflare Pages Projects

You need **two separate Cloudflare Pages projects**:
- `cambeerfestival` (production)
- `cambeerfestival-staging` (staging/previews)

**Option A: Let GitHub Actions Create the Projects (Easiest)**

Both projects will be automatically created on their first deployment. You can skip this step and jump to step 2 (Get Account ID) and step 3 (Create API Token).

- First push to `main` will create `cambeerfestival-staging`
- First git tag will create `cambeerfestival`

**Option B: Create Projects Manually**

If you prefer to create the projects manually first:

**For Production Project:**
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Workers & Pages**
3. Click **Create application** → **Pages**
4. Set **Project name**: `cambeerfestival`
5. Disable automatic deployments (GitHub Actions will handle deployments)

**For Staging Project:**
1. In **Workers & Pages**, click **Create application** → **Pages**
2. Set **Project name**: `cambeerfestival-staging`
3. Disable automatic deployments

**Important**: Project names must match the workflow configuration (`cambeerfestival` and `cambeerfestival-staging`).

### 2. Get Cloudflare Account ID

1. In Cloudflare Dashboard, click your profile in the top right
2. Navigate to **Account Home**
3. Copy your **Account ID** from the right sidebar
4. Save this for GitHub Secrets setup (see below)

### 3. Update Cloudflare API Token

**If you already have a Cloudflare API token for Workers:**

You can reuse the same token by adding Pages permissions to it:

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Find your existing token (e.g., `GitHub Actions - Cambridge Beer Festival`)
3. Click **Edit** (pencil icon)
4. Add the following permission:
   - **Account → Cloudflare Pages → Edit**
5. Your token should now have:
   - Account → **Workers Scripts → Edit** (existing)
   - Account → **Cloudflare Pages → Edit** (new)
6. Click **Continue to summary** → **Update Token**

**If you don't have an existing token:**

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Select **Create Custom Token**
4. Configure the token:
   - **Token name**: `GitHub Actions - Cambridge Beer Festival`
   - **Permissions**:
     - Account → **Workers Scripts → Edit** (for Workers deployment)
     - Account → **Cloudflare Pages → Edit** (for Pages deployment)
     - Zone → DNS → Read (optional, only if you need DNS updates)
   - **Account Resources**: Include → Your Account
   - **Zone Resources**:
     - If you added Zone → DNS → Read permission: Include → `cambeerfestival.app`
     - Otherwise: Not needed (Pages and Workers are Account-level resources)
5. Click **Continue to summary** → **Create Token**
6. **Copy the token immediately** (you won't be able to see it again)
7. Save this for GitHub Secrets setup (see below)

**Note**: Using a single token with both Workers and Pages permissions is simpler and follows the principle of consolidating CI/CD credentials for the same application.

### 4. Configure Custom Domains

You need to configure **one custom domain per project**:

#### 4a. Production Project Domain

1. In Cloudflare Dashboard, go to **Workers & Pages** → **Pages**
2. Select the **`cambeerfestival`** project
3. Go to **Settings** → **Builds & deployments**
4. Set **Production branch** to: `release`
5. Go to **Custom domains** tab
6. Click **Set up a custom domain**
7. Enter: `cambeerfestival.app`
8. Click **Continue**
9. Cloudflare will automatically configure the DNS records

#### 4b. Staging Project Domain

1. In Cloudflare Dashboard, go to **Workers & Pages** → **Pages**
2. Create or select the **`cambeerfestival-staging`** project
3. Go to **Settings** → **Builds & deployments**
4. Set **Production branch** to: `main`
5. Go to **Custom domains** tab
6. Click **Set up a custom domain**
7. Enter: `staging.cambeerfestival.app`
8. Click **Continue**
9. Cloudflare will automatically configure the DNS records

**Note**: The `cambeerfestival-staging` project will be automatically created by GitHub Actions on the first deployment if it doesn't exist.

#### 4c. Optional: WWW Redirect

If you want `www.cambeerfestival.app` to redirect to the apex domain:
1. In the `cambeerfestival` project, add `www.cambeerfestival.app` as a custom domain

**DNS Records Created** (automatic):
- `CNAME cambeerfestival.app` → `cambeerfestival.pages.dev`
- `CNAME staging.cambeerfestival.app` → `cambeerfestival-staging.pages.dev`
- `CNAME www.cambeerfestival.app` → `cambeerfestival.pages.dev` (optional)

### 5. Update Cloudflare Worker

The Cloudflare Worker for API proxy has already been updated to allow both custom domains in CORS origins:
- `https://cambeerfestival.app` (production)
- `https://staging.cambeerfestival.app` (staging)

When you deploy worker changes:

```bash
cd cloudflare-worker
npm ci
cp ../data/festivals.json ./festivals.json
wrangler deploy
```

Or let GitHub Actions deploy it automatically on push to `main`.

## GitHub Configuration

### 1. Verify/Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Verify or add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `CLOUDFLARE_API_TOKEN` | `<token from step 3 above>` | API token with Workers + Pages permissions |
| `CLOUDFLARE_ACCOUNT_ID` | `<account ID from step 2 above>` | Your Cloudflare account ID |
| `GOOGLE_SERVICES_JSON` | `<your google-services.json content>` | Firebase config (already exists) |

**Note**: If you already have `CLOUDFLARE_API_TOKEN` for Workers deployment, you don't need to change it in GitHub—just ensure you updated the token itself in Cloudflare (step 3) to include Pages permissions. The same token will now work for both Workers and Pages deployments.

**Important**: Keep these secrets secure. Never commit them to the repository.

### 2. Verify Workflow Files

The project uses **3 GitHub Actions workflows** for CI/CD:

| Workflow | File | Purpose |
|----------|------|---------|
| **Flutter App CI/CD** | `build-deploy.yml` | App building, testing, and staging deployments |
| **Cloudflare Worker** | `cloudflare-worker.yml` | API proxy and festivals.json deployment |
| **Release Web** | `release-web.yml` | Production releases to `cambeerfestival.app` |

**See [CICD.md](CICD.md) for complete workflow documentation.**

**Key features**:
- Production releases via version tags (`v*`)
- Automated testing before deployment
- PR preview deployments to Cloudflare Pages
- Separate worker deployment pipeline
- Staging environment on `main.cambeerfestival.pages.dev`

### 3. Enable GitHub Actions

1. Go to **Settings** → **Actions** → **General**
2. Ensure **Actions permissions** is set to "Allow all actions"
3. Under **Workflow permissions**, ensure:
   - "Read and write permissions" is selected
   - "Allow GitHub Actions to create and approve pull requests" is checked (optional)

## Deployment Workflow

> **📖 For complete deployment flows and workflow details, see [CICD.md](CICD.md#deployment-flow)**

The app has three main deployment workflows:

### 1. Production Deployment (cambeerfestival.app)

**Trigger**: Creating a version tag

**Workflow**: `.github/workflows/release-web.yml`

**Steps to deploy**:

1. Create and push a tag:
   ```bash
   git tag v2025.12.0
   git push origin v2025.12.0
   ```

2. GitHub Actions automatically:
   - Runs tests and analysis
   - Builds Flutter web app with `--base-href "/"`
   - Deploys to Cloudflare Pages production
   - App is live at `https://cambeerfestival.app` within 1-2 minutes

**Manual trigger**:
1. Go to **Actions** tab in GitHub
2. Select **Release Web to Cloudflare Pages** workflow
3. Click **Run workflow**
4. Enter version tag (e.g., `v2025.12.0`)
5. Click **Run workflow**

### 2. Cloudflare Worker Deployment

**Trigger**: Push to `main` or PR when worker/festivals.json changes

**Workflow**: `.github/workflows/cloudflare-worker.yml`

**Automatic process**:

1. Edit `cloudflare-worker/**` or `data/festivals.json`
2. Commit and push to `main`
3. GitHub Actions automatically:
   - Validates festivals.json against schema
   - Deploys worker to production
   - Worker is live at `https://data.cambeerfestival.app`

**On Pull Requests**:
- Validates festivals.json
- Runs `wrangler deploy --dry-run` to catch errors

**See [CICD.md](CICD.md#2-cloudflare-worker) for detailed workflow documentation.**

### 3. Build and Deploy Workflow (Staging, Development, PR Previews)

**Trigger**: Push to `main` branch or pull requests

**Workflow**: `.github/workflows/build-deploy.yml`

This workflow handles all non-production deployments and includes multiple jobs:

#### A. Staging Deployment (Cloudflare Pages Preview)

**Trigger**: Push to `main` branch

**Job**: `deploy-web-preview`

**Automatic process**:

1. Push or merge to `main`
2. GitHub Actions automatically:
   - Builds web app (reuses artifact from `build-web` job)
   - Deploys to Cloudflare Pages `main` branch preview
   - Creates a stable staging URL (e.g., `main.cambeerfestival.pages.dev`)

**Benefits**:
- Stable staging environment that mirrors `main` branch
- Test changes before creating production releases
- Production-like environment without affecting live site

#### B. PR Preview Deployments (Cloudflare Pages)

**Trigger**: Opening or updating a pull request

**Job**: `deploy-web-preview`

**Automatic process**:

1. Open a pull request to `main`
2. GitHub Actions automatically:
   - Builds web app (reuses artifact from `build-web` job)
   - Deploys to Cloudflare Pages preview environment
   - Posts unique preview URL as comment on the PR
3. Each PR gets its own unique preview URL
4. Preview is automatically updated when you push new commits

**Benefits**:
- Test changes in production-like environment before merging
- Share preview URLs with team members for review
- No conflicts with staging environment

## Verification

After deployment, verify:

1. **Website loads**: Visit `https://cambeerfestival.app`
2. **SSL is active**: Check for padlock icon in browser
3. **API calls work**: Test loading drink data
4. **CORS headers**: Check browser console for CORS errors (should be none)
5. **Firebase works**: Check analytics and crashlytics
6. **Service worker**: Check for offline functionality

### Test API Connectivity

Open browser console on `https://cambeerfestival.app` and run:

```javascript
fetch('https://data.cambeerfestival.app/festivals.json')
  .then(r => r.json())
  .then(console.log)
```

Should return festival data without CORS errors.

## Troubleshooting

### Deployment Fails

**Check GitHub Actions logs**:
1. Go to **Actions** tab
2. Click on failed workflow run
3. Review logs for errors

**Common issues**:
- Missing secrets: Add required secrets to GitHub
- Wrong Cloudflare project name: Ensure project is named `cambeerfestival`
- Invalid API token: Regenerate token with correct permissions

### CORS Errors

If you see CORS errors in browser console:

1. Verify Cloudflare Worker includes `https://cambeerfestival.app` in `ALLOWED_ORIGINS`
2. Redeploy the worker:
   ```bash
   cd cloudflare-worker
   wrangler deploy
   ```
3. Clear browser cache and test again

### Custom Domain Not Working

1. Check DNS records in Cloudflare Dashboard → **DNS** → **Records**
2. Ensure CNAME record exists: `cambeerfestival.app` → `cambeerfestival.pages.dev`
3. Wait up to 24 hours for DNS propagation
4. Check SSL certificate status in **Workers & Pages** → **cambeerfestival** → **Custom domains**

### App Shows 404

1. Verify deployment succeeded in GitHub Actions
2. Check Cloudflare Pages deployment status
3. Ensure base-href is "/" in build command (not "/cambridge-beer-festival-app/")

### Verifying Cache Headers and Redirects

The `_headers` and `_redirects` files won't appear in the Cloudflare Pages asset list, but you can verify they're working:

**Check Cache Headers**:
```bash
# Check staging (should show no-cache)
curl -I https://staging.cambeerfestival.app/

# Check production (should show longer cache for assets)
curl -I https://cambeerfestival.app/assets/AssetManifest.json
```

**Check Security Headers**:
```bash
curl -I https://cambeerfestival.app/ | grep -E "X-Content-Type|X-Frame|Referrer"
```

**Check SPA Redirect**:
```bash
# Should return 200 status in headers
curl -I https://cambeerfestival.app/favorites
```

**Browser DevTools**:
1. Open DevTools → Network tab
2. Navigate to the app
3. Select any resource
4. Check Response Headers for `Cache-Control`, security headers, etc.

If headers are not being applied:
1. Verify `_headers` file exists in `build/web/` after build
2. Check Cloudflare Pages deployment logs
3. Ensure the syntax in `_headers` follows [Cloudflare Pages format](https://developers.cloudflare.com/pages/platform/headers/)
4. Try purging Cloudflare cache: Dashboard → Caching → Configuration → Purge Everything

## Maintenance

### Updating the App

1. Make changes to code
2. Commit and push to `main` branch
3. GitHub Actions automatically deploys to Cloudflare Pages staging

### Updating Festivals Data

1. Edit `data/festivals.json`
2. Commit and push to `main`
3. GitHub Actions automatically deploys worker with new data

### Rolling Back

If deployment breaks production:

1. Go to Cloudflare Dashboard → **Workers & Pages** → **cambeerfestival**
2. Click **Deployments** tab
3. Find the last working deployment
4. Click **⋯** → **Rollback to this deployment**

Or fix and redeploy from GitHub:

1. Revert commit: `git revert HEAD`
2. Push to `main`: `git push origin main`
3. GitHub Actions will deploy the reverted version

## Security Notes

- **API Token**: Keep Cloudflare API token secure. Rotate periodically.
- **CORS**: Worker only allows specific origins. Don't add wildcards.
- **HTTPS**: Cloudflare enforces HTTPS. All traffic is encrypted.
- **Rate Limiting**: Consider enabling Cloudflare rate limiting for API endpoints.

## Cost Estimates

**Cloudflare Pages**: Free tier includes:
- Unlimited requests
- Unlimited bandwidth
- 500 builds/month
- 1 build at a time

**Cloudflare Workers**: Free tier includes:
- 100,000 requests/day
- Sufficient for moderate traffic

Both should remain in free tier unless app sees very high traffic.

## Support

- **CI/CD Workflows**: [CICD.md](CICD.md) - Complete workflow documentation
- **Cloudflare Pages Docs**: https://developers.cloudflare.com/pages/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Flutter Web Docs**: https://docs.flutter.dev/platform-integration/web

## Summary Checklist

**Cloudflare Setup:**
- [ ] Cloudflare Pages project `cambeerfestival` created (production)
- [ ] Cloudflare Pages project `cambeerfestival-staging` created (staging/previews)
- [ ] Production project `cambeerfestival` → Production branch set to `release`
- [ ] Staging project `cambeerfestival-staging` → Production branch set to `main`
- [ ] Custom domain `cambeerfestival.app` configured on `cambeerfestival` project
- [ ] Custom domain `staging.cambeerfestival.app` configured on `cambeerfestival-staging` project
- [ ] DNS records configured (automatic via Cloudflare)
- [ ] Cloudflare Account ID obtained
- [ ] Cloudflare API Token updated with **both** Workers Scripts + Pages permissions

**GitHub Setup:**
- [ ] GitHub Secret `CLOUDFLARE_API_TOKEN` verified (should work for both Workers and Pages)
- [ ] GitHub Secret `CLOUDFLARE_ACCOUNT_ID` added
- [ ] GitHub Secret `GOOGLE_SERVICES_JSON` verified
- [ ] Workflow files committed (`.github/workflows/release-web.yml` and `build-deploy.yml`)

**Verification:**
- [ ] Cloudflare Worker updated with both custom domains in CORS origins
- [ ] Push to `main` triggers successful deployment to `https://staging.cambeerfestival.app`
- [ ] Create tag triggers production deployment to `https://cambeerfestival.app`
- [ ] API calls work without CORS errors on all environments
