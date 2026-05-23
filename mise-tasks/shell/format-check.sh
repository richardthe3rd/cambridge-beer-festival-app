#!/usr/bin/env bash
#MISE description="Check shell formatting without modifying files"

set -euo pipefail

mapfile -t ALL_FILES < <(find . -name "*.sh" -not -path "./.git/*" -not -path "./.mise/*" -not -path "*/node_modules/*" | sort)

if [ "${#ALL_FILES[@]}" -eq 0 ]; then
	echo "No shell scripts found"
	exit 0
fi

echo "Checking ${#ALL_FILES[@]} files with shfmt..."
shfmt -d -i 0 -ci "${ALL_FILES[@]}"
echo "shfmt check passed"
