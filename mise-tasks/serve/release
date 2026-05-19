#!/usr/bin/env bash
#MISE description="Serve release build with http-server (SPA mode for deep linking)"

set -euo pipefail
if [ ! -d "build/web" ]; then
	echo "Error: build/web directory not found"
	echo "Run: mise run build:web first"
	exit 1
fi

echo "Starting http-server with SPA routing..."
echo "Available at: http://localhost:8080"
echo "Press Ctrl+C to stop"
npx http-server build/web -p 8080 --proxy http://localhost:8080?
