#!/bin/bash
# Patch AndroidManifest.xml to add package visibility queries for url_launcher
# This fixes issue #53: Cannot open festival website on Android

set -e

MANIFEST_PATH="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST_PATH" ]; then
    echo "Error: AndroidManifest.xml not found at $MANIFEST_PATH"
    exit 1
fi

echo "Patching $MANIFEST_PATH to add url_launcher queries..."

# Check if queries section already exists
if grep -q "<queries>" "$MANIFEST_PATH"; then
    echo "Queries section already exists, skipping patch"
    exit 0
fi

# Add queries section after <manifest> tag
sed -i '/<manifest/a\
    <!-- Package visibility queries for Android 11+ (API 30+) - FIX FOR ISSUE #53 -->\
    <queries>\
        <!-- Required for url_launcher to open URLs in external browser -->\
        <intent>\
            <action android:name="android.intent.action.VIEW" />\
            <data android:scheme="https" />\
        </intent>\
        <intent>\
            <action android:name="android.intent.action.VIEW" />\
            <data android:scheme="http" />\
        </intent>\
    </queries>\
' "$MANIFEST_PATH"

echo "✓ Successfully patched AndroidManifest.xml"
echo "Added package visibility queries for url_launcher"
