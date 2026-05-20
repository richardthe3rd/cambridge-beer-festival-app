#!/usr/bin/env bash
#MISE description="Start Flutter dev server on localhost:8080"

set -euo pipefail
echo "Starting Flutter dev server on http://localhost:8080"
flutter run -d web-server --web-port 8080 --pid-file flutter-dev.pid
