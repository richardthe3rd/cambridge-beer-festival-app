# GitHub Secrets Reference

This document lists all GitHub Secrets needed for the Cambridge Beer Festival app CI/CD workflows.

## Current Secrets (Already Configured)

| Secret Name | Purpose | Used In | Status |
|-------------|---------|---------|--------|
| `CLOUDFLARE_API_TOKEN` | Deploy Cloudflare Worker | `build-deploy.yml` | ✅ Required |
| `CODECOV_TOKEN` | Upload coverage to Codecov | `build-deploy.yml` | ⚠️ Optional |

## Secrets for Signed Android Releases (Optional)

These secrets are **not required** for the current unsigned release workflow, but will be needed if you want to sign APKs/AABs in CI/CD.

| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `KEYSTORE_BASE64` | Base64-encoded keystore file | `base64 -i upload-keystore.jks \| tr -d '\n'` | ❌ Optional |
| `KEYSTORE_PASSWORD` | Keystore password | Password from keystore creation | ❌ Optional |
| `KEY_ALIAS` | Key alias | Usually `upload` | ❌ Optional |
| `KEY_PASSWORD` | Key password | Usually same as keystore password | ❌ Optional |

## How to Configure Secrets

### 1. Navigate to Repository Settings

1. Go to your repository on GitHub
2. Click **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 2. Add Each Secret

For each secret:
1. Enter the **Name** (exactly as shown in the table)
2. Enter the **Value**
3. Click **Add secret**

## Creating Signing Secrets

### Step 1: Generate Keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

**Important:**
- Use a strong password
- Store the password securely (you'll need it for GitHub Secrets)
- Keep the `.jks` file safe - you cannot regenerate it

### Step 2: Convert Keystore to Base64

**Linux/Mac:**
```bash
base64 -i upload-keystore.jks | tr -d '\n' | pbcopy
# Or to save to file:
base64 -i upload-keystore.jks | tr -d '\n' > keystore-base64.txt
```

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
# Or to save to file:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore-base64.txt
```

### Step 3: Add to GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `KEYSTORE_BASE64` | Paste the entire base64 string (no line breaks) |
| `KEYSTORE_PASSWORD` | The password you entered during keystore creation |
| `KEY_ALIAS` | `upload` (or whatever you specified with `-alias`) |
| `KEY_PASSWORD` | Usually the same as `KEYSTORE_PASSWORD` |

## Current Workflow Status

### ✅ Working Without Signing Secrets

The current release workflow (`.github/workflows/release.yml`) produces **unsigned** builds and does **not require** any signing secrets.

**What works now:**
- ✅ Unsigned APK (can be installed on devices with "unknown sources")
- ✅ Unsigned AAB (can be uploaded to Play Console with Play App Signing)
- ✅ Automatic GitHub Releases on version tags
- ✅ Checksums for verification

### 🔐 If You Want Signed Releases in CI/CD

To sign APKs/AABs automatically in GitHub Actions:

1. **Generate keystore** (see Step 1 above)
2. **Add the 4 secrets** to GitHub (see table above)
3. **Update `.github/workflows/release.yml`** with the signing steps from [`docs/ANDROID_RELEASE.md`](ANDROID_RELEASE.md#6-update-github-workflow-for-signed-releases)
4. **Update `android/app/build.gradle`** to configure signing (see [`docs/ANDROID_RELEASE.md`](ANDROID_RELEASE.md#3-update-buildgradle))

## Play Store Publishing with Play App Signing

**Recommended Approach**: Don't sign in CI/CD. Use Play App Signing instead.

With Play App Signing (Google's recommended approach):
- ✅ Upload **unsigned** AAB to Play Console
- ✅ Google automatically signs with their key
- ✅ No need to manage signing keys in GitHub Secrets
- ✅ Google handles key security and rotation
- ✅ Less complexity in CI/CD

**How it works:**
1. Generate release with current workflow → Unsigned AAB
2. Download AAB from GitHub Release
3. Upload to Play Console
4. Google signs it automatically with Play App Signing
5. Done! ✨

## Security Best Practices

### ✅ Do

- Store keystores in a secure password manager
- Use strong passwords (20+ characters)
- Enable 2FA on your GitHub account
- Limit repository access to trusted collaborators
- Use Play App Signing for production apps
- Back up keystores to encrypted storage

### ❌ Don't

- Commit keystores (`.jks`, `.keystore`) to git
- Commit `key.properties` to git
- Share keystore passwords in plain text
- Store keystores in cloud storage without encryption
- Reuse keystores across different apps
- Share the same keystore with multiple people

## Verification

### Check Current Secrets

1. Go to Repository Settings → Secrets and variables → Actions
2. You should see:
   - ✅ `CLOUDFLARE_API_TOKEN` (required for worker deployment)
   - ⚠️ `CODECOV_TOKEN` (optional for coverage)
   - ❌ No signing secrets (not needed for unsigned releases)

### Test Release Workflow

```bash
# Create a test tag
git tag -a v2025.12.0 -m "Test release"
git push origin v2025.12.0

# Check GitHub Actions
# Go to: https://github.com/richardthe3rd/cambridge-beer-festival-app/actions

# Verify:
# ✅ Release workflow runs successfully
# ✅ Unsigned APK and AAB are created
# ✅ GitHub Release is published
```

## Troubleshooting

### "Error: Secret not found"

**Cause**: Workflow references a secret that doesn't exist

**Solution**:
- Check secret names are spelled correctly (case-sensitive)
- Verify secrets are added at the repository level, not organization
- Ensure workflow has permissions to access secrets

### "Failed to decode keystore"

**Cause**: `KEYSTORE_BASE64` is incorrect or has line breaks

**Solution**:
- Ensure you used `tr -d '\n'` to remove all line breaks
- Copy the entire base64 string with no spaces or newlines
- Re-encode the keystore and update the secret

### "Keystore password incorrect"

**Cause**: `KEYSTORE_PASSWORD` or `KEY_PASSWORD` is wrong

**Solution**:
- Verify the password matches what you used during keystore creation
- Keystore password and key password are often the same
- Check for typos or extra spaces

## Summary

### Current Setup (December 2025)

- **Signing**: ❌ Disabled (unsigned releases)
- **Required Secrets**: 1 (`CLOUDFLARE_API_TOKEN`)
- **Optional Secrets**: 1 (`CODECOV_TOKEN`)
- **Release Method**: Tag-based automatic releases
- **Play Store**: Upload unsigned AAB, Google signs it

### Future: If You Enable Signing

- **Signing**: ✅ Enabled in CI/CD
- **Required Secrets**: 5 (add 4 keystore secrets)
- **Release Method**: Same (tag-based)
- **Play Store**: Upload pre-signed AAB

## Resources

- [Android App Signing Documentation](https://developer.android.com/studio/publish/app-signing)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)

---

**Last Updated**: December 2025
**Maintained by**: [Your Name]
