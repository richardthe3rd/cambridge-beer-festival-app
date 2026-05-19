#!/usr/bin/env bash
#MISE description="Run all Flutter tests (output saved to $TEST_LOG, or set TEST_LOG to reuse a path)"
#MISE depends=["generate"]

set -euo pipefail
TEST_LOG="${TEST_LOG:-$(mktemp /tmp/test-XXXXXX.log)}"
echo "TEST_LOG=$TEST_LOG"
flutter test 2>&1 | tee "$TEST_LOG"
EXIT_CODE=$?
echo "---"
echo "Grep with: grep -n 'FAILED\|ERROR' $TEST_LOG"
exit $EXIT_CODE
