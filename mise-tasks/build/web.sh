#!/usr/bin/env bash
#MISE description="Build Flutter web app in release mode (for local testing/e2e)"

set -euo pipefail
echo "Building Flutter web app in release mode..."
flutter build web --release --base-href "/"
echo ""
echo "Build complete! Output at: build/web/"
echo ""
echo "To serve locally for testing:"
echo "  npx http-server build/web -p 8080"
