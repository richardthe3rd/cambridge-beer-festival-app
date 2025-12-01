# Firebase Setup Guide

Complete guide for setting up Firebase Crashlytics and Analytics in the Cambridge Beer Festival app.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Create Firebase Project](#step-1-create-firebase-project)
- [Step 2: Register Your Apps](#step-2-register-your-apps)
- [Step 3: Download Configuration Files](#step-3-download-configuration-files)
- [Step 4: Install Firebase CLI](#step-4-install-firebase-cli)
- [Step 5: Configure FlutterFire](#step-5-configure-flutterfire)
- [Step 6: Update Platform-Specific Configuration](#step-6-update-platform-specific-configuration)
- [Step 7: Install Dependencies](#step-7-install-dependencies)
- [Step 8: Test the Integration](#step-8-test-the-integration)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Google account
- Flutter development environment set up
- Firebase CLI installed (covered in Step 4)

---

## Step 1: Create Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `cambridge-beer-festival` (or your preferred name)
4. **Google Analytics**: Enable (recommended) - you can use existing account or create new
5. Click **"Create project"** and wait for setup to complete
6. Click **"Continue"** to enter your project

---

## Step 2: Register Your Apps

You need to register separate apps for each platform you're targeting.

### Register Android App

1. In Firebase Console, click the **Android icon** to add an Android app
2. **Android package name**: `ralcock.cbf`
   - ⚠️ **Important**: This must match your app's package ID exactly
   - This is the package name used in the Play Store listing
3. **App nickname** (optional): "Cambridge Beer Festival Android"
4. **Debug signing certificate SHA-1** (optional, but recommended for testing):
   ```bash
   # Get your debug certificate SHA-1
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
   # Default password is usually: android
   ```
5. Click **"Register app"**
6. **Download `google-services.json`** (you'll need this file!)
7. Click **"Next"** and **"Continue to console"**

### Register iOS App

1. In Firebase Console, click the **iOS icon** to add an iOS app
2. **iOS bundle ID**: `ralcock.cbf` (or your chosen bundle ID)
   - ⚠️ **Important**: This should match your iOS app's bundle identifier
3. **App nickname** (optional): "Cambridge Beer Festival iOS"
4. Click **"Register app"**
5. **Download `GoogleService-Info.plist`** (you'll need this file!)
6. Click **"Next"** and **"Continue to console"**

### Register Web App (Optional)

1. In Firebase Console, click the **Web icon** to add a web app
2. **App nickname**: "Cambridge Beer Festival Web"
3. **Firebase Hosting** (optional): Check if you want to use Firebase Hosting
4. Click **"Register app"**
5. **Copy the Firebase configuration** (you'll need this for `firebase_options.dart`)
6. Click **"Continue to console"**

---

## Step 3: Download Configuration Files

### Where to Place Configuration Files

#### Android Configuration

**File**: `google-services.json`
**Location**: `android/app/google-services.json`

```
cambridge-beer-festival-app/
├── android/
│   ├── app/
│   │   ├── google-services.json  ← Place here
│   │   └── build.gradle
│   └── build.gradle
```

**Important**: This file contains your Firebase project credentials. DO NOT commit it to public repositories unless it's a public/demo project.

#### iOS Configuration

**File**: `GoogleService-Info.plist`
**Location**: `ios/Runner/GoogleService-Info.plist`

```
cambridge-beer-festival-app/
├── ios/
│   ├── Runner/
│   │   ├── GoogleService-Info.plist  ← Place here
│   │   ├── Info.plist
│   │   └── Runner.xcodeproj
```

**Note**: You also need to add this file to Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Right-click on `Runner` folder in project navigator
3. Select "Add Files to Runner..."
4. Select `GoogleService-Info.plist`
5. Ensure "Copy items if needed" is checked
6. Click "Add"

---

## Step 4: Install Firebase CLI

The Firebase CLI and FlutterFire CLI are needed to generate platform configuration.

### Install Firebase CLI

```bash
# Using npm (recommended)
npm install -g firebase-tools

# Or using curl (macOS/Linux)
curl -sL https://firebase.tools | bash

# Verify installation
firebase --version
```

### Login to Firebase

```bash
firebase login
```

This will open a browser window for authentication.

---

## Step 5: Configure FlutterFire

FlutterFire CLI generates the `firebase_options.dart` file automatically based on your Firebase project.

### Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### Configure FlutterFire

From the root of your Flutter project:

```bash
# Configure Firebase for your project
flutterfire configure

# Or specify project explicitly
flutterfire configure --project=cambridge-beer-festival
```

This command will:
1. Detect your Firebase projects
2. Let you select which project to use
3. Detect platforms in your Flutter project
4. Generate `lib/firebase_options.dart` automatically

**Select platforms when prompted:**
- ✅ Android
- ✅ iOS
- ✅ Web (if you're building for web)

### Generated File

The command creates: `lib/firebase_options.dart`

```dart
// This file is auto-generated - DO NOT EDIT MANUALLY
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      // ... other platforms
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    // ...
  );

  // ... iOS and web configurations
}
```

---

## Step 6: Update Platform-Specific Configuration

### Android Configuration

#### 1. Update Project-Level `build.gradle`

**File**: `android/build.gradle`

Add Google services classpath:

```gradle
buildscript {
    dependencies {
        // ... existing dependencies
        classpath 'com.google.gms:google-services:4.4.0'  // Add this line
        classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9'  // Add this line
    }
}
```

#### 2. Update App-Level `build.gradle`

**File**: `android/app/build.gradle`

Add plugins at the **bottom** of the file:

```gradle
// ... rest of your build.gradle

apply plugin: 'com.google.gms.google-services'  // Add this line
apply plugin: 'com.google.firebase.crashlytics'  // Add this line
```

Also ensure `minSdkVersion` is at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Ensure this is at least 21
        // ... other config
    }
}
```

### iOS Configuration

#### 1. Update Podfile

**File**: `ios/Podfile`

Ensure platform is iOS 13.0 or higher:

```ruby
platform :ios, '13.0'  # Ensure this is at least 13.0
```

#### 2. Install Pods

```bash
cd ios
pod install
cd ..
```

#### 3. Enable Crashlytics in Xcode (Optional but Recommended)

For better crash reports with dSYM files:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your **Runner** target
3. Go to **Build Phases**
4. Click **+** → **New Run Script Phase**
5. Add this script:

```bash
"${PODS_ROOT}/FirebaseCrashlytics/run"
```

6. Ensure it runs **after** "Compile Sources" phase

---

## Step 7: Install Dependencies

### Install Flutter Packages

From the project root:

```bash
flutter pub get
```

This installs the Firebase packages already added to `pubspec.yaml`:
- `firebase_core`
- `firebase_crashlytics`
- `firebase_analytics`

### Verify Installation

Check that packages are listed in `pubspec.lock` without errors.

---

## Step 8: Test the Integration

### Test on Android

```bash
# Build and run on Android device/emulator
flutter run

# Check logcat for Firebase initialization
adb logcat | grep -i firebase
```

### Test on iOS

```bash
# Build and run on iOS device/simulator
flutter run

# Check console logs for Firebase initialization
# (View in Xcode console or device logs)
```

### Verify Crashlytics

To test crash reporting:

1. Add a test crash button temporarily:

```dart
ElevatedButton(
  onPressed: () {
    FirebaseCrashlytics.instance.crash(); // Force crash
  },
  child: Text('Test Crash'),
)
```

2. Run the app, tap the button
3. Restart the app (Crashlytics sends reports on next launch)
4. Check Firebase Console → Crashlytics (may take 5-10 minutes to appear)

### Verify Analytics

Check Firebase Console → Analytics → Events to see events being logged:
- `app_open`
- `festival_selected`
- `favorite_added`
- etc.

**Note**: Analytics events may take several hours to appear in the console.

---

## File Structure Overview

After setup, your project should have these Firebase-related files:

```
cambridge-beer-festival-app/
├── lib/
│   ├── firebase_options.dart           ← Auto-generated by flutterfire
│   ├── main.dart                       ← Firebase initialization added
│   └── services/
│       └── analytics_service.dart      ← Analytics & Crashlytics wrapper
│
├── android/
│   ├── app/
│   │   ├── google-services.json        ← Downloaded from Firebase Console
│   │   └── build.gradle                ← Updated with Firebase plugins
│   └── build.gradle                    ← Updated with classpath
│
├── ios/
│   ├── Runner/
│   │   ├── GoogleService-Info.plist    ← Downloaded from Firebase Console
│   │   └── Info.plist
│   └── Podfile                         ← Ensure iOS 13.0+
│
└── pubspec.yaml                        ← Firebase dependencies added
```

---

## Troubleshooting

### Common Issues

#### 1. "No Firebase App '[DEFAULT]' has been created"

**Solution**: Ensure `Firebase.initializeApp()` is called in `main()` before `runApp()`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BeerFestivalApp());
}
```

#### 2. "google-services.json not found"

**Solution**: Place the file in `android/app/` (not `android/`)

#### 3. "GoogleService-Info.plist not found"

**Solution**:
1. Place the file in `ios/Runner/`
2. Add it to Xcode project (right-click Runner → Add Files)

#### 4. Android build fails with "default Firebase app is not initialized"

**Solutions**:
1. Ensure `apply plugin: 'com.google.gms.google-services'` is at the **bottom** of `android/app/build.gradle`
2. Run `flutter clean && flutter pub get`
3. Verify `google-services.json` is in correct location

#### 5. iOS build fails with CocoaPods errors

**Solutions**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

#### 6. Crashlytics not showing crashes

**Solutions**:
- Ensure app is restarted after crash (reports sent on next launch)
- Check that `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)` is set
- Wait 5-10 minutes for crashes to appear in console
- For iOS, ensure dSYMs are uploaded (automatic in debug builds)

#### 7. "firebase_options.dart" doesn't exist

**Solution**: Run `flutterfire configure` from project root

#### 8. Analytics events not appearing

**Reasons**:
- Analytics has a delay (can be several hours in debug mode)
- Debug events are filtered by default in Firebase Console
- Enable debug view:
  ```bash
  # Android
  adb shell setprop debug.firebase.analytics.app com.richardalcock.cambridge_beer_festival

  # iOS - run with argument:
  -FIRAnalyticsDebugEnabled
  ```

---

## Security Considerations

### What to Commit to Git

✅ **Safe to commit**:
- `lib/firebase_options.dart` (placeholder template)
- `android/app/build.gradle` (configuration files)
- `android/build.gradle`
- `ios/Podfile`

⚠️ **DO NOT commit** (already in `.gitignore`):
- `android/app/google-services.json` (contains API keys)
- `ios/Runner/GoogleService-Info.plist` (contains API keys)
- Actual `lib/firebase_options.dart` after running `flutterfire configure`

### CI/CD Configuration

For GitHub Actions and CI/CD builds, Firebase configuration is provided via **GitHub Secrets**.

**See [GITHUB_SECRETS.md](GITHUB_SECRETS.md) for complete CI/CD setup instructions.**

The workflow automatically creates the Firebase config files from secrets during builds:
- `GOOGLE_SERVICES_JSON` → `android/app/google-services.json`
- `FIREBASE_OPTIONS_DART` → `lib/firebase_options.dart`

This allows builds to work in CI without committing sensitive files to version control.

---

## Additional Resources

- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)
- [Firebase Analytics](https://firebase.google.com/docs/analytics)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)
- [Firebase Console](https://console.firebase.google.com/)

---

## What's Already Configured

The code changes for Firebase integration are already complete:

✅ Dependencies added to `pubspec.yaml`
✅ Firebase initialization in `lib/main.dart`
✅ Crashlytics error handling in `BeerProvider`
✅ Analytics service created (`lib/services/analytics_service.dart`)
✅ Analytics events tracked throughout the app

**What you need to do:**
1. Create Firebase project
2. Download and place configuration files
3. Run `flutterfire configure`
4. Update Android/iOS build files
5. Test the integration

Once you complete these steps, Firebase Crashlytics and Analytics will be fully operational!
