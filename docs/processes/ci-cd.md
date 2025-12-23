# CI/CD Workflows

This document describes all GitHub Actions workflows used for continuous integration and deployment of the Cambridge Beer Festival app.

## Overview

The project uses **3 separate workflows** to handle different aspects of the CI/CD pipeline:

| Workflow | File | Purpose | Triggers |
|----------|------|---------|----------|
| **Flutter App CI/CD** | `build-deploy.yml` | Build, test, and deploy Flutter app | Push to `main`, PRs to `main` |
| **Cloudflare Worker** | `cloudflare-worker.yml` | Deploy API proxy worker and festivals data | Push to `main`, PRs (when worker/festivals.json changes) |
| **Release Web** | `release-web.yml` | Production web releases to Cloudflare Pages | Version tags (`v*`) |

---

## 1. Flutter App CI/CD

**File**: `.github/workflows/build-deploy.yml`
**Name**: `Flutter App CI/CD`

### Purpose

Handles all Flutter app building, testing, and deployment workflows for staging, development, and PR previews.

### Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

- **Push to `main`**: Full build, test, deploy to Cloudflare Pages staging
- **Pull Requests to `main`**: Build, test, deploy preview to Cloudflare Pages (runs once per push)
- **Manual**: Via workflow_dispatch in GitHub Actions UI

**Note**: The workflow triggers only on `pull_request` events for PR branches, not on `push` events, which prevents duplicate workflow runs when pushing commits to a PR branch.

### Jobs

#### A. `changes`

Detects which files have changed to optimize workflow execution.

**Outputs:**
- `app`: Changed if Flutter app files modified

**Filters:**
- `lib/**`, `web/**`, `pubspec.yaml`, `test/**`, `android/**`
- `.github/workflows/build-deploy.yml`, `mise.toml`

#### B. `test`

Runs Flutter tests with coverage reporting.

**Runs when**: `needs.changes.outputs.app == 'true'`

**Steps:**
1. Setup Flutter 3.38.3
2. Create Firebase configuration from secrets
3. Install dependencies (`flutter pub get`)
4. Generate mocks (`build_runner`)
5. Analyze code (`flutter analyze --no-fatal-infos`)
6. Run tests with coverage (`flutter test --coverage`)
7. Report coverage to GitHub PR comments and Codecov

**Coverage Requirements:**
- Minimum: 25% (TODO: increase to 70%)
- Reports posted as PR comments
- Uploaded to Codecov

#### C. `build-web`

Builds Flutter web application.

**Runs when**: `test` job succeeds

**Steps:**
1. Setup Flutter
2. Create Firebase configuration
3. Install dependencies
4. Build web with `--base-href "/"` (for Cloudflare Pages)
5. Upload build artifact

**Artifact**: `web-build` (used by deployment jobs)

#### D. `build-android`

Builds Android APK and App Bundle.

**Runs when**: `test` job succeeds

**Steps:**
1. Setup JDK 17
2. Cache Gradle dependencies (caches `~/.gradle/caches` and `~/.gradle/wrapper`)
3. Setup Flutter
4. Create Firebase configuration
5. Install dependencies
6. Build debug APK

**Artifacts:**
- `app-debug-apk`

**Performance Optimizations:**
- Gradle dependency caching reduces build time by 2-5 minutes on cache hits
- Gradle build cache enabled (see gradle.properties)

#### E. `deploy-web-preview`

Deploys to **Cloudflare Pages** (staging and PR previews).

**Runs when**: `needs.changes.outputs.app == 'true'`

**Environments:**
- **Staging**: `main.cambeerfestival.pages.dev` (push to `main`)
- **PR Previews**: Unique URL per PR (pull requests)

**Steps:**
1. Download `web-build` artifact
2. Deploy to Cloudflare Pages using `cloudflare/pages-action@v1`
3. Comment PR with preview URL (if PR)

**Preview URL Format:**
- PR: `https://<pr-branch>.cambeerfestival.pages.dev`
- Staging: `https://main.cambeerfestival.pages.dev`

---

## 2. Cloudflare Worker

**File**: `.github/workflows/cloudflare-worker.yml`
**Name**: `Cloudflare Worker`

### Purpose

Handles deployment of the Cloudflare Worker (API proxy) and festivals.json data.

### Triggers

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'cloudflare-worker/**'
      - 'data/festivals.json'
      - '.github/workflows/cloudflare-worker.yml'
  pull_request:
    paths:
      - 'cloudflare-worker/**'
      - 'data/festivals.json'
      - '.github/workflows/cloudflare-worker.yml'
  workflow_dispatch:
```

- **Push to `main`**: Deploy worker if worker or festivals.json changed
- **Pull Requests**: Validate worker (dry-run) if worker or festivals.json changed (runs once per push)
- **Manual**: Via workflow_dispatch in GitHub Actions UI

**Note**: The `pull_request` trigger doesn't specify branches, allowing PRs from any branch while still running only once per push.

### Jobs

#### A. `changes`

Detects which files have changed.

**Outputs:**
- `worker`: Changed if `cloudflare-worker/**` modified
- `festivals`: Changed if `data/festivals.json` modified

#### B. `validate-festivals`

Validates `festivals.json` against JSON schema.

**Runs when**: `needs.changes.outputs.festivals == 'true'`

**Steps:**
1. Setup Node.js 20
2. Install validation dependencies (`scripts/package.json`)
3. Run `node scripts/validate-festivals.js`

**Validation checks:**
- JSON syntax validity
- Schema compliance (`docs/api/festival-registry-schema.json`)
- Required fields present
- Data types correct

#### C. `validate-worker`

Validates Cloudflare Worker deployment (dry-run).

**Runs when**: PR and `(worker == 'true' || festivals == 'true')`

**Steps:**
1. Setup Node.js 20
2. Install worker dependencies
3. Copy `festivals.json` to worker directory
4. Run `wrangler deploy --dry-run`

**Purpose**: Catch deployment errors before merging to `main`

#### D. `deploy-worker`

Deploys Cloudflare Worker to production.

**Runs when**: Push to `main` and `(worker == 'true' || festivals == 'true')`

**Steps:**
1. Setup Node.js 20
2. Validate festivals.json (if changed)
3. Install worker dependencies
4. Copy `festivals.json` to worker directory
5. Deploy using `wrangler` via `cloudflare/wrangler-action@v3`

**Worker URL**: `https://data.cambeerfestival.app`

**Key Features:**
- CORS proxy for Cambridge Beer Festival API
- Serves festivals.json registry
- Injects CORS headers for allowed origins

---

## 3. Release Web

**File**: `.github/workflows/release-web.yml`
**Name**: `Release Web to Cloudflare Pages`

### Purpose

Production releases of the web app to the custom domain `cambeerfestival.app`.

### Triggers

```yaml
on:
  push:
    tags:
      - 'v*'  # Matches v2025.12.1, v2025.12.0, etc.
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag using CalVer (e.g., v2025.12.1)'
        required: true
```

- **Tag Push**: Automatic deployment when version tag pushed
- **Manual**: Via workflow_dispatch with version input

### Jobs

#### A. `build-and-deploy`

Builds and deploys production web app.

**Environment**: `production`
**URL**: `https://cambeerfestival.app`

**Steps:**
1. Checkout code
2. Extract version from tag
3. Setup Flutter 3.38.3
4. Create Firebase configuration
5. Install dependencies
6. Generate mocks
7. Analyze code
8. Run tests (must pass!)
9. Build web with `--base-href "/"`
10. Deploy to Cloudflare Pages production

**Deployment Strategy:**
- Tests must pass before deployment
- Code analysis must pass
- Deploys to production branch in Cloudflare Pages
- Custom domain `cambeerfestival.app` points to this deployment

---

## Workflow Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    Code Change / PR                         │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
┌───────────────────────────┐   ┌─────────────────────────┐
│   Flutter App CI/CD       │   │   Cloudflare Worker     │
│   (build-deploy.yml)      │   │   (cloudflare-worker    │
│                           │   │    .yml)                │
│  • Test & Build           │   │                         │
│  • Deploy to GH Pages     │   │  • Validate JSON        │
│  • Deploy to CF Pages     │   │  • Validate Worker      │
│    (PR preview/staging)   │   │  • Deploy Worker (main) │
└───────────────────────────┘   └─────────────────────────┘

                ┌─────────────┐
                │  Tag Push   │
                │  (v*.*.*)   │
                └──────┬──────┘
                       │
                       ▼
          ┌────────────────────────┐
          │   Release Web          │
          │   (release-web.yml)    │
          │                        │
          │  • Test & Build        │
          │  • Deploy to Prod      │
          │    (cambeerfestival    │
          │     .app)              │
          └────────────────────────┘
```

---

## Required GitHub Secrets

All workflows require the following secrets (set in repository Settings → Secrets):

| Secret | Used By | Description |
|--------|---------|-------------|
| `CLOUDFLARE_API_TOKEN` | Worker, Release Web, App CI/CD | API token with Workers + Pages permissions |
| `CLOUDFLARE_ACCOUNT_ID` | Worker, Release Web, App CI/CD | Cloudflare account ID |
| `GOOGLE_SERVICES_JSON` | App CI/CD, Release Web | Firebase Android configuration |
| `CODECOV_TOKEN` | App CI/CD | Codecov upload token (optional) |

See [GITHUB_SECRETS.md](GITHUB_SECRETS.md) for setup instructions.

---

## Deployment Environments

| Environment | Workflow | Trigger | URL | Purpose |
|-------------|----------|---------|-----|---------|
| **Production** | Release Web | Version tag | `cambeerfestival.app` | Live production site |
| **Staging** | App CI/CD | Push to `main` | `main.cambeerfestival.pages.dev` | Stable staging environment |
| **PR Preview** | App CI/CD | Pull request | `<branch>.cambeerfestival.pages.dev` | Test PRs before merge |
| **Development** | App CI/CD | Push to `main` | `richardthe3rd.github.io/...` | Alternative dev environment |
| **Worker** | Worker | Push to `main` | `data.cambeerfestival.app` | API proxy |

---

## Deployment Flow

### For Feature Development (Pull Request)

1. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Push branch and open PR**
   - GitHub Actions automatically:
     - Runs tests (`test` job)
     - Builds app (`build-web`, `build-android`)
     - Deploys preview to Cloudflare Pages
     - Comments PR with preview URL

3. **Review preview**
   - Visit preview URL in PR comment
   - Test changes in production-like environment

4. **Merge to `main`**
   - Triggers deployment to:
     - Cloudflare Pages staging (`staging.cambeerfestival.app`)
   - If worker/festivals.json changed:
     - Deploys updated worker

### For Production Release

1. **Create and push version tag**
   ```bash
   git tag v2025.12.1
   git push origin v2025.12.1
   ```

2. **Automatic production deployment**
   - GitHub Actions automatically:
     - Runs tests (must pass)
     - Builds web app
     - Deploys to `cambeerfestival.app`

3. **Verify production**
   - Visit `https://cambeerfestival.app`
   - Check functionality

### For Worker/Festivals Updates

1. **Update worker code or `data/festivals.json`**
   ```bash
   # Edit files
   git commit -m "Update festivals.json"
   git push origin main
   ```

2. **Automatic worker deployment**
   - GitHub Actions automatically:
     - Validates festivals.json (if changed)
     - Deploys worker to production

---

## Manual Workflow Triggers

All workflows support manual triggering via GitHub Actions UI:

1. Go to **Actions** tab in GitHub
2. Select workflow from left sidebar:
   - Flutter App CI/CD
   - Cloudflare Worker
   - Release Web to Cloudflare Pages
3. Click **Run workflow** button
4. Select branch (or enter version for Release Web)
5. Click **Run workflow**

---

## Workflow Concurrency

### Flutter App CI/CD

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

- Each branch gets its own concurrency group
- Non-main branches: new pushes cancel in-progress runs
- Main branch: runs always complete (no cancellation)

### Cloudflare Worker

```yaml
concurrency:
  group: cloudflare-worker-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

- Separate concurrency group for worker deployments
- Same cancellation logic as App CI/CD

### Release Web

```yaml
concurrency:
  group: cloudflare-pages-release-${{ github.ref }}
  cancel-in-progress: false
```

- Never cancels production releases
- Each release runs to completion

---

## Troubleshooting

### Tests Failing

**Check**:
1. Run tests locally: `flutter test`
2. Check coverage meets minimum (25%)
3. Review test failure logs in GitHub Actions

**Fix**:
- Fix failing tests
- Increase coverage if below threshold
- Push new commit to trigger re-run

### Build Failing

**Check**:
1. Build locally: `flutter build web`
2. Check for analyzer errors: `flutter analyze --no-fatal-infos`
3. Verify dependencies: `flutter pub get`

**Fix**:
- Fix analyzer errors
- Update dependencies if needed
- Check Firebase configuration

### Deployment Failing

**Check**:
1. Verify GitHub Secrets are set correctly
2. Check Cloudflare account/token permissions
3. Review deployment logs in GitHub Actions

**Fix**:
- Update secrets if expired
- Verify Cloudflare token has correct permissions
- Check Cloudflare Pages project exists

### Worker Deployment Failing

**Check**:
1. Validate festivals.json: `node scripts/validate-festivals.js`
2. Test worker locally: `cd cloudflare-worker && wrangler dev`
3. Check Cloudflare Worker quota/limits

**Fix**:
- Fix festivals.json schema errors
- Update worker code if needed
- Check Cloudflare account limits

---

## Monitoring Workflows

### GitHub Actions UI

1. Go to **Actions** tab
2. View all workflow runs
3. Click on run to see details
4. Expand job to see step logs

### PR Comments

- Coverage reports posted automatically
- Preview URLs for Cloudflare Pages
- Test results summary

### Notifications

Configure in **Settings → Notifications**:
- Email on workflow failure
- Slack/Discord webhooks (optional)

---

## Performance Optimization

### Caching

All workflows use caching to speed up builds:

**Flutter builds:**
```yaml
- uses: subosito/flutter-action@v2
  with:
    cache: true  # Caches Flutter SDK
```

**Android builds (Gradle):**
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      ${{ runner.os }}-gradle-
```

**Impact:**
- First build: Normal duration (populates cache)
- Subsequent builds: 2-5 min faster from cached Gradle dependencies

**Node.js builds:**
```yaml
- uses: actions/setup-node@v4
  with:
    cache: 'npm'
    cache-dependency-path: scripts/package-lock.json
```

### Gradle Build Optimizations

The `android/gradle.properties` file includes performance optimizations:

```properties
# Gradle build optimizations
org.gradle.caching=true      # Enable build cache for incremental builds
org.gradle.parallel=true     # Run tasks in parallel when possible
```

**Impact:**
- Build cache: 1-3 min savings from incremental builds
- Parallel execution: Better CPU utilization during builds

**Note on deprecated flags:**
- `org.gradle.configureondemand` is intentionally NOT used
- This flag is deprecated in modern Gradle versions (8.9.1+)
- It can cause configuration issues with Flutter's multi-project builds
- The combination of `caching` and `parallel` provides sufficient optimization

### Artifact Reuse

The `build-web` job creates an artifact that is reused by:
- `deploy-web`
- `deploy-web-preview`

This avoids rebuilding the app multiple times.

### Conditional Execution

Jobs only run when relevant files change:
- `test` only runs when `app` files change
- Worker jobs only run when `worker` or `festivals` change

---

## Security Considerations

### Secrets Management

- Never commit secrets to repository
- Rotate tokens periodically
- Use minimal permissions for tokens
- Separate tokens for different services (optional)

### Fork PRs

- Secrets are NOT available to fork PRs
- Fork contributors must run tests locally
- Maintainers can merge to branch to trigger CI

### Code Review

- Require PR reviews before merge
- Enable branch protection on `main`
- Require status checks to pass

---

## Related Documentation

- [GitHub Secrets Setup](GITHUB_SECRETS.md) - How to configure secrets
- [Cloudflare Pages Setup](CLOUDFLARE_PAGES_SETUP.md) - Cloudflare configuration
- [Firebase Setup](FIREBASE_SETUP.md) - Firebase project setup
- [Development Guide](DEVELOPMENT.md) - Local development workflow

---

## Quick Reference

### Trigger Production Deployment

```bash
git tag v2025.12.1
git push origin v2025.12.1
```

### Trigger Worker Deployment

```bash
# Edit cloudflare-worker/* or data/festivals.json
git commit -m "Update worker"
git push origin main
```

### View Workflow Status

```bash
gh run list --workflow="Flutter App CI/CD"
gh run list --workflow="Cloudflare Worker"
gh run list --workflow="Release Web to Cloudflare Pages"
```

### Cancel Workflow Run

```bash
gh run cancel <run-id>
```

### Re-run Failed Workflow

```bash
gh run rerun <run-id>
```

---

## Avoiding Duplicate CI Runs

### Problem

When a workflow is configured with both `push` and `pull_request` triggers for the same branches, it can run twice for the same commit:

```yaml
# ❌ BAD: Causes duplicate runs on PR pushes
on:
  push:
    branches: [main, feature/**]
  pull_request:
    branches: [main]
```

**Result**: Push to a PR branch → workflow runs on `push` event **AND** on `pull_request` event = **2 runs** 💰💸

### Solution

Our workflows are configured to run **only once** per commit:

```yaml
# ✅ GOOD: Runs only once per PR push
on:
  push:
    branches: [main]  # Only run on direct pushes to main
  pull_request:
    branches: [main]  # Run on all PRs targeting main
```

**Result**: 
- Push to a PR branch → workflow runs **only** on `pull_request` event = **1 run** ✅
- Push directly to main → workflow runs **only** on `push` event = **1 run** ✅

### Benefits

1. **Cost savings** - Reduces GitHub Actions minutes usage by 50%
2. **Faster feedback** - No waiting for duplicate runs to complete
3. **Cleaner UI** - Fewer runs to monitor in the Actions tab
4. **Resource efficiency** - Less CI queue contention

### Additional Notes

- The `pull_request` trigger in some workflows (e.g., `cloudflare-worker.yml`) doesn't specify `branches`, which allows PRs from any branch while still maintaining single-run behavior
- The `workflow_dispatch` trigger allows manual runs when needed
- Concurrency groups ensure that new pushes to the same branch cancel in-progress runs (except on `main`)

---

## Summary

The Cambridge Beer Festival app uses **3 specialized workflows**:

1. **Flutter App CI/CD** - Comprehensive app testing, building, and deployment
2. **Cloudflare Worker** - API proxy and festivals data deployment
3. **Release Web** - Production releases to custom domain

This separation provides:
- **Clear responsibilities** - Each workflow has a specific purpose
- **Independent triggers** - Worker can deploy without rebuilding app
- **Optimized execution** - Only relevant jobs run for each change
- **Better monitoring** - Easier to track specific deployment types
- **Single run per commit** - Avoids duplicate CI runs on PR pushes
