#!/usr/bin/env bash
#MISE description="Run after Dart changes — pass a path to limit scope; grep output with the path printed at start"
#MISE depends=["generate"]

set -uo pipefail
ANALYZE_LOG="${ANALYZE_LOG:-$(mktemp /tmp/analyze-XXXXXX.log)}"
echo "ANALYZE_LOG=$ANALYZE_LOG"
flutter analyze --no-fatal-infos "$@" 2>&1 |
	grep -v -E "Woah! You appear|superuser privileges" |
	tee "$ANALYZE_LOG"
EXIT_CODE=${PIPESTATUS[0]}
echo "---"
echo "Grep with: grep -n 'error\|warning' $ANALYZE_LOG"
exit "$EXIT_CODE"
