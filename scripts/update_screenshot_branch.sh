#!/bin/bash
# Script to update screenshots to the pr-screenshot branch

set -e

PR_NUMBER="$1"
SOURCE_BRANCH="$2"

if [ -z "$PR_NUMBER" ]; then
  echo "Error: PR_NUMBER argument required"
  exit 1
fi

if [ -z "$SOURCE_BRANCH" ]; then
  echo "Error: SOURCE_BRANCH argument required"
  exit 1
fi

BRANCH_NAME="pr-screenshot"
PR_FOLDER="pr-$PR_NUMBER"

echo "Updating screenshots to branch: $BRANCH_NAME"
echo "PR folder: $PR_FOLDER"
echo "Source branch: $SOURCE_BRANCH"

# Store the current directory to return to it
ORIGINAL_DIR=$(pwd)

# Copy screenshots to a temp directory BEFORE switching branches
TEMP_DIR=$(mktemp -d)
echo "Copying screenshots to temporary directory: $TEMP_DIR"
cp test/screenshots/goldens/*.png "$TEMP_DIR/" || {
  echo "Error: No screenshot files found in test/screenshots/goldens/"
  exit 1
}

# Configure git
git config --local user.email "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

# Check if pr-screenshot branch exists
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "Branch $BRANCH_NAME exists, checking it out..."
  git fetch origin "$BRANCH_NAME"
  git checkout "$BRANCH_NAME"
  
  # Pull latest changes
  git pull origin "$BRANCH_NAME"
else
  echo "Creating new branch $BRANCH_NAME..."
  git checkout --orphan "$BRANCH_NAME"
  
  # Remove all files from the new orphan branch
  git rm -rf . || true
  
  # Create README
  cat > README.md << 'EOF'
# PR Screenshots

This branch contains screenshots organized by PR number.

Each PR has its own folder: `pr-{number}/`

## Structure

```
pr-123/
├── drinks_screen_phone_light.png
├── drinks_screen_phone_dark.png
└── ...
pr-124/
├── about_screen_phone_light.png
└── ...
```

Screenshots are automatically generated and committed by the Screenshot Tests workflow.
EOF
  
  git add README.md
  git commit -m "Initialize pr-screenshot branch"
fi

# Create or update the PR folder
echo "Creating/updating $PR_FOLDER directory..."
mkdir -p "$PR_FOLDER"

# Copy screenshots from temp directory to the PR folder
echo "Copying screenshots from temp directory to $PR_FOLDER..."
cp "$TEMP_DIR"/*.png "$PR_FOLDER/"

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Add and commit
git add "$PR_FOLDER"/*.png

if git diff --staged --quiet; then
  echo "No screenshot changes to commit"
  exit 0
else
  echo "Committing screenshot changes..."
  git commit -m "Update screenshots for PR #$PR_NUMBER [skip ci]"
  
  echo "Pushing to $BRANCH_NAME..."
  git push origin "$BRANCH_NAME"
  
  echo "✓ Screenshots updated successfully to $BRANCH_NAME/$PR_FOLDER"
fi
