#!/usr/bin/env bash
#MISE description="Report unused code, unused files, and unnecessary nullable params"
#MISE depends=["generate"]
#USAGE arg "[path]" help="Path to check" default="lib"

# depends=["generate"] for the same reason as the sibling tasks: DCL silently
# skips unresolvable compilation units, so running before `generate` would
# under-report. Unused-code detection is especially sensitive to this — a
# generated file is exactly the kind of thing that references otherwise-unused
# members.
#
# All three checks came back clean on 2026-08-16, so any output is a regression.
# Not wired into `check`: each walks the whole package and takes ~30s.

set -uo pipefail

TARGET="${usage_path:-lib}"
EXIT_CODE=0

for CHECK in check-unused-code check-unused-files check-unnecessary-nullable; do
	echo "===== $CHECK ====="
	dart run "dart_code_linter:metrics" "$CHECK" "$TARGET" 2>&1 |
		grep -v -E "Woah! You appear|superuser privileges" |
		sed 's/\x1b\[[0-9;]*[A-Za-z]//g' |
		grep -v -E "Processing [0-9]+ file|Analysis is completed"
	STATUS=${PIPESTATUS[0]}
	[ "$STATUS" -ne 0 ] && EXIT_CODE="$STATUS"
done

exit "$EXIT_CODE"
