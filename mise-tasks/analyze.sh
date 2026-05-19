#!/usr/bin/env bash
#MISE description="Run after Dart changes — pass a path to limit scope; grep output with the path printed at start"
#MISE depends=["generate"]

set -euo pipefail
ANALYZE_LOG="${ANALYZE_LOG:-$(mktemp /tmp/analyze-XXXXXX.log)}"
echo "ANALYZE_LOG=$ANALYZE_LOG"
flutter analyze --no-fatal-infos "$@" 2>&1 | tee "$ANALYZE_LOG"
EXIT_CODE=$?
echo "---"
echo "Grep with: grep -n 'error\|warning' $ANALYZE_LOG"
exit $EXIT_CODE
