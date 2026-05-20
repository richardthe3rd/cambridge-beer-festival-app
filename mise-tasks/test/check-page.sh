#!/usr/bin/env bash
#MISE description="Check page for console errors and take screenshot"
#USAGE arg "[url]" help="URL to check" default="http://localhost:8080"
#USAGE arg "[screenshot]" help="Screenshot output path" default="screenshot.png"

set -euo pipefail
URL="${usage_url:-http://localhost:8080}"
SCREENSHOT="${usage_screenshot:-screenshot.png}"

echo "Checking page: $URL"
echo "Screenshot will be saved to: $SCREENSHOT"
node scripts/check-page.mjs -u "$URL" -s "$SCREENSHOT"
