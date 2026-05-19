#!/usr/bin/env bash
#MISE description="Run tests with coverage reporting (output: coverage/lcov.info)"
#MISE depends=["generate"]

set -euo pipefail
flutter test --coverage
echo "Coverage report generated at coverage/lcov.info"
echo "To view HTML report, install lcov and run: genhtml coverage/lcov.info -o coverage/html"
