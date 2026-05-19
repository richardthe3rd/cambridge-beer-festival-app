#!/usr/bin/env bash
#MISE description="Run tests with coverage reporting (output: coverage/lcov.info)"
#MISE depends=["generate"]

set -uo pipefail
flutter test --coverage 2>&1 | grep -v -E "Woah! You appear|superuser privileges"
EXIT_CODE=${PIPESTATUS[0]}
echo "Coverage report generated at coverage/lcov.info"
echo "To view HTML report, install lcov and run: genhtml coverage/lcov.info -o coverage/html"
exit "$EXIT_CODE"
