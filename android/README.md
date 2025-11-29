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
- **Phone calls** - For tel: scheme (future-proofing)
- **Email** - For mailto: scheme (future-proofing)
- **SMS** - For smsto: scheme (future-proofing)

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

**Note:** The default launcher icons are placeholders. To add custom launcher icons:

1. Create icon assets in appropriate sizes for each density folder:
   - `mipmap-mdpi/ic_launcher.png` (48x48)
   - `mipmap-hdpi/ic_launcher.png` (72x72)
   - `mipmap-xhdpi/ic_launcher.png` (96x96)
   - `mipmap-xxhdpi/ic_launcher.png` (144x144)
   - `mipmap-xxxhdpi/ic_launcher.png` (192x192)

2. Or use a tool like [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) to generate them automatically.

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
