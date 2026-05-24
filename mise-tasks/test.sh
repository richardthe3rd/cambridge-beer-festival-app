#!/usr/bin/env bash
#MISE description="Run before committing — pass a file arg to run a subset; grep output with the path printed at start"
#MISE depends=["generate"]

set -uo pipefail
TEST_LOG="${TEST_LOG:-$(mktemp /tmp/test-XXXXXX.log)}"
echo "TEST_LOG=$TEST_LOG"
flutter test "$@" 2>&1 |
	grep -v -E "Woah! You appear|superuser privileges" |
	tee "$TEST_LOG"
EXIT_CODE=${PIPESTATUS[0]}
echo "---"
echo "Grep with: grep -n 'FAILED\|ERROR' $TEST_LOG"
exit "$EXIT_CODE"
