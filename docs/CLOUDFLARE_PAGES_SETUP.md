# Cloudflare Pages Deployment Setup

This document explains how to set up Cloudflare Pages deployment for the Cambridge Beer Festival app at `cambeerfestival.app`.

## Overview

The app has two deployment targets:

1. **GitHub Pages** (Development/Staging): `richardthe3rd.github.io/cambridge-beer-festival-app/`
2. **Cloudflare Pages** (Production): `cambeerfestival.app`

## Prerequisites

- Cloudflare account with access to manage Pages and DNS
- GitHub repository with appropriate permissions
- Domain `cambeerfestival.app` added to Cloudflare

## Cloudflare Configuration

### 1. Create Cloudflare Pages Project

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Workers & Pages** → **Pages**
3. Click **Create a project**
4. Select **Direct Upload** (GitHub Actions will handle deployment)
5. Set **Project name**: `cambeerfestival`
6. Click **Create project**

**Important**: The project name must be `cambeerfestival` to match the workflow configuration.

### 2. Get Cloudflare Account ID

1. In Cloudflare Dashboard, click your profile in the top right
2. Navigate to **Account Home**
3. Copy your **Account ID** from the right sidebar
4. Save this for GitHub Secrets setup (see below)

### 3. Create Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Select **Create Custom Token**
4. Configure the token:
   - **Token name**: `GitHub Actions - Cambridge Beer Festival`
   - **Permissions**:
     - Account → Cloudflare Pages → Edit
     - Zone → DNS → Read (if you need DNS updates)
   - **Account Resources**: Include → Your Account
   - **Zone Resources**: Include → `cambeerfestival.app`
5. Click **Continue to summary** → **Create Token**
6. **Copy the token immediately** (you won't be able to see it again)
7. Save this for GitHub Secrets setup (see below)

### 4. Configure Custom Domain

1. In Cloudflare Dashboard, go to **Workers & Pages** → **Pages**
2. Select your `cambeerfestival` project
3. Go to **Custom domains** tab
4. Click **Set up a custom domain**
5. Enter: `cambeerfestival.app`
6. Click **Continue**
7. Cloudflare will automatically configure the DNS records
8. Optionally add `www.cambeerfestival.app` as well

**DNS Records Created** (automatic):
- `CNAME cambeerfestival.app` → `cambeerfestival.pages.dev`
- `CNAME www.cambeerfestival.app` → `cambeerfestival.pages.dev` (if www added)

### 5. Update Cloudflare Worker

The Cloudflare Worker for API proxy has already been updated to allow `https://cambeerfestival.app` in CORS origins.

When you deploy worker changes:

```bash
cd cloudflare-worker
npm ci
cp ../data/festivals.json ./festivals.json
wrangler deploy
```

Or let GitHub Actions deploy it automatically on push to `main`.

## GitHub Configuration

### 1. Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `CLOUDFLARE_API_TOKEN` | `<token from step 3 above>` | API token with Pages edit permissions |
| `CLOUDFLARE_ACCOUNT_ID` | `<account ID from step 2 above>` | Your Cloudflare account ID |
| `GOOGLE_SERVICES_JSON` | `<your google-services.json content>` | Firebase config (already set) |

**Important**: Keep these secrets secure. Never commit them to the repository.

### 2. Verify Workflow File

The workflow file `.github/workflows/release-web.yml` is already configured:

```yaml
name: Release Web to Cloudflare Pages

on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'
      - 'android/**'
      - '.github/workflows/release-web.yml'
  workflow_dispatch:
```

**Key features**:
- Triggers on push to `main` branch when relevant files change
- Can be manually triggered via `workflow_dispatch`
- Runs tests before deployment
- Builds with base-href "/" (for custom domain)
- Deploys to Cloudflare Pages using official action

### 3. Enable GitHub Actions

1. Go to **Settings** → **Actions** → **General**
2. Ensure **Actions permissions** is set to "Allow all actions"
3. Under **Workflow permissions**, ensure:
   - "Read and write permissions" is selected
   - "Allow GitHub Actions to create and approve pull requests" is checked (optional)

## Deployment Workflow

### Automatic Deployment

When you push changes to `main`:

1. GitHub Actions detects changes in relevant paths
2. Runs tests and analysis
3. Builds Flutter web app with `--base-href "/"`
4. Deploys to Cloudflare Pages project `cambeerfestival`
5. App is live at `https://cambeerfestival.app` within 1-2 minutes

### Manual Deployment

Trigger manually via GitHub Actions:

1. Go to **Actions** tab in GitHub
2. Select **Release Web to Cloudflare Pages** workflow
3. Click **Run workflow**
4. Select branch (usually `main`)
5. Click **Run workflow**

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
fetch('https://cbf-data-proxy.richard-alcock.workers.dev/festivals.json')
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

## Maintenance

### Updating the App

1. Make changes to code
2. Commit and push to `main` branch
3. GitHub Actions automatically deploys to both:
   - GitHub Pages (staging)
   - Cloudflare Pages (production)

### Updating Festivals Data

1. Edit `data/festivals.json`
2. Commit and push to `main`
3. GitHub Actions automatically deploys worker with new data

### Rolling Back

If deployment breaks production:

1. Go to Cloudflare Dashboard → **Workers & Pages** → **cambeerfest**
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

- **Cloudflare Pages Docs**: https://developers.cloudflare.com/pages/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Flutter Web Docs**: https://docs.flutter.dev/platform-integration/web

## Summary Checklist

- [ ] Cloudflare Pages project `cambeerfestival` created
- [ ] Cloudflare Account ID obtained
- [ ] Cloudflare API Token created with Pages edit permissions
- [ ] Custom domain `cambeerfestival.app` configured in Cloudflare Pages
- [ ] DNS records configured (automatic via Cloudflare)
- [ ] GitHub Secret `CLOUDFLARE_API_TOKEN` added
- [ ] GitHub Secret `CLOUDFLARE_ACCOUNT_ID` added
- [ ] GitHub Secret `GOOGLE_SERVICES_JSON` verified
- [ ] Workflow file `.github/workflows/release-web.yml` committed
- [ ] Cloudflare Worker updated with `cambeerfestival.app` CORS origin
- [ ] Push to `main` triggers successful deployment
- [ ] Website accessible at `https://cambeerfestival.app`
- [ ] API calls work without CORS errors
