#!/bin/bash
# Script to copy screenshots from test goldens to a screenshots directory for easier access

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDENS_DIR="$PROJECT_ROOT/test/screenshots/goldens"
SCREENSHOTS_DIR="$PROJECT_ROOT/screenshots"

echo "Copying screenshots from test goldens to screenshots directory..."

# Create screenshots directory if it doesn't exist
mkdir -p "$SCREENSHOTS_DIR"

# Copy all screenshots
cp -v "$GOLDENS_DIR"/*.png "$SCREENSHOTS_DIR/"

echo ""
echo "✓ Screenshots copied successfully to $SCREENSHOTS_DIR"
echo "  Total screenshots: $(ls -1 "$SCREENSHOTS_DIR"/*.png | wc -l)"
