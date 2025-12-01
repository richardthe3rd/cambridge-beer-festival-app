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
2. Build unsigned APK and AAB
3. Generate SHA256 checksums
4. Create a GitHub Release with:
   - Release notes (auto-generated from commits)
   - APK file for direct installation
   - AAB file for Play Store upload
   - Checksums file

### 5. Manual Release (Alternative)

You can also trigger a release manually via GitHub Actions:

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter the version tag (e.g., `v2025.12.0`)
4. Click **Run workflow**

## Build Artifacts

Each release produces three files:

### 1. Unsigned APK
- **Filename**: `cambridge-beer-festival-YYYY.MM.PATCH-unsigned.apk`
- **Size**: ~15-25 MB
- **Use**: Direct installation on Android devices
- **Installation**: Requires "Install from unknown sources" enabled
- **Signing**: Unsigned (or debug signed for testing)

### 2. Unsigned AAB (Android App Bundle)
- **Filename**: `cambridge-beer-festival-YYYY.MM.PATCH-unsigned.aab`
- **Size**: ~10-15 MB (smaller than APK)
- **Use**: Upload to Google Play Console
- **Signing**: Will be signed by Google Play App Signing automatically

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
| **Package Name** | `com.example.cambridge_beer_festival` |
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

## Google Play Console Upload Process

### First-Time Setup

1. **Create Developer Account**
   - Sign up at [Google Play Console](https://play.google.com/console)
   - Pay one-time $25 registration fee
   - Verify identity

2. **Create App**
   - Click "Create app"
   - App name: "Cambridge Beer Festival"
   - Default language: English (United Kingdom)
   - App/Game: App
   - Free/Paid: Free

3. **Set Up Play App Signing**
   - Go to **Release** → **Setup** → **App signing**
   - Enroll in Play App Signing (recommended)
   - Google will manage your signing keys

### Uploading a Release

1. **Navigate to Production Track**
   - Go to **Release** → **Production**
   - Click **Create new release**

2. **Upload AAB**
   - Click **Upload** and select the `cambridge-beer-festival-YYYY.MM.PATCH-unsigned.aab` file
   - Google Play will automatically sign it

3. **Add Release Notes**
   ```
   Version YYYY.MM.PATCH

   [Copy the "What's Changed" section from GitHub Release notes]

   Features:
   • Browse festival drinks
   • Search and filter
   • Save favorites
   • Rate drinks
   • View festival info
   ```

4. **Review and Rollout**
   - Review the release details
   - Click **Save** → **Review release** → **Start rollout to Production**

### Updating an Existing App

Since this replaces an existing Java/XML app:

1. **Ensure Package Name Matches**
   - Current: `com.example.cambridge_beer_festival`
   - Must match the existing app's package name in Play Console

2. **Version Code Must Increase**
   - CalVer ensures this: `20251200` > previous version code
   - Play Store will reject if version code doesn't increase

3. **Update Process**
   - Upload new AAB as described above
   - Google Play recognizes it as an update (same package name)
   - Users will receive an automatic update notification

## Signing Configuration (Future)

Currently, the app produces **unsigned** releases. For the Play Store, Google Play App Signing handles this automatically.

If you need to sign APKs manually in the future:

### 1. Generate Upload Key

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 2. Create key.properties

Create `android/key.properties`:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

### 3. Update build.gradle

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

### 4. Add to .gitignore

```
# Signing files
android/key.properties
*.jks
*.keystore
```

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
