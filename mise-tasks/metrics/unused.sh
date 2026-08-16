#!/usr/bin/env bash
#MISE description="Report unused code, unused files, and unnecessary nullable params"

# All three came back clean on 2026-08-16, so any output here is a regression.
# Not wired into `check`: these walk the whole package and take ~30s each.

set -uo pipefail

TARGET="${1:-lib}"
EXIT_CODE=0

for CHECK in check-unused-code check-unused-files check-unnecessary-nullable; do
	echo "===== $CHECK ====="
	dart run "dart_code_linter:metrics" "$CHECK" "$TARGET" 2>&1 |
		grep -v -E "Woah! You appear|superuser privileges" |
		sed 's/\x1b\[[0-9;]*[A-Za-z]//g' |
		grep -v -E "Processing [0-9]+ file|⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏"
	STATUS=${PIPESTATUS[0]}
	[ "$STATUS" -ne 0 ] && EXIT_CODE="$STATUS"
done

exit "$EXIT_CODE"
