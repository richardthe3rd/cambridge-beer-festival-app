#!/usr/bin/env bash
#MISE description="Run e2e tests in headed mode (visible browser)"

set -euo pipefail
echo "Running e2e tests in headed mode..."
npm run test:e2e:headed
