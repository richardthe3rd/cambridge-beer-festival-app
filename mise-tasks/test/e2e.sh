#!/usr/bin/env bash
#MISE description="Run e2e tests with Playwright (headless mode)"

set -euo pipefail
echo "Running e2e tests with Playwright..."
npm run test:e2e
