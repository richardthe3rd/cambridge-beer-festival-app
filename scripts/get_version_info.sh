#!/bin/bash
# Get version information from git for build-time injection

set -e

# Get git tag (if available)
GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")

# Get git commit hash (short)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Get git branch
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Get build timestamp
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# If we have a tag, use it as the version (strip 'v' prefix)
if [ -n "$GIT_TAG" ]; then
  VERSION="${GIT_TAG#v}"
else
  # Fall back to pubspec.yaml version + commit
  PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1)
  VERSION="${PUBSPEC_VERSION}+git.${GIT_COMMIT}"
fi

# Output format for GitHub Actions
if [ "$1" == "github" ]; then
  echo "git_tag=$GIT_TAG"
  echo "git_commit=$GIT_COMMIT"
  echo "git_branch=$GIT_BRANCH"
  echo "version=$VERSION"
  echo "build_time=$BUILD_TIME"
# Output format for --dart-define flags
elif [ "$1" == "dart-define" ]; then
  echo "--dart-define=GIT_TAG=$GIT_TAG --dart-define=GIT_COMMIT=$GIT_COMMIT --dart-define=GIT_BRANCH=$GIT_BRANCH --dart-define=BUILD_VERSION=$VERSION --dart-define=BUILD_TIME=$BUILD_TIME"
# Output format for human reading
else
  echo "Version: $VERSION"
  echo "Git Tag: ${GIT_TAG:-none}"
  echo "Git Commit: $GIT_COMMIT"
  echo "Git Branch: $GIT_BRANCH"
  echo "Build Time: $BUILD_TIME"
fi
