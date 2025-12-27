# Patrol + Firebase Test Lab Integration Plan

> **Status**: Research & Planning (Reviewed 2025-12-16)
> **Created**: 2025-12-16
> **Last Updated**: 2025-12-16
> **Review Document**: See [PATROL_FIREBASE_TESTING_REVIEW.md](PATROL_FIREBASE_TESTING_REVIEW.md) for detailed review findings

## Executive Summary

This document outlines a plan to implement end-to-end integration testing using [Patrol](https://patrol.leancode.co/) (LeanCode's Flutter testing framework) with [Firebase Test Lab](https://firebase.google.com/docs/test-lab) for running tests on real/virtual devices and capturing screenshots.

### Key Benefits
- **Native automation**: Patrol can interact with system dialogs, permissions, notifications
- **Real device testing**: Firebase Test Lab runs tests on actual Android/iOS devices
- **Screenshots**: Automated screenshot capture during test runs
- **No local emulator needed**: Device farm handles execution

### Key Constraints
- **Spark plan limit**: 15 test runs/day (free tier)
- **Trigger strategy**: Run only on PR merge to main, not on every PR update

---

## 1. Technology Overview

### 1.1 Patrol Framework

[Patrol](https://patrol.leancode.co/) is a Flutter-native E2E testing framework that overcomes limitations of `flutter_test` and `integration_test`.

**Key Features:**
- Written entirely in Dart - feels natural to Flutter developers
- Native automation via UIAutomator (Android) and XCUITest (iOS)
- Can interact with permission dialogs, notifications, WebViews
- Can modify device settings (Wi-Fi, Bluetooth, etc.)
- Works seamlessly with Firebase Test Lab
- Custom finders with concise syntax: `$(#buttonId).tap()`

**Current Version:** 4.0.1 (as of December 2025)

**Example Test:**
```dart
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('user can browse drinks', ($) async {
    // Navigate to app
    await $.pumpWidgetAndSettle(const MyApp());

    // Find and tap a drink card
    await $(#drinkCard).first.tap();

    // Verify detail screen appears
    expect($(#drinkDetailScreen), findsOneWidget);

    // Take a screenshot
    await $.native.takeScreenshot(name: 'drink_detail');
  });
}
```

### 1.2 Firebase Test Lab

[Firebase Test Lab](https://firebase.google.com/docs/test-lab) is a cloud-based app testing infrastructure.

**Capabilities:**
- Run instrumentation tests on real and virtual devices
- Multiple device configurations (models, OS versions, locales)
- Automatic screenshot capture
- Video recording of test runs
- Test result artifacts and logs

**Spark Plan (Free Tier) Quotas:**
| Resource | Daily Limit |
|----------|-------------|
| Total test runs | 15 per day |
| Virtual device minutes | Included |
| Physical device minutes | Included |

**Blaze Plan (Pay-as-you-go) Free Allowance:**
| Resource | Daily Free Allowance |
|----------|---------------------|
| Physical device time | 30 minutes/day |
| Virtual device time | 60 minutes/day |

**Beyond free tier pricing:**
- Physical devices: $5/device/hour
- Virtual devices: $1/device/hour

---

## 2. Implementation Strategy

### 2.1 Trigger Strategy (Managing 15 Tests/Day Limit)

Given the Spark plan's 15 test runs/day limit, we need a conservative trigger strategy:

| Trigger | Run Patrol Tests? | Rationale |
|---------|-------------------|-----------|
| PR opened | No | Conserve quota |
| PR updated | No | Conserve quota |
| PR merged to main | **Yes** | Verified, important changes |
| Manual dispatch | **Yes** | On-demand testing |
| Nightly schedule | Optional | Overnight regression |

**Recommended Configuration:**
```yaml
on:
  push:
    branches: [main]  # Only run on merge to main
  workflow_dispatch:   # Allow manual trigger
  # Optional: schedule for nightly runs
  # schedule:
  #   - cron: '0 2 * * *'  # 2 AM UTC
```

**Quota Budget (15 tests/day):**
- Typical day: 2-3 PR merges = 2-3 test runs
- Reserve capacity: 10+ runs for manual testing/debugging
- Weekend buffer: Unused quota doesn't roll over

### 2.2 Test Scope

Given quota constraints, focus tests on critical user journeys:

**Recommended Test Cases (Priority Order):**

1. **App Launch & Navigation** (P0)
   - App loads successfully
   - Bottom navigation works
   - Basic tab switching

2. **Drink Browsing** (P0)
   - Drink list loads
   - Search functionality
   - Filter by category

3. **Drink Details** (P1)
   - Navigate to drink detail
   - Favorite toggle works
   - Rating stars work

4. **Deep Links** (P1)
   - `/drink/{id}` opens correct drink
   - `/brewery/{id}` opens correct brewery
   - `/style/{name}` shows filtered list

5. **Offline/Error States** (P2)
   - Graceful error handling
   - Retry functionality

**Estimated Test Count:** 5-8 test files, bundled into 1-2 test runs

### 2.3 Screenshot Strategy

Screenshots serve two purposes:
1. **Visual regression detection** - Compare screenshots across builds
2. **Documentation** - Generate app screenshots for store listings

**Screenshot Points:**
- Home screen (drinks list)
- Search results
- Drink detail screen
- Brewery screen
- Favorites screen
- Filter states

**Implementation Options:**

1. **Patrol Native Screenshots:**
   ```dart
   await $.native.takeScreenshot(name: 'home_screen');
   ```

2. **fbtl_screenshots Package:**
   ```dart
   import 'package:fbtl_screenshots/fbtl_screenshots.dart';

   await takeScreenshot('drink_detail');
   ```
   Then retrieve with: `--directories-to-pull /sdcard`

---

## 3. Technical Implementation

### 3.1 Dependencies

**pubspec.yaml additions:**
```yaml
dev_dependencies:
  patrol: ^4.0.1
  # fbtl_screenshots: ^x.x.x  # Optional: for enhanced screenshot support

patrol:
  app_name: Cambridge Beer Festival
  android:
    package_name: ralcock.cbf
  ios:
    bundle_id: ralcock.cbf  # Note: iOS platform not currently configured
```

**CLI Tool:**
```bash
dart pub global activate patrol_cli
```

### 3.2 Native Setup

#### Android (`android/app/build.gradle`)

```gradle
android {
    defaultConfig {
        // Existing config...

        // Add for Patrol
        testInstrumentationRunner "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments clearPackageData: "true"
    }
}

dependencies {
    // Existing dependencies...

    // Patrol dependencies are added automatically by patrol_cli
}
```

#### iOS (Xcode Configuration)

> **Note:** As of December 2025, this project targets Android and Web platforms only.
> The iOS platform is not currently configured. If iOS support is added in the future,
> follow these instructions:

1. Open `ios/Runner.xcworkspace` in Xcode
2. File > New > Target > UI Testing Bundle
3. Name: `RunnerUITests`
4. Configure for Patrol per [official docs](https://patrol.leancode.co/getting-started)

### 3.3 Test Directory Structure

```
integration_test/
├── patrol_test/
│   ├── app_test.dart           # App launch, basic navigation
│   ├── drinks_test.dart        # Drink list, search, filter
│   ├── drink_detail_test.dart  # Detail screen interactions
│   ├── deep_links_test.dart    # URL routing tests
│   └── screenshots_test.dart   # Dedicated screenshot capture
├── test_bundle.dart            # Bundles all tests for single run
└── patrol_test_config.dart     # Shared test configuration
```

### 3.4 Building for Firebase Test Lab

**Android:**
```bash
# Build both APKs
patrol build android --target integration_test/patrol_test/test_bundle.dart

# Output locations:
# - App APK: build/app/outputs/apk/debug/app-debug.apk
# - Test APK: build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

**iOS:**
```bash
# Build for testing
patrol build ios --target integration_test/patrol_test/test_bundle.dart

# Create zip archive for Firebase
cd build/ios_integ/Build/Products
zip -r ios_tests.zip Release-iphoneos *.xctestrun
```

### 3.5 Running on Firebase Test Lab

**Android (gcloud CLI):**
```bash
gcloud firebase test android run \
  --type instrumentation \
  --use-orchestrator \
  --app build/app/outputs/apk/debug/app-debug.apk \
  --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --timeout 5m \
  --device model=MediumPhone.arm,version=34,locale=en,orientation=portrait \
  --record-video \
  --directories-to-pull /sdcard \
  --environment-variables clearPackageData=true \
  --results-bucket gs://your-bucket-name \
  --results-dir patrol-results
```

**iOS (gcloud CLI):**
```bash
gcloud firebase test ios run \
  --test build/ios_integ/Build/Products/ios_tests.zip \
  --timeout 5m \
  --device model=iphone14pro,version=17.0,locale=en,orientation=portrait
```

---

## 4. CI/CD Integration

### 4.1 GitHub Actions Workflow

**New file: `.github/workflows/patrol-tests.yml`**

```yaml
name: Patrol E2E Tests

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      device_model:
        description: 'Android device model'
        default: 'MediumPhone.arm'
        type: string

jobs:
  patrol-test-android:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Install Patrol CLI
        run: dart pub global activate patrol_cli

      - name: Get dependencies
        run: flutter pub get

      - name: Build test APKs
        run: patrol build android --target integration_test/patrol_test/test_bundle.dart

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: '${{ secrets.GCP_SERVICE_ACCOUNT_KEY }}'

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2

      - name: Run tests on Firebase Test Lab
        run: |
          gcloud firebase test android run \
            --type instrumentation \
            --use-orchestrator \
            --app build/app/outputs/apk/debug/app-debug.apk \
            --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
            --timeout 5m \
            --device model=${{ inputs.device_model || 'MediumPhone.arm' }},version=34,locale=en,orientation=portrait \
            --record-video \
            --directories-to-pull /sdcard \
            --environment-variables clearPackageData=true \
            --project ${{ secrets.FIREBASE_PROJECT_ID }}

      - name: Download test results
        if: always()
        run: |
          gsutil -m cp -r gs://${{ secrets.GCP_RESULTS_BUCKET }}/patrol-results ./patrol-results || true

      - name: Upload screenshots
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: patrol-screenshots
          path: patrol-results/
          retention-days: 14
```

### 4.2 Required Secrets

| Secret | Description | How to Obtain |
|--------|-------------|---------------|
| `GCP_SERVICE_ACCOUNT_KEY` | Service account JSON key | GCP Console > IAM > Service Accounts |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Firebase Console > Project Settings |
| `GCP_RESULTS_BUCKET` | GCS bucket for results | Create in GCP Console |

**Service Account Permissions:**
- Firebase Test Lab Admin
- Cloud Storage Object Admin (for results bucket)
- Cloud Tool Results Editor

### 4.3 Integration with Existing CI

Modify `.github/workflows/ci.yml` to optionally trigger Patrol tests:

```yaml
# Add after deploy-web-preview job
patrol-tests:
  needs: [test, build-android]
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  uses: ./.github/workflows/patrol-tests.yml
  secrets: inherit
```

---

## 5. Screenshots Retrieval

### 5.1 Android Screenshot Locations

Firebase Test Lab stores screenshots in GCS. Retrieve with:

```bash
# Pull from device during test
gcloud firebase test android run ... --directories-to-pull /sdcard

# Download from GCS after test
gsutil -m cp -r gs://your-bucket/results/screenshots ./screenshots
```

### 5.2 Organizing Screenshots

```
screenshots/
├── android/
│   ├── pixel-7-api-34/
│   │   ├── home_screen.png
│   │   ├── drink_detail.png
│   │   └── ...
│   └── medium-phone-api-33/
│       └── ...
└── ios/
    ├── iphone-14-pro-ios-17/
    │   └── ...
    └── ...
```

### 5.3 Visual Regression (Future Enhancement)

Consider integrating with visual regression tools:
- [Percy](https://percy.io/) - Visual testing platform
- [Applitools](https://applitools.com/) - AI-powered visual testing
- Custom diff tool comparing screenshots across builds

---

## 6. Implementation Phases

### Phase 0: Prerequisites (Before Implementation)
- [ ] Verify Firebase project has Test Lab enabled
- [ ] Confirm GCP billing account status (Spark vs Blaze plan)
- [ ] Test gcloud CLI authentication locally
- [ ] Review and approve 15 tests/day quota strategy with stakeholders
- [ ] Create GCS bucket for test results
- [ ] Configure service account with required permissions
- [ ] Document approved device configurations

### Phase 1: Foundation (Week 1)
- [ ] Add Patrol dependencies to `pubspec.yaml`
- [ ] Configure `patrol` section in `pubspec.yaml` with correct package name (`ralcock.cbf`)
- [ ] Complete Android native setup (`build.gradle`)
- [ ] Write first basic test (app launch)
- [ ] Verify local test execution with `patrol test`
- [ ] Note: iOS setup deferred (platform not currently supported)

### Phase 2: Test Development (Week 2)
- [ ] Create test directory structure
- [ ] Write core test cases (navigation, drinks, detail)
- [ ] Implement screenshot capture points
- [ ] Create test bundle for single-run execution
- [ ] Test locally on emulator

### Phase 3: Firebase Integration (Week 3)
- [ ] Create/configure Firebase project for Test Lab
- [ ] Create GCP service account with required permissions
- [ ] Create GCS bucket for results
- [ ] Add secrets to GitHub repository
- [ ] Test manual `gcloud firebase test android run`

### Phase 4: CI/CD Integration (Week 4)
- [ ] Create `patrol-tests.yml` workflow
- [ ] Configure trigger on merge to main
- [ ] Test end-to-end pipeline
- [ ] Add screenshot artifact upload
- [ ] Document process in `docs/`

### Phase 5: Polish & Monitoring (Ongoing)
- [ ] Monitor quota usage
- [ ] Add more test cases as needed
- [ ] Consider iOS support (if iOS platform is added to project)
- [ ] Evaluate visual regression tools (Percy, Applitools, Chromatic)
- [ ] Optimize test execution time
- [ ] Add favorites flow test
- [ ] Add offline mode test

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Quota exhaustion | Tests can't run | Monitor usage, conservative triggers |
| Flaky tests | False failures | Use `--use-orchestrator`, retry logic |
| Long execution time | Slow feedback | Optimize tests, parallel execution |
| Native setup complexity | Delayed implementation | Follow official docs closely |
| Screenshot inconsistency | Unreliable baselines | Standardize device config |

---

## 8. Cost Analysis

### Spark Plan (Recommended for Start)
- **Cost**: Free
- **Limit**: 15 tests/day
- **Suitable for**: Low-frequency testing (merge to main only)

### Blaze Plan (If Needed Later)
- **Base cost**: Free (60 min virtual, 30 min physical per day)
- **Additional cost**: ~$1-5/day if exceeding free tier
- **Suitable for**: Higher frequency testing

### Recommendation
Start with Spark plan. If 15 tests/day becomes limiting:
1. Optimize test bundling (fewer runs, more tests per run)
2. Upgrade to Blaze only if necessary

---

## 9. References

### Official Documentation
- [Patrol Documentation](https://patrol.leancode.co/)
- [Patrol Firebase Test Lab Guide](https://patrol.leancode.co/documentation/integrations/firebase-test-lab)
- [Firebase Test Lab Flutter Integration](https://firebase.google.com/docs/test-lab/flutter/integration-testing-with-flutter)
- [Firebase Test Lab Quotas & Pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing)

### Tutorials & Guides
- [Patrol 2.0 - Improved Flutter UI Testing](https://leancode.co/blog/patrol-2-0-improved-flutter-ui-testing)
- [Automating Flutter App Testing with Patrol and Firebase](https://medium.com/@lozhkovoi/automating-flutter-app-testing-with-patrol-and-firebase-d29e9e61b736)
- [Flutter Integration Tests on Firebase Test Lab](https://flutterexperts.com/flutter-integration-tests-on-firebase-test-lab/)

### Packages
- [patrol on pub.dev](https://pub.dev/packages/patrol) (v4.0.1)
- [fbtl_screenshots on pub.dev](https://pub.dev/packages/fbtl_screenshots)

---

## 10. Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-16 | Use Patrol over raw integration_test | Native automation, better Firebase Test Lab support |
| 2025-12-16 | Spark plan initially | Free, 15 tests/day sufficient for merge-only |
| 2025-12-16 | Trigger on merge to main only | Conserve quota, test verified changes |
| 2025-12-16 | Android first, iOS deferred | iOS platform not currently configured in project |
| 2025-12-16 | Package name is ralcock.cbf | Existing production app identifier |
| 2025-12-16 | Bundle tests in single run | Optimize quota usage, faster feedback |
