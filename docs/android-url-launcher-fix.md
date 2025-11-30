# Android URL Launcher Fix (Issue #53)

## Problem

The app cannot open URLs (like the festival website) on Android devices, even though it works on web. This is due to Android 11+ (API level 30+) package visibility restrictions.

## Root Cause

Android 11 and above require apps to explicitly declare which external applications they can query and launch. Without the proper `<queries>` declarations in AndroidManifest.xml, the `url_launcher` package cannot:
1. Check if a browser is available
2. Launch the browser to open URLs

## Solution Architecture

This project uses a **CI-generated Android platform** approach:

1. **No `android/` directory in git** - The Android platform files are NOT committed to the repository
2. **CI generates Android files** - The build workflow runs `flutter create --platforms=android` to generate fresh platform files
3. **Patch after generation** - A script (`scripts/patch-android-manifest.sh`) patches the generated AndroidManifest.xml to add the required `<queries>` section

### Why This Approach?

- **Stays up-to-date**: Flutter generates the latest Android configuration matching the Flutter version
- **No version conflicts**: Avoids manually maintaining Gradle and Kotlin versions
- **Minimal changes**: Only patches what's necessary for the fix
- **Clean git history**: No large Android platform directories cluttering the repo

## The Fix

### What Gets Added

The patch script adds this to `android/app/src/main/AndroidManifest.xml`:

```xml
<queries>
    <!-- Required for url_launcher to open URLs in external browser -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="http" />
    </intent>
</queries>
```

### How It Works in CI

The `build-android` job in `.github/workflows/build-deploy.yml`:

1. Checks out the code
2. Sets up JDK and Flutter
3. Runs `flutter create --platforms=android` to generate Android files
4. **Runs `scripts/patch-android-manifest.sh` to add the fix** ← The key step
5. Builds the APK with the patched manifest

## Local Development

If you need to build Android locally:

```bash
# Generate Android platform files
flutter create --platforms=android --project-name=cambridge_beer_festival .

# Apply the fix
bash scripts/patch-android-manifest.sh

# Build
flutter build apk --debug
```

The patch script is idempotent - it's safe to run multiple times.

## Testing

To verify the fix works:

1. Build and install on Android device: `flutter install`
2. Open the app and navigate to Festival Info screen
3. Tap "Visit Festival Website" button
4. ✓ The festival website should open in the device's browser

## References

- [Android Package Visibility](https://developer.android.com/training/package-visibility)
- [url_launcher Package](https://pub.dev/packages/url_launcher)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
