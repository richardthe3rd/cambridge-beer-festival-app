# Release Process

This project uses **CalVer** (`YYYY.M.patch`) for versioning. Releases are triggered by pushing a `v*` tag, which kicks off automatic web and Android deployments.

## Version Format

| Component | Format | Example |
|-----------|--------|---------|
| Version name | `YYYY.M.patch` | `2026.5.2` |
| Build number | `YYYYMMDD` (release date) | `20260509` |
| pubspec.yaml | `version: YYYY.M.patch+YYYYMMDD` | `2026.5.2+20260509` |
| Git tag | `vYYYY.M.patch` | `v2026.5.2` |

Patch number resets to `1` each month. Increment for each release within a month (`2026.5.1`, `2026.5.2`, …).

## Step-by-Step Release

### 1. Bump version in pubspec.yaml

On `main`, edit the `version` line:

```yaml
version: 2026.5.2+20260509
```

Replace `20260509` with today's date (`YYYYMMDD`).

### 2. Commit and push

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 2026.5.2"
git push origin main
```

### 3. Tag and push

```bash
git tag v2026.5.2
git push origin v2026.5.2
```

That's it. Pushing the tag triggers the release workflows automatically.

## What happens next (automated)

| Workflow | Action |
|----------|--------|
| `release-web.yml` | Runs tests, builds, and deploys web app to `cambeerfestival.app` |
| `release-android.yml` | Builds signed APK/AAB, creates GitHub Release, uploads to Google Play Internal track |

Monitor progress in the [Actions tab](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions).

## Promote Android release (manual)

Once the Internal track build is available:

1. Open [Google Play Console](https://play.google.com/console)
2. Navigate to your app → Internal testing
3. Promote to Alpha / Beta / Production as appropriate

## Verify production

Visit [cambeerfestival.app](https://cambeerfestival.app) and confirm the release is live.

## Hotfix releases

Branch from the release tag rather than `main`:

```bash
git checkout v2026.5.2
git checkout -b hotfix/2026.5.3
# fix, bump version, commit
git tag v2026.5.3
git push origin v2026.5.3
```

Then backport the fix to `main` via a normal PR.

## See also

- [CI/CD Workflows](ci-cd.md) — full workflow documentation
- [GitHub Secrets](../tooling/github-secrets.md) — secrets required for release workflows
