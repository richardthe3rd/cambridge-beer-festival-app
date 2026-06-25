#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

echo '{"async": true, "asyncTimeout": 300000}'

cd "$CLAUDE_PROJECT_DIR"

# Install Flutter 3.44.0 and all mise-managed tools (Node, shellcheck, shfmt).
# bin/mise self-bootstraps so no prior installation is required.
./bin/mise install

# Fetch pub dependencies and generate mocks.
# [deps.flutter] auto=true in mise.toml triggers flutter pub get automatically.
./bin/mise run generate
