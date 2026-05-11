# Android Release Guide

This guide covers how to create and publish Android releases for the Cambridge Beer Festival app.

## Versioning Scheme: CalVer

This app uses **Calendar Versioning (CalVer)** with the format: `YYYY.MM.PATCH`

### Format Explanation

- **YYYY**: 4-digit year (e.g., 2025)
- **MM**: Month without leading zero (1-12, not 01-12)
- **PATCH**: Incremental patch number starting from 0

### Examples

- `v2025.12.0` - First release in December 2025
- `v2025.12.1` - Second release in December 2025 (patch/hotfix)
- `v2026.1.0` - First release in January 2026
- `v2026.1.1` - Second release in January 2026

### Version Code Calculation

The Android `versionCode` (integer) is automatically calculated from the CalVer string:

```
versionCode = (YYYY * 10000) + (MM * 100) + PATCH
```

Examples:
- `2025.12.0` → `20251200`
- `2025.12.1` → `20251201`
- `2026.1.0` → `20260100`

This ensures:
- Each version has a unique, incrementing code
- Google Play accepts it as an upgrade
- Maximum value: 2,147,483,647 (year 214748)

## Release Process

### 1. Update Version in pubspec.yaml

Before creating a release, update the version in `pubspec.yaml`:

```yaml
version: 2025.12.0+20251200
```

Format: `versionName+versionCode`
- **versionName**: Human-readable CalVer (e.g., `2025.12.0`)
- **versionCode**: Integer for Play Store ordering (e.g., `20251200`)

### 2. Commit Version Change

```bash
git add pubspec.yaml
git commit -m "Bump version to v2025.12.0"
git push origin main
```

### 3. Create and Push Git Tag

```bash
# Create annotated tag
git tag -a v2025.12.0 -m "Release v2025.12.0"

# Push tag to trigger release workflow
git push origin v2025.12.0
```

### 4. Monitor GitHub Actions

The release workflow will automatically:
1. Run tests
2. Build signed APK and AAB (using upload keystore)
3. Generate SHA256 checksums
4. Create a GitHub Release with:
   - Release notes (auto-generated from commits)
   - APK file for direct installation
   - AAB file for Play Store upload
   - Checksums file
5. Upload the signed AAB to Google Play **Internal track** automatically

> **First release only**: The Google Play API cannot create a new app listing.
> Before CI upload will work, you must upload the **first** AAB manually through
> Play Console and complete the app listing setup (store page, content rating,
> privacy policy). After that, all future releases are fully automated.
> See [play-store.md](play-store.md) for the first-time setup checklist.

### 5. Manual Release (Alternative)

You can also trigger a release manually via GitHub Actions:

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter the version tag (e.g., `v2025.12.0`)
4. Click **Run workflow**

## Testing the Release Workflow

Before creating your first production release, test the workflow to ensure everything works correctly.

### Option 1: Manual Workflow Trigger (Recommended)

**Best for**: Testing the full workflow without creating a real release tag.

**Steps:**

1. **Merge this PR to main** (or push to your branch)

2. **Navigate to GitHub Actions**
   - Go to repository → **Actions** tab
   - Select **Release** workflow from the left sidebar

3. **Trigger manually**
   - Click **Run workflow** (dropdown button)
   - Branch: Select `main` (or your current branch)
   - Version: Enter a test version like `v2025.12.0-test`
   - Click **Run workflow** button

4. **Monitor the workflow**
   - Watch the workflow run in real-time
   - Check for any errors in build steps
   - Verify all steps complete successfully

5. **Verify outputs**
   - Check that a GitHub Release was created
   - Download and verify APK and AAB files
   - Check checksums file is present
   - Test installing the APK on a device

6. **Clean up**
   - Delete the test release from Releases page
   - No need to delete tags (it wasn't created via tag push)

**Advantages:**
- ✅ Full workflow validation
- ✅ No tag management needed
- ✅ Easy to repeat
- ✅ Can test from any branch
- ✅ Free (GitHub Actions minutes included for public repos)

**Time**: ~5-10 minutes per test run

### Option 2: Test Tag

**Best for**: Testing the tag-triggered workflow.

**Steps:**

```bash
# Create test tag
git tag -a v2025.12.0-test -m "Test release workflow"

# Push tag to trigger workflow
git push origin v2025.12.0-test

# Monitor workflow in GitHub Actions tab

# After testing, delete the tag
git tag -d v2025.12.0-test                    # Delete locally
git push origin :refs/tags/v2025.12.0-test    # Delete remotely

# Also delete the GitHub Release if created
# Go to Releases → Click release → Delete release
```

**Advantages:**
- ✅ Tests the actual tag-based trigger
- ✅ Validates the complete automated flow

**Disadvantages:**
- ⚠️ Creates a real tag (needs cleanup)
- ⚠️ Tag appears in git history even after deletion

### Option 3: Local Build Test

**Best for**: Quick validation of build configuration without using CI/CD minutes.

**Requirements:**
- Flutter installed locally
- Android SDK configured
- Java 17+ installed

**Steps:**

```bash
# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Build release AAB
flutter build appbundle --release

# Check outputs
ls -lh build/app/outputs/flutter-apk/app-release.apk
ls -lh build/app/outputs/bundle/release/app-release.aab

# Test install on device (optional)
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Advantages:**
- ✅ Fastest feedback
- ✅ No GitHub Actions usage
- ✅ Can iterate quickly

**Disadvantages:**
- ❌ Doesn't test the full CI/CD workflow
- ❌ Doesn't test release creation
- ❌ Requires local Flutter setup

### Recommended Testing Strategy

**First time setup:**

1. **Local build test** - Verify builds work
2. **Manual trigger** - Test full workflow with `v2025.12.0-test`
3. **Verify everything** - Download artifacts, test APK
4. **Clean up test release** - Delete from Releases page
5. **Create real release** - Use tag `v2025.12.0` for production

**For subsequent releases:**

Just create the production tag directly - you've already validated the workflow works.

### What to Verify in Test Release

When testing, check these items:

- [ ] **Workflow completes successfully** (all green checkmarks)
- [ ] **GitHub Release is created** with correct version number
- [ ] **APK file is present** and downloads successfully
- [ ] **AAB file is present** and downloads successfully
- [ ] **Checksums file is present** with both file hashes
- [ ] **Release notes are generated** (auto-generated from commits)
- [ ] **APK installs on Android device** (test with `adb install`)
- [ ] **App launches and runs** without crashes
- [ ] **Version number shows correctly** in app (check About screen if available)

### Troubleshooting Test Failures

**Build fails: "Flutter not found"**
- Workflow uses Flutter 3.38.3 - this is correct
- Check if Flutter version changed in workflow

**Build fails: "Gradle error"**
- Check `android/app/build.gradle` syntax
- Verify signing config is correct

**APK/AAB missing**
- Check build step completed successfully
- Verify artifact upload paths are correct

**Release not created**
- Check workflow has `contents: write` permission
- Verify `GITHUB_TOKEN` is available (automatic)

**Release notes empty**
- Make sure you have commits since last tag
- Release notes are auto-generated from git history

## Build Performance

### CI/CD Optimizations

The release workflow includes several performance optimizations:

**Gradle Dependency Caching:**
- Caches `~/.gradle/caches` and `~/.gradle/wrapper` between builds
- Reduces build time by 2-5 minutes on cache hits
- First build after cache clear takes normal duration

**Gradle Build Cache:**
- Enabled via `org.gradle.caching=true` in `android/gradle.properties`
- Enables incremental builds (1-3 min savings)
- Reuses build outputs from previous builds when inputs haven't changed

**Parallel Execution:**
- Enabled via `org.gradle.parallel=true` in `android/gradle.properties`
- Runs independent Gradle tasks in parallel
- Better utilizes available CPU cores

**Total estimated savings:** 5-12 minutes per build (after initial cache population)

### Local Build Performance

When building locally, the same optimizations apply:

```bash
# First build - slower (populates cache)
flutter build apk --release

# Subsequent builds - faster (uses cache)
flutter build apk --release
```

**Tip:** Keep your local Gradle cache to speed up builds:
- Cache location: `~/.gradle/caches`
- Typical size: 1-3 GB
- Only clear if troubleshooting build issues

### Gradle Configuration Details

The `android/gradle.properties` file includes:

```properties
org.gradle.caching=true      # Build cache
org.gradle.parallel=true     # Parallel execution
```

**Note:** `org.gradle.configureondemand` is intentionally NOT used as it's deprecated in Gradle 8.9.1+ and can cause issues with Flutter's multi-project builds.

---

## Build Artifacts

Each release produces three files:

### 1. APK
- **Filename**: `cambridge-beer-festival-YYYY.MM.PATCH.apk`
- **Size**: ~15-25 MB
- **Use**: Direct installation on Android devices
- **Installation**: Requires "Install from unknown sources" enabled
- **Signing**: Signed with upload keystore in CI

### 2. AAB (Android App Bundle)
- **Filename**: `cambridge-beer-festival-YYYY.MM.PATCH.aab`
- **Size**: ~10-15 MB (smaller than APK)
- **Use**: Uploaded automatically to Google Play Internal track by CI
- **Signing**: Signed with upload key; Google Play re-signs with the app signing key (Play App Signing)

### 3. Checksums File
- **Filename**: `checksums.txt`
- **Content**: SHA256 hashes of APK and AAB
- **Use**: Verify file integrity

## Required Metadata for Google Play Store

When uploading to Google Play Console, you'll need to provide the following metadata:

### App Information

| Field | Value |
|-------|-------|
| **App Name** | Cambridge Beer Festival |
| **Package Name** | `ralcock.cbf` |
| **Category** | Food & Drink |
| **Content Rating** | 18+ (alcohol-related content) |
| **Target Audience** | Adults 18+ |

### Store Listing

#### Short Description (80 characters max)
```
Browse beers, ciders, and more at the Cambridge Beer Festival
```

#### Full Description (4000 characters max)
```
Cambridge Beer Festival App

The official companion app for the Cambridge Beer Festival, helping you discover and explore the incredible selection of drinks available at the festival.

🍺 FEATURES

• Browse hundreds of beers, ciders, perries, meads, and wines
• Search by name, brewery, or style
• Filter by category, style, and ABV
• Save your favorites for quick access
• Rate drinks to remember your preferences
• View detailed information about each drink
• Discover breweries and their complete product ranges
• Access festival information, dates, and location
• View the venue map
• Visit brewery websites directly

📋 DRINK CATEGORIES

• Real Ales & Craft Beers
• Ciders & Perries
• Meads
• International Beers
• Low & Non-Alcoholic Options
• Wines

🔍 SMART SEARCH & FILTERS

Find exactly what you're looking for with powerful search and filtering:
• Search across drink names, breweries, and styles
• Filter by ABV range (alcohol strength)
• Sort by name, brewery, ABV, or rating
• Browse by beer styles (IPA, Stout, Porter, Pale Ale, etc.)
• Quick category switching

⭐ PERSONALIZATION

• Save drinks to your favorites list
• Rate drinks from 1-5 stars
• Your preferences are saved locally on your device
• Favorites sync across festival editions

🌐 OFFLINE-FIRST DESIGN

The app caches festival data so you can browse even with limited connectivity at the venue.

📍 FESTIVAL INFORMATION

Access essential festival details:
• Event dates and times
• Venue location and map
• Official website link
• Festival updates

🎉 ABOUT CAMBRIDGE BEER FESTIVAL

The Cambridge Beer Festival is one of the UK's premier beer festivals, featuring an extensive selection of real ales, craft beers, ciders, and more from breweries across Britain and around the world.

---

This is an unofficial community app developed to enhance your festival experience. The app is not affiliated with or endorsed by the Cambridge Beer Festival organizers.

For official festival information, visit the Cambridge CAMRA website.
```

#### App Icon
- Provided in the app (already configured)
- Format: PNG
- Size: 512x512 pixels
- Location: `android/app/src/main/res/mipmap-*`

### Screenshots Required

You need **at least 2 screenshots** for each supported device type:

**Phone Screenshots (Required)**
- Minimum 2, recommended 8
- Resolution: 16:9 or 9:16 aspect ratio
- Min size: 320px
- Max size: 3840px

**7-inch Tablet Screenshots (Optional)**
- Same requirements as phone

**10-inch Tablet Screenshots (Optional)**
- Same requirements as phone

**Recommended Screenshots to Capture:**
1. Home screen with drink list
2. Drink detail view
3. Search and filters in action
4. Favorites list
5. Festival information screen
6. Brewery detail view
7. Category filter demonstration
8. Star rating feature

### Feature Graphic (Required for Featured Placement)
- Size: 1024w × 500h pixels
- Format: PNG or JPEG
- Content: Should showcase the app name and main features

### Privacy Policy

You must provide a privacy policy URL. The app collects:
- ✅ **Local data only**: Favorites and ratings (stored on device)
- ✅ **Network requests**: Fetches public festival data from API
- ❌ **No personal information collected**
- ❌ **No analytics or tracking**
- ❌ **No ads**

**Privacy Policy Template:**
```
Privacy Policy for Cambridge Beer Festival App

Last updated: [DATE]

This app does not collect, store, or transmit any personal information.

Data Storage:
- Favorite drinks and ratings are stored locally on your device
- No data is sent to external servers
- No analytics or tracking

Network Access:
- The app fetches public festival data from a Cloudflare Worker API
- No personal information is included in these requests

Permissions:
- Internet: Required to fetch festival data
- Storage: Required to save your favorites and ratings locally

Contact:
For questions about this privacy policy, please contact [YOUR EMAIL]
```

### Content Rating Questionnaire

When you submit for content rating, answer:

- **Does your app contain violence?** No
- **Does your app contain sexual content?** No
- **Does your app contain profanity or crude humor?** No
- **Does your app reference or depict drugs, alcohol, or tobacco?** **Yes** (alcohol information)
- **Does your app simulate gambling?** No

This will result in:
- **PEGI**: 18 (Europe)
- **ESRB**: Mature 17+ (USA)
- **USK**: 18 (Germany)
- **Rating varies by region** (due to alcohol content)

### Target Audience & Age Rating

- **Target Age Group**: 18+
- **Age Restriction**: Adults only (alcohol-related content)
- **Google Play Rating**: Will be rated based on content questionnaire

## Store Listing Assets Checklist

Before submitting to Play Store, ensure you have:

- [ ] App icon (512×512 PNG) - ✅ Already included
- [ ] Feature graphic (1024×500 PNG/JPEG)
- [ ] At least 2 phone screenshots
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Privacy policy URL
- [ ] Content rating questionnaire completed
- [ ] App category selected (Food & Drink)
- [ ] Contact email address
- [ ] Target audience set (18+)

## Replacing the Existing Play Store App (Seamless Upgrade)

The Flutter app replaces an existing self-signed APK app with package name `ralcock.cbf`.
For existing users to receive it as an automatic update (not a reinstall), two things must hold:

1. **Package name matches** — `applicationId = "ralcock.cbf"` in `build.gradle` ✅ already correct
2. **Signing certificate matches** — requires migrating to Play App Signing using the original keystore

### Why migration is required

Google Play requires AABs to be distributed via **Play App Signing**. During migration you upload
your original signing key to Google; it becomes the *app signing key* that Google uses when
delivering APKs to users. Devices that already have the app installed with the old certificate
accept the update seamlessly because the distribution certificate hasn't changed.

Your original keystore also becomes the *upload key* used in CI — so there is nothing new to
generate for the initial migration.

### One-time migration steps (do this before the first CI release)

#### Step 1: Check your version code

The new release's `versionCode` **must be higher** than whatever is currently live in Play Store.
Check `pubspec.yaml` — the build number after `+` is the version code (e.g. `2025.12.0+20251200`
→ `versionCode = 20251200`). If the existing app's version code is higher, update `pubspec.yaml`
before tagging.

#### Step 2: Enroll in Play App Signing

1. Open [Google Play Console](https://play.google.com/console) → your app
2. Go to **Release** → **Setup** → **App integrity** (or **App signing** in older UI)
3. Click **App signing** → **Upgrade your app signing key** (if present) or find the
   "App signing key" section
4. Choose **"Use a key exported from Java Keystore"**
5. Play Console provides a tool to encrypt and export your key — run it locally:
   ```bash
   # Play Console shows you this exact command with the right parameters
   java -jar pepk.jar \
     --keystore=your-original.jks \
     --alias=your-key-alias \
     --output=encrypted-key.zip \
     --include-cert \
     --encryptionkey=<hex-key-from-play-console>
   ```
6. Upload the resulting `encrypted-key.zip` to Play Console
7. Your original key is now enrolled as the **app signing key** — Google holds it and uses it
   to sign APKs delivered to users

> **You do not need to create a new keystore.** Your original keystore becomes the upload key.
> If you ever need to rotate the upload key you can do so in Play Console without affecting users.

#### Step 3: Configure GitHub secrets

Set `ANDROID_KEYSTORE_BASE64` to your **original signing keystore** (the same one you just
enrolled as the app signing key). CI will sign the AAB with it; Google will verify the signature
and re-sign the distributed APK/AAB with the same certificate existing users already have.

See [github-secrets.md](github-secrets.md) for the full secrets setup.

#### Step 4: First AAB upload (manual)

The Google Play API cannot upload to an app that has never had an AAB submitted. After completing
the migration above:

1. Push a tag to trigger the `Release Android` workflow
2. When it completes, download the AAB from the GitHub Release
3. In Play Console → **Internal testing** → **Create new release** → upload the AAB
4. Complete and roll out the release
5. From this point on, **all future releases are uploaded automatically by CI**

### Subsequent releases (fully automated)

```bash
# 1. Update version in pubspec.yaml
version: 2026.5.0+20260500

# 2. Commit and tag
git add pubspec.yaml
git commit -m "Bump version to v2026.5.0"
git tag -a v2026.5.0 -m "Release v2026.5.0"
git push origin main --follow-tags
```

CI builds → signs → uploads to Internal track. Promote to Production in Play Console.

### Add release notes

When promoting a release in Play Console, paste the "What's Changed" section from the
corresponding GitHub Release. For the English (UK) locale:

```
Version YYYY.MM.PATCH

[paste What's Changed from GitHub Release]
```

## Signing Configuration

Releases are signed with an **upload keystore**. This is the standard Play App Signing model:

| Key | Held by | Purpose |
|-----|---------|---------|
| **App signing key** | Google (Play App Signing) | Signs APKs delivered to users |
| **Upload key** | You (GitHub secret) | Signs the AAB you submit; Google verifies then re-signs |

If your upload key is ever compromised, you can rotate it in Play Console without affecting users.

### How It Works in CI

`android/app/build.gradle` reads signing config from `android/key.properties` if that file exists.
In CI, the workflow writes `key.properties` from secrets before building. Locally, if `key.properties`
is absent the build falls back to debug signing (fine for development, not uploadable to Play).

### One-Time Setup: Identify the Keystore

> **This app replaces an existing Play Store app.** Use the **original signing keystore**
> (the one used to sign all previous releases of `ralcock.cbf`), not a newly generated one.
> Generating a new keystore would produce a different certificate and break the upgrade path
> for existing users. See the migration steps above for enrolling it in Play App Signing.

Base64-encode the original keystore for the GitHub secret:

```bash
# Linux/Mac
base64 -i original-signing.jks | tr -d '\n'

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("original-signing.jks"))
```

### Required GitHub Secrets

Add these in **Repository Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` content (from command above) |
| `ANDROID_KEY_ALIAS` | Alias used when creating the keystore (e.g. `upload`) |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |

See [github-secrets.md](github-secrets.md) for full secrets setup including Google Play.

### Local Development

`android/key.properties` and `*.jks` are gitignored. For local release builds with signing:

```properties
# android/key.properties  (never commit this file)
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=../../upload-keystore.jks
```

## Code Obfuscation & Optimization (ProGuard/R8)

Currently, ProGuard/R8 is **enabled** (`minifyEnabled = true`). This reduces app size and generates a deobfuscation mapping file that is uploaded to two destinations automatically:

- **Firebase Crashlytics** — uploaded during the Gradle build by the `firebase-crashlytics-gradle` plugin (`uploadCrashlyticsMappingFileRelease` task). Crash reports in the Firebase Console are deobfuscated automatically.
- **Google Play Console** — uploaded by the CI release workflow (`release-android.yml`) after the AAB build. ANRs and crashes reported via Play Console are deobfuscated automatically.

### Why Enable ProGuard/R8?

**Benefits:**
- **Smaller APK/AAB size**: Removes unused code (~20-40% reduction)
- **Code obfuscation**: Makes reverse engineering harder
- **Performance**: Optimizes bytecode

**Trade-offs:**
- **Build time**: Adds 1-2 minutes to build
- **Debugging**: Stack traces need to be deobfuscated
- **Compatibility**: May break reflection-based code

### Enabling ProGuard/R8

**1. Update build.gradle**

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true        // Enable code shrinking
        shrinkResources true      // Enable resource shrinking
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**2. Create proguard-rules.pro**

Create `android/app/proguard-rules.pro`:

```proguard
# Flutter wrapper classes
-keep class io.flutter.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Preserve source file names and line numbers for actionable crash stack traces
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

-dontwarn com.google.android.gms.**
-dontwarn androidx.lifecycle.DefaultLifecycleObserver
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
```

**3. Test Thoroughly**

```bash
# Build with ProGuard enabled
flutter build apk --release

# Install and test all features
adb install build/app/outputs/flutter-apk/app-release.apk

# Check app size reduction
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

**4. Deobfuscate Stack Traces**

If you encounter crashes in production, use the mapping file to deobfuscate:

```bash
# Mapping file location (after a release build)
build/app/outputs/mapping/release/mapping.txt

# Deobfuscate using the Android SDK retrace tool:
$ANDROID_HOME/tools/proguard/bin/retrace.sh -verbose \
  build/app/outputs/mapping/release/mapping.txt obfuscated_trace.txt
```

### Recommendation for This App

**Current Status**: ✅ ProGuard/R8 enabled

The mapping file is automatically uploaded to Google Play Console as part of the CI release workflow,
enabling automatic deobfuscation of crash stack traces in the Play Console.

**If you need to deobfuscate a stack trace locally:**

```bash
# Mapping file location (after a release build)
build/app/outputs/mapping/release/mapping.txt

# Deobfuscate using the Android SDK retrace tool:
$ANDROID_HOME/tools/proguard/bin/retrace.sh -verbose \
  build/app/outputs/mapping/release/mapping.txt obfuscated_trace.txt

# Or with a standalone retrace JAR:
java -jar $ANDROID_HOME/tools/proguard/lib/retrace.jar -verbose \
  build/app/outputs/mapping/release/mapping.txt obfuscated_trace.txt
```

> **Note:** For AAB-based Play Store installs the mapping is also available in Play Console under
> Android Vitals → Deobfuscation files. For sideloaded APK installs, save the mapping file from
> CI artifacts within 7 days of the release build.

## Testing Before Release

### Test Unsigned APK

```bash
# Build locally
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# Or share file and install via File Manager
```

### Test AAB Locally

You cannot directly install AAB files. To test:

1. Use [bundletool](https://developer.android.com/studio/command-line/bundletool):
   ```bash
   # Generate APKs from AAB
   bundletool build-apks --bundle=app-release.aab \
     --output=app.apks \
     --mode=universal

   # Extract universal APK
   unzip app.apks -d apks

   # Install
   adb install apks/universal.apk
   ```

2. Or upload to **Internal Testing** track in Play Console first

## Troubleshooting

### "Failed to finalize session"
- App is already installed with a different signature
- Uninstall existing app first: `adb uninstall com.example.cambridge_beer_festival`

### "Version code must be greater than X"
- Ensure your CalVer version code is higher than the current one in Play Store
- Check `pubspec.yaml` version

### "Package name already exists"
- If replacing existing app, ensure package name matches exactly
- If new app, you cannot reuse a package name from deleted apps

### "Upload key doesn't match"
- Once enrolled in Play App Signing, Google manages the signing
- You can upload unsigned AABs, and Google will sign them

## Useful Commands

```bash
# Check current version
flutter pub run flutter_version

# Build release APK locally
flutter build apk --release

# Build release AAB locally
flutter build appbundle --release

# Check APK size
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Check AAB size
ls -lh build/app/outputs/bundle/release/app-release.aab

# Get SHA256 of APK
sha256sum build/app/outputs/flutter-apk/app-release.apk

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat -s flutter

# Uninstall app
adb uninstall com.example.cambridge_beer_festival
```

## Resources

- [Google Play Console](https://play.google.com/console)
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [CalVer Specification](https://calver.org/)

## Support

For issues with the release process, check:
- GitHub Actions workflow logs
- Google Play Console error messages
- Flutter build output

For app issues, file a GitHub issue or contact the development team.
