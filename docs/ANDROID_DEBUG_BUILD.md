# Android Debug Build

This document explains how to download the debug APK artifact from the GitHub Actions workflow.

## Workflow Location

The Android debug build workflow runs automatically on:
- Push to the `main` branch
- Pull requests targeting `main`
- Manual trigger via `workflow_dispatch`

## Downloading the Debug APK

1. Navigate to the **Actions** tab of the repository
2. Select a completed **Android Debug Build** workflow run
3. Scroll down to the **Artifacts** section
4. Download the **app-debug-apk** artifact

The downloaded ZIP file contains `app-debug.apk`, an unsigned debug APK suitable for sideloading onto Android devices.

## Notes

- This is an unsigned debug APK intended for testing purposes only
- Enable "Install from unknown sources" on your Android device to sideload the APK
