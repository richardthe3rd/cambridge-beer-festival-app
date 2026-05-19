#!/usr/bin/env bash
#MISE description="Run after editing any .sh or mise-tasks/ file"
#MISE tools={shellcheck="system"}

set -euo pipefail

mapfile -t ALL_FILES < <(find . -name "*.sh" -not -path "./.git/*" -not -path "*/node_modules/*" | sort)

if [ "${#ALL_FILES[@]}" -eq 0 ]; then
	echo "No shell scripts found"
	exit 0
fi

echo "Running shellcheck on ${#ALL_FILES[@]} files..."
shellcheck "${ALL_FILES[@]}"
echo "shellcheck passed"
