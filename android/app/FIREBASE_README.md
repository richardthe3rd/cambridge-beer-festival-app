# Firebase Configuration for Android

## Required File

This directory needs a `google-services.json` file to enable Firebase services.

## How to Get This File

1. Follow the complete setup guide in `/docs/FIREBASE_SETUP.md`
2. Go to [Firebase Console](https://console.firebase.google.com/)
3. Select your project
4. Click the gear icon → Project settings
5. Scroll to "Your apps" section
6. Click on your Android app (or add a new Android app)
7. Download `google-services.json`
8. Place it in this directory: `android/app/google-services.json`

## File Location

```
android/
├── app/
│   ├── google-services.json  ← Place your downloaded file HERE
│   ├── google-services.json.template  ← Template file (for reference only)
│   ├── build.gradle
│   └── src/
```

## Important Notes

- **DO NOT** commit `google-services.json` to public repositories (it's in .gitignore)
- The file must be named exactly `google-services.json`
- The file is JSON format downloaded directly from Firebase Console
- Without this file, Firebase features (Crashlytics, Analytics) will not work

## Verification

After placing the file, verify it's correct:

```bash
cat android/app/google-services.json | grep project_id
```

You should see your actual Firebase project ID, not "REPLACE_WITH_YOUR_PROJECT_ID".

## Next Steps

Once you've added `google-services.json`:

1. Run `flutter pub get`
2. Run `flutter clean`
3. Build the app: `flutter build apk` or `flutter run`
4. Check logs for Firebase initialization messages

For complete setup instructions, see `/docs/FIREBASE_SETUP.md`
