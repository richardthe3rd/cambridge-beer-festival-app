#!/usr/bin/env bash
#MISE description="Run e2e tests in Playwright UI mode (interactive)"

set -euo pipefail
echo "Running e2e tests in UI mode..."
npm run test:e2e:ui
