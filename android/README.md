# Android Platform Configuration

This directory contains the Android platform configuration for the Cambridge Beer Festival app.

## Issue #53 Fix: URL Launching on Android

The main fix for issue #53 (Cannot open festival website on Android) is in the `AndroidManifest.xml` file.

### What was the problem?

Android 11 (API level 30) and above require apps to declare which external applications they can query and launch. Without the proper `<queries>` declarations in the AndroidManifest.xml, the `url_launcher` package cannot successfully open URLs in external browsers.

### The Solution

The `AndroidManifest.xml` file now includes the required `<queries>` section that declares intents for:
- **HTTPS URLs** - For opening the festival website and other secure web links
- **HTTP URLs** - For opening any non-secure web links
- **Text processing** - Required by Flutter for text selection features

### Key Configuration

```xml
<queries>
    <!-- If your app opens https URLs -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <!-- If your app opens http URLs -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="http" />
    </intent>
    ...
</queries>
```

This configuration allows the app to query and launch external browsers when the user taps "Visit Festival Website" button in the Festival Info screen.

## App Icon

**Note:** This configuration includes a basic adaptive icon (XML vector drawable) for Android 8.0+ (API 26+).

For complete icon support across all Android versions:

**Recommended:** Use [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons):
```bash
flutter pub add dev:flutter_launcher_icons
# Add configuration to pubspec.yaml with your icon image, then:
flutter pub run flutter_launcher_icons
```

Or manually create PNG icons in each mipmap density folder (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi).

## Building for Android

To build the Android app:

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# Install on connected device
flutter install
```

## Testing URL Launching

To test the fix:

1. Build and install the app on an Android device or emulator
2. Navigate to the Festival Info screen
3. Tap "Visit Festival Website" button
4. The festival website should open in the device's default browser

If you encounter issues, check the Android logcat for any permission or intent errors:
```bash
flutter logs
```
