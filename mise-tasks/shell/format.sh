#!/usr/bin/env bash
#MISE description="Format all shell scripts in place with shfmt (scripts/ and mise-tasks/)"

set -euo pipefail

mapfile -t ALL_FILES < <(find . -name "*.sh" -not -path "./.git/*" -not -path "*/node_modules/*" | sort)

if [ "${#ALL_FILES[@]}" -eq 0 ]; then
	echo "No shell scripts found"
	exit 0
fi

echo "Formatting ${#ALL_FILES[@]} files with shfmt..."
shfmt -w -i 0 -ci "${ALL_FILES[@]}"
echo "shfmt complete"
