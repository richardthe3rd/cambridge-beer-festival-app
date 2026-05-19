#!/usr/bin/env bash
#MISE description="Run Flutter code analysis (output saved to $ANALYZE_LOG, or set ANALYZE_LOG to reuse a path)"
#MISE depends=["generate"]

set -euo pipefail
ANALYZE_LOG="${ANALYZE_LOG:-$(mktemp /tmp/analyze-XXXXXX.log)}"
echo "ANALYZE_LOG=$ANALYZE_LOG"
flutter analyze --no-fatal-infos 2>&1 | tee "$ANALYZE_LOG"
EXIT_CODE=$?
echo "---"
echo "Grep with: grep -n 'error\|warning' $ANALYZE_LOG"
exit $EXIT_CODE
