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
     - Zone → DNS → Read (optional, if you need DNS updates)
   - **Account Resources**: Include → Your Account
   - **Zone Resources**: Include → `cambeerfestival.app`
5. Click **Continue to summary** → **Create Token**
6. **Copy the token immediately** (you won't be able to see it again)
7. Save this for GitHub Secrets setup (see below)

**Note**: Using a single token with both Workers and Pages permissions is simpler and follows the principle of consolidating CI/CD credentials for the same application.

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

The app has two main deployment workflows:

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

### 2. Build and Deploy Workflow (Staging, Development, PR Previews)

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

#### C. Development Deployment (GitHub Pages)

**Trigger**: Push to `main` branch

**Job**: `deploy-web`

**Automatic process**:

1. Push or merge to `main`
2. Deploys to `richardthe3rd.github.io/cambridge-beer-festival-app/`
3. Serves as alternative development/testing environment

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

- **Cloudflare Pages Docs**: https://developers.cloudflare.com/pages/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Flutter Web Docs**: https://docs.flutter.dev/platform-integration/web

## Summary Checklist

- [ ] Cloudflare Pages project `cambeerfestival` created
- [ ] Cloudflare Account ID obtained
- [ ] Cloudflare API Token updated with **both** Workers Scripts + Pages permissions
- [ ] Custom domain `cambeerfestival.app` configured in Cloudflare Pages
- [ ] DNS records configured (automatic via Cloudflare)
- [ ] GitHub Secret `CLOUDFLARE_API_TOKEN` verified (should work for both Workers and Pages)
- [ ] GitHub Secret `CLOUDFLARE_ACCOUNT_ID` added
- [ ] GitHub Secret `GOOGLE_SERVICES_JSON` verified
- [ ] Workflow files committed (`.github/workflows/release-web.yml` and `build-deploy.yml`)
- [ ] Cloudflare Worker updated with `cambeerfestival.app` CORS origin and wildcard for Pages previews
- [ ] Push to `main` triggers successful deployment to staging
- [ ] Create tag triggers production deployment to `https://cambeerfestival.app`
- [ ] API calls work without CORS errors on all environments
