#!/usr/bin/env bash
#MISE description="Run after editing any .sh or mise-tasks/ file"

set -euo pipefail

# Exclusions are unanchored (`*/.mise/*`, not `./.mise/*`) so they also match
# nested copies inside agent worktrees, which carry their own extracted Flutter
# SDK — thousands of vendored .sh files, some of which shfmt/shellcheck reject
# (#509). Worktrees are skipped outright as well: their scripts are already
# covered by this same task in the main tree.
mapfile -t ALL_FILES < <(find . -name "*.sh" \
	-not -path "./.git/*" \
	-not -path "*/.mise/*" \
	-not -path "*/.claude/worktrees/*" \
	-not -path "*/node_modules/*" | sort)

if [ "${#ALL_FILES[@]}" -eq 0 ]; then
	echo "No shell scripts found"
	exit 0
fi

echo "Formatting ${#ALL_FILES[@]} files with shfmt..."
shfmt -w -i 0 -ci "${ALL_FILES[@]}"
echo "shfmt complete"
