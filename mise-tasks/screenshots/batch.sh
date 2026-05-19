#!/usr/bin/env bash
#MISE description="Capture screenshots of multiple pages from config file"
#MISE usage='arg "[config]" help="Config file path" default="screenshots.config.json"\narg "[output]" help="Output directory" default="screenshots"'

set -euo pipefail
CONFIG="${usage_config:-screenshots.config.json}"
OUTPUT="${usage_output:-screenshots}"

echo "Running batch screenshot capture..."
echo "Config: $CONFIG"
echo "Output: $OUTPUT"
node scripts/screenshot-batch.mjs -c "$CONFIG" -o "$OUTPUT"
