#!/bin/bash
# Script to check for new or modified screenshot golden files

set -e

BASE_REF="$1"

if [ -z "$BASE_REF" ]; then
  echo "Error: BASE_REF argument required"
  exit 1
fi

# Fetch base branch
git fetch origin "$BASE_REF"

# Find new or modified golden files
CHANGED_FILES=$(git diff --name-only "origin/$BASE_REF...HEAD" -- test/screenshots/goldens/*.png || true)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo "0")

echo "changed_count=$CHANGED_COUNT"
echo "Changed files:"
echo "$CHANGED_FILES"

# Export for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "changed_count=$CHANGED_COUNT" >> "$GITHUB_OUTPUT"
  
  if [ "$CHANGED_COUNT" -gt 0 ]; then
    echo "new_or_modified_files<<EOF" >> "$GITHUB_OUTPUT"
    echo "$CHANGED_FILES" >> "$GITHUB_OUTPUT"
    echo "EOF" >> "$GITHUB_OUTPUT"
  fi
fi
