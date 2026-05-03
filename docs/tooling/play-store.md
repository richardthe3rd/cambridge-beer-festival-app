# Google Play Store Metadata Quick Reference

This document provides the exact metadata needed for the Google Play Store listing.

## 📱 Basic App Information

| Field | Value |
|-------|-------|
| **App Name** | Cambridge Beer Festival |
| **Package Name** | `[REPLACE_WITH_YOUR_PACKAGE_NAME]`<br/><sub>e.g. <code>com.cambridgebeerfestival.cambridge_beer_festival</code></sub> |
| **Developer Name** | [YOUR NAME/ORGANIZATION] |
| **Contact Email** | [YOUR EMAIL] |
| **Website** | [YOUR WEBSITE or GitHub repo URL] |
| **Category** | Food & Drink |
| **Content Rating** | 18+ (Alcohol-related content) |
| **Price** | Free |

## 📝 Store Listing Text

### Short Description (80 characters)
```
Browse beers, ciders, and more at the Cambridge Beer Festival
```

### Full Description (Copy-paste ready)

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

## 📸 Visual Assets Needed

### 1. Feature Graphic (Required for featured listings)
- **Size**: 1024 × 500 pixels
- **Format**: PNG or JPEG (24-bit, no alpha)
- **Content**: App branding with "Cambridge Beer Festival" text
- **File**: Create using design tool (Canva, Figma, Photoshop)

### 2. App Icon
- ✅ Already configured in app
- **Location**: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- You also need a 512×512 high-res version for Play Console

### 3. Screenshots (Minimum 2, recommended 8)

**Recommended screenshots to take:**

1. **Home Screen** - Drink list with categories
2. **Search & Filters** - Show filter chips and search bar in use
3. **Drink Detail** - Individual drink with rating and brewery info
4. **Favorites** - Show saved favorites list
5. **Festival Info** - Festival details and map link
6. **Brewery View** - Brewery details with product list
7. **Category Filter** - Different categories (Beer, Cider, Mead)
8. **Rating System** - Show star rating interaction

**Requirements:**
- **Aspect Ratio**: 16:9 or 9:16 (portrait recommended for phone)
- **Min Dimension**: 320px (short side)
- **Max Dimension**: 3840px (long side)
- **Format**: PNG or JPEG (24-bit)
- **Recommended Phone**: 1080 × 2340 pixels (9:19.5 ratio)

**How to capture:**
```bash
# Run app on emulator or device
flutter run

# Take screenshots via Android Studio
# Device File Explorer → /sdcard/Pictures/Screenshots

# Or use ADB
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

## 🔒 Privacy Policy

You **must** provide a privacy policy URL. Host it on:
- Your website
- Cloudflare Pages
- Google Docs (make it public)

**Privacy Policy Template** (copy and customize):

```markdown
# Privacy Policy for Cambridge Beer Festival App

**Last Updated:** December 2025

## Overview

The Cambridge Beer Festival app is designed with privacy in mind. We do not collect, store, or transmit any personal information.

## Data We Collect

**None.** This app does not collect any personal information, analytics, or tracking data.

## Data Storage

- **Favorites and Ratings**: Stored locally on your device using SharedPreferences
- **No Cloud Storage**: Nothing is sent to external servers
- **No User Accounts**: No registration or login required

## Network Access

- The app fetches public festival data from our Cloudflare Worker API
- These requests contain no personal information
- API endpoint: `https://data.cambeerfestival.app`

## Permissions

The app requests the following permissions:

- **Internet Access**: Required to download festival drink data
- **Network State**: To check connectivity before fetching data

The app does NOT request:
- Location
- Camera
- Microphone
- Contacts
- Storage (beyond app-specific cache)

## Third-Party Services

- **None**: No analytics, advertising, or tracking SDKs

## Children's Privacy

This app is intended for adults 18+ due to alcohol-related content. We do not knowingly collect information from anyone under 18.

## Changes to This Policy

We may update this policy occasionally. Changes will be posted here with an updated "Last Updated" date.

## Contact

For questions about this privacy policy, contact:
- Email: [YOUR EMAIL]
- GitHub: https://github.com/richardthe3rd/cambridge-beer-festival-app

---

*This privacy policy was last updated on [DATE].*
```

**Where to host:**
- Create `docs/privacy-policy.md` in your repo
- Deploy to Cloudflare Pages
- Use URL: `https://cambeerfestival.app/privacy-policy.html` or `https://staging.cambeerfestival.app/privacy-policy.html`

## 🎯 Content Rating

When filling out the content rating questionnaire:

| Question | Answer | Reason |
|----------|--------|--------|
| Violence | ❌ No | App contains no violent content |
| Sexual content | ❌ No | No sexual content |
| Profanity | ❌ No | No crude humor or profanity |
| **Drugs/Alcohol** | ✅ **Yes** | **App is about alcoholic beverages** |
| Gambling | ❌ No | No gambling simulation |

**Result**: App will be rated 18+ (varies by region)

## 📋 Checklist Before Submission

Use this checklist when preparing your Play Store submission:

- [ ] **App built and tested**
  - [ ] APK/AAB generated via GitHub Release
  - [ ] Tested on physical device
  - [ ] All features working

- [ ] **Visual Assets**
  - [ ] Feature graphic (1024×500) created
  - [ ] High-res icon (512×512) exported
  - [ ] 2-8 screenshots captured
  - [ ] All images meet size requirements

- [ ] **Store Listing Text**
  - [ ] Short description (max 80 chars)
  - [ ] Full description (max 4000 chars)
  - [ ] App name confirmed

- [ ] **Legal & Privacy**
  - [ ] Privacy policy written and hosted
  - [ ] Privacy policy URL confirmed working
  - [ ] Content rating questionnaire completed
  - [ ] Target audience set to 18+

- [ ] **Technical**
  - [ ] Package name matches existing app (if updating)
  - [ ] Version code increased from previous version
  - [ ] Enrolled in Play App Signing
  - [ ] Android signing secrets configured in GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEYSTORE_PASSWORD`)
  - [ ] Google Play service account secret configured in GitHub (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`)
  - [ ] **First upload done manually** (CI upload only works after the app exists in Play Console)

- [ ] **Contact Information**
  - [ ] Developer email set
  - [ ] Website/support URL provided
  - [ ] Developer name/organization set

- [ ] **Release Configuration**
  - [ ] Release type selected (Production/Internal/Alpha/Beta)
  - [ ] Release notes written
  - [ ] Countries/regions selected
  - [ ] Pricing set (Free)

## 🚀 Quick Start: First Release

If this is your first time, follow these steps:

### 1. Prepare Assets (1-2 hours)
- Create feature graphic
- Take 2-8 screenshots
- Write/host privacy policy

### 2. Create Google Play Developer Account (30 min)
- Sign up at [play.google.com/console](https://play.google.com/console)
- Pay $25 registration fee
- Verify identity

### 3. Create App Listing (30 min)
- Create new app in Play Console
- Fill in all metadata from this document
- Upload visual assets

### 4. Generate Release (5 min)
```bash
git tag -a v2025.12.0 -m "Release v2025.12.0"
git push origin v2025.12.0
```

### 5. First release: upload AAB manually, then CI takes over

> **One-time step**: The Google Play Developer API cannot create a new app listing.
> For the **very first** release you must:
> 1. Download the AAB from the GitHub Release created in step 4
> 2. Upload it manually in Play Console → Internal testing → Create new release
> 3. Complete the store listing (see checklist below)
> 4. Submit and wait for the first review to pass
>
> From the **second release onwards**, CI uploads to Internal track automatically
> with no manual intervention needed.

### 6. Promote to Production in Play Console (5 min)
- Open [Google Play Console](https://play.google.com/console) → Internal testing
- Click **Promote release** → Production
- Fill in release notes
- Submit for review

### 7. Wait for Review (1-7 days)
- Google reviews the app
- You'll receive email notification
- Fix any issues if rejected
- Once approved, app goes live!

## 📞 Support Contacts

**Google Play Console Support:**
- Help Center: https://support.google.com/googleplay/android-developer
- Email: android-developer-support@google.com

**App Development Issues:**
- GitHub Issues: https://github.com/richardthe3rd/cambridge-beer-festival-app/issues

---

**Next Steps:**
1. Customize this metadata with your information
2. Create visual assets (feature graphic, screenshots)
3. Write and host privacy policy
4. Follow the release process in [ANDROID_RELEASE.md](ANDROID_RELEASE.md)
