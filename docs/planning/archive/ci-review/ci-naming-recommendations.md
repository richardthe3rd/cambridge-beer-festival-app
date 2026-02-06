# GitHub Actions Naming Conventions Review

## Current vs. Best Practices Analysis

### ✅ What's Already Good

Your workflows mostly follow GitHub's recommended conventions:
- Workflow files: `kebab-case.yml` ✅
- Job names: `kebab-case` ✅
- Most step names: Sentence case ✅

---

## 🔄 Recommended Changes

### 1. Workflow File Names

**Current** → **Recommended** (Align with GitHub's de facto standards)

| Current | Recommended | Reason |
|---------|-------------|--------|
| `ci.yml` | `ci.yml` or `ci-cd.yml` | Industry standard for main CI/CD pipeline |
| `release-android.yml` | `release-android.yml` ✅ | Already good |
| `release-web.yml` | `release-web.yml` ✅ | Already good |
| `deploy-worker.yml` | `worker-deploy.yml` | More descriptive of action (deploy) |
| `devcontainer.yml` | `devcontainer.yml` ✅ | Already good |

**Rationale**:
- `ci.yml` is the most common name for main CI/CD workflows (see: Docker, Kubernetes, etc.)
- Prefix with action verb when applicable (`deploy-`, `release-`, `test-`)
- Most popular repos use this pattern

---

### 2. Workflow Display Names

**Current** → **Recommended**

```yaml
# ❌ Current: ci.yml
name: Flutter App CI/CD

# ✅ Better:
name: CI
# OR
name: Continuous Integration
```

```yaml
# ❌ Current: deploy-worker.yml
name: Cloudflare Worker

# ✅ Better:
name: Deploy Worker
# OR
name: Cloudflare Worker Deploy
```

```yaml
# ❌ Current: release-web.yml
name: Release Web to Cloudflare Pages

# ✅ Better:
name: Release Web
# (Cloudflare is implementation detail, can be in description)
```

**Rationale**:
- Workflow names appear in GitHub UI and status badges
- Shorter names are clearer in checks list
- Focus on WHAT (CI, Release) not HOW (Flutter, Cloudflare)

---

### 3. Job Names - Semantic Clarity

**Current** → **Recommended**

```yaml
# ❌ Current: devcontainer.yml
jobs:
  devcontainer-build:

# ✅ Better:
jobs:
  validate:
  # OR
  build:
```
*Reason*: "devcontainer-" prefix is redundant when workflow is already named "Validate DevContainer"

```yaml
# ❌ Current: release-android.yml
jobs:
  create-release:

# ✅ Better:
jobs:
  build-and-release:
  # OR split into:
  build:
  release:
```
*Reason*: Job also builds, not just creates release

```yaml
# ✅ Already good: ci.yml
jobs:
  changes:       # Standard name for path filtering
  test:          # Standard
  build-web:     # Clear and specific
  build-android: # Clear and specific
  test-e2e-web:  # Descriptive
  deploy-web-preview: # Clear action + target
```

---

### 4. Step Names - Action-Oriented

**Pattern**: Start with verb, be specific about what's happening

**Current Issues** → **Recommendations**:

```yaml
# ❌ Generic
- name: Setup Flutter
# ✅ More specific
- name: Set up Flutter 3.38.3

# ❌ Missing context
- name: Run tests
# ✅ Better context
- name: Run unit and widget tests
# OR
- name: Test with coverage

# ❌ Unclear
- name: Analyze code
# ✅ Clearer
- name: Run Flutter analyzer
# OR
- name: Lint with Flutter analyzer

# ❌ Too verbose
- name: Build release APK (unsigned)
# ✅ Concise (unsigned is clear from filename)
- name: Build release APK

# ❌ Inconsistent
- name: Get dependencies
# ✅ Consistent with Flutter CLI
- name: Install dependencies
# OR keep "Get" to match `flutter pub get`
```

**Standard Verb Patterns**:
- **Setup/Set up**: Installing tools, configuring environment
- **Install**: Dependencies, packages
- **Build**: Compilation
- **Test**: Running tests
- **Deploy**: Publishing/deploying
- **Upload/Download**: Artifacts
- **Create**: New resources (files, releases)
- **Run**: Executing commands/scripts
- **Validate**: Checking/verifying
- **Generate**: Code generation

---

### 5. Environment Names

**Current**:
```yaml
# release-web.yml
environment:
  name: production
  url: https://cambeerfestival.app
```
✅ Already good!

**Also consider** (if you add staging):
```yaml
environment:
  name: staging  # NOT "preview" or "dev"
  url: https://staging.cambeerfestival.app
```

**Standard environment names**:
- `production` (or `prod`)
- `staging` (or `stage`)
- `development` (or `dev`)
- `preview` (for PR previews)

---

### 6. Secret Names

**Current** (assumed from usage):
```yaml
secrets.GOOGLE_SERVICES_JSON
secrets.CLOUDFLARE_API_TOKEN
secrets.CLOUDFLARE_ACCOUNT_ID
secrets.CODECOV_TOKEN
```
✅ Already following best practices!

**Pattern**: `UPPER_SNAKE_CASE` with descriptive prefixes

**Keep this pattern**:
- Service prefix: `CLOUDFLARE_*`, `CODECOV_*`, `FIREBASE_*`
- Purpose suffix: `*_TOKEN`, `*_KEY`, `*_SECRET`

---

### 7. Artifact Names

**Current** → **Recommended**

```yaml
# ❌ Missing version/context
name: web-build

# ✅ Include useful metadata
name: web-build-${{ github.sha }}
# OR
name: web-build-${{ github.run_number }}
```

```yaml
# ❌ Generic
name: app-debug-apk

# ✅ More specific
name: android-debug-${{ github.sha }}
```

```yaml
# ✅ Already good
name: playwright-report
name: code-coverage-report
```

**Benefits**:
- Easier to identify in artifact list
- Can download specific build from UI
- Prevents name collisions

---

### 8. Cache Keys - Follow Patterns

**Current** (missing pub cache, but when added):

```yaml
# ✅ Good pattern
key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*') }}

# ✅ Recommended pattern for pub cache
key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}

# ✅ Recommended pattern for npm
key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
```

**Pattern**: `{os}-{tool}-{content-hash}`

---

## 📋 Alignment with Industry Standards

### GitHub's Official Examples

**Popular Pattern - Multi-file approach**:
```
.github/workflows/
├── ci.yml              # Main CI (tests, builds)
├── deploy-prod.yml     # Production deployment
├── deploy-staging.yml  # Staging deployment
├── release.yml         # Create releases
└── cron-daily.yml      # Scheduled jobs
```

**Your Current Approach** (closer to this):
```
.github/workflows/
├── ci.yml       → ci.yml
├── release-android.yml    ✅
├── release-web.yml        ✅
├── deploy-worker.yml  → deploy-worker.yml
└── devcontainer.yml       ✅
```

### Top OSS Projects Naming Analysis

| Project | Main CI Name | Release Name | Deploy Name |
|---------|-------------|--------------|-------------|
| **Docker** | `ci.yml` | `release.yml` | `deploy.yml` |
| **Kubernetes** | `ci.yml` | `release.yml` | - |
| **Flutter** | `test.yml` | `release.yaml` | `deploy.yaml` |
| **VS Code** | `ci.yml` | `release.yml` | - |
| **React** | `test.yml` | `release.yml` | - |

**Consensus**: `ci.yml` for main workflow, `release-*.yml` for releases

---

## 🎯 Recommended Renaming Plan

### Option A: Minimal Changes (Safest)

Only rename files, keep workflow display names:

```bash
# Rename files
mv .github/workflows/ci.yml .github/workflows/ci.yml
mv .github/workflows/deploy-worker.yml .github/workflows/deploy-worker.yml

# Update any references in docs
```

**Impact**: Low risk, aligns with standards

### Option B: Complete Alignment (Recommended)

Rename files AND update display names:

```yaml
# .github/workflows/ci.yml
name: CI

# .github/workflows/deploy-worker.yml
name: Deploy Worker

# .github/workflows/release-web.yml
name: Release Web

# .github/workflows/release-android.yml
name: Release Android

# .github/workflows/devcontainer.yml
name: DevContainer
```

**Impact**: Better GitHub UI clarity, more professional

### Option C: Comprehensive Refactor (Future)

1. Rename files
2. Update display names
3. Standardize job names
4. Improve step names
5. Add descriptions

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:          # Was: test (analyze step)
    name: Lint code
    steps:
      - name: Run Flutter analyzer

  test:
    name: Test
    steps:
      - name: Run unit and widget tests with coverage

  build-web:
    name: Build for web

  build-android:
    name: Build for Android

  e2e:           # Was: test-e2e-web
    name: E2E tests

  deploy-preview:  # Was: deploy-web-preview
    name: Deploy preview
```

---

## 🔍 Status Badge Implications

Your README likely has status badges. After renaming:

```markdown
<!-- Before -->
![CI](https://github.com/user/repo/workflows/Flutter%20App%20CI%2FCD/badge.svg)

<!-- After (if you rename to "CI") -->
![CI](https://github.com/user/repo/workflows/CI/badge.svg)
```

**Action Required**: Update README.md badges after renaming

---

## 📝 Migration Checklist

If you decide to rename:

- [ ] Rename workflow files
- [ ] Update workflow display names
- [ ] Update job names (if applicable)
- [ ] Update any workflow references in:
  - [ ] README.md (badges)
  - [ ] CONTRIBUTING.md
  - [ ] Issue templates
  - [ ] Wiki/docs
- [ ] Update branch protection rules (if using workflow names)
- [ ] Search codebase for hardcoded workflow names
- [ ] Wait for one successful run of renamed workflows
- [ ] Delete old workflow runs (UI) if desired

---

## 🎓 References

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [GitHub Actions Naming Best Practices](https://docs.github.com/en/actions/learn-github-actions/finding-and-customizing-actions#naming-your-action)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## ✅ Final Recommendation

**Do This Now**:
1. Rename `ci.yml` → `ci.yml`
2. Update workflow name to just "CI"
3. Update README badges

**Consider Later**:
- Standardize step names during refactoring
- Add workflow descriptions
- Improve artifact naming with SHA/run number

**Why**: Aligns with 80%+ of popular open-source projects, improves discoverability, cleaner GitHub UI.
