# Release Process

This project uses **CalVer** (`YYYY.M.patch`) for versioning. Releases are fully automated via a release PR model: changes land on `main`, a PR is kept up to date reflecting the pending release, and merging that PR triggers the actual release.

## Version Format

| Component | Format | Example |
|-----------|--------|---------|
| Version name | `YYYY.M.patch` | `2026.5.2` |
| Build number | `YYYYMMDD` (release date) | `20260509` |
| pubspec.yaml | `version: YYYY.M.patch+YYYYMMDD` | `2026.5.2+20260509` |
| Git tag | `vYYYY.M.patch` | `v2026.5.2` |

Patch number resets to `0` each month. Increment for each release within a month (`2026.5.0`, `2026.5.1`, …).

## How Releases Work

### 1. The release PR is created automatically

Every push to `main` (and a daily cron at 06:00 UTC) triggers `release-pr.yml`, which:

1. Computes the next version by inspecting existing `v*` tags for the current month
2. Runs [git-cliff](https://git-cliff.org/) to generate a changelog from unreleased commits
3. Updates `pubspec.yaml` with the new version
4. Prepends the new section to `CHANGELOG.md`
5. Opens or force-updates a PR from `release/next` → `main` titled `Release X.Y.Z`

The PR is skipped if there are no releasable commits (i.e. only `chore`/`ci`/`test` changes since the last tag).

### 2. Review and merge the release PR

Inspect the auto-generated changelog in the PR body. Add context to the body if helpful, then merge when ready to ship.

### 3. Deployment happens automatically

Merging the release PR triggers `release.yml`, which:

1. Reads the version from `pubspec.yaml` (source of truth)
2. Creates and pushes the git tag (e.g. `v2026.5.5`)
3. Creates a GitHub Release from that tag with the `CHANGELOG.md` body

Creating the GitHub Release triggers the deployment workflows (via `on: release: published`):

| Workflow | Action |
|----------|--------|
| `release-web.yml` | Builds and deploys web app to `cambeerfestival.app` |
| `release-android.yml` | Builds signed APK/AAB, attaches artifacts to the GitHub Release, uploads to Google Play Internal track |

Monitor progress in the [Actions tab](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions).

## What goes into a release

git-cliff reads conventional commit messages since the last tag. The following types are included:

| Type | Changelog section |
|------|-------------------|
| `feat` | Features |
| `fix` | Bug Fixes |
| `perf` | Performance |
| `refactor` | Refactoring |
| `docs` | Documentation |

Types `chore`, `ci`, `build`, `style`, and `test` are excluded. Unconventional commits are also excluded.

## Hotfix releases

Branch from the release tag rather than `main`:

```bash
git checkout v2026.5.2
git checkout -b hotfix/fix-description
# fix, commit using conventional commit message
git push origin hotfix/fix-description
# Open a PR targeting main, merge normally
```

After merging to `main`, the release PR will pick up the fix in the next run and compute the next patch version automatically.

## Promote Android release (manual)

Once the Internal track build is available:

1. Open [Google Play Console](https://play.google.com/console)
2. Navigate to your app → Internal testing
3. Promote to Alpha / Beta / Production as appropriate

## Verify production

Visit [cambeerfestival.app](https://cambeerfestival.app) and confirm the release is live.

## See also

- [CI/CD Workflows](ci-cd.md) — full workflow documentation
- [GitHub Secrets](../tooling/github-secrets.md) — secrets required for release workflows
