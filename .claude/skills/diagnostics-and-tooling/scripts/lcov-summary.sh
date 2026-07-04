#!/usr/bin/env bash
# Summarize an lcov.info file: per-file lines-hit/lines-found and percentage,
# sorted worst-coverage-first, plus a project-wide total.
#
# Usage:
#   scripts/lcov-summary.sh [path/to/lcov.info] [min_percent]
#
#   path/to/lcov.info  default: coverage/lcov.info (relative to cwd)
#   min_percent        optional — only print files at or below this percent
#                       (use this to find the worst offenders, e.g. `40`)
#
# Output columns: LH  LF  PCT%  FILE
# A trailing "TOTAL" line gives the project-wide aggregate — this is the
# number closest to (but not identical to — see SKILL.md) the codecov
# project% gate.
set -euo pipefail

LCOV_FILE="${1:-coverage/lcov.info}"
MIN_PERCENT="${2:-100}"

if [[ ! -f "$LCOV_FILE" ]]; then
	echo "error: lcov file not found: $LCOV_FILE" >&2
	echo "Generate one with: ./bin/mise run coverage" >&2
	exit 1
fi

ROWS_FILE="$(mktemp)"
trap 'rm -f "$ROWS_FILE"' EXIT

TOTAL_LINE="$(awk -v min_percent="$MIN_PERCENT" -v rows_file="$ROWS_FILE" '
  BEGIN { total_lh = 0; total_lf = 0 }
  /^SF:/ { file = substr($0, 4); lh = 0; lf = 0; next }
  /^LH:/ { lh = substr($0, 4); next }
  /^LF:/ { lf = substr($0, 4); next }
  /^end_of_record/ {
    total_lh += lh
    total_lf += lf
    pct = (lf > 0) ? (lh * 100.0 / lf) : 100.0
    if (pct <= min_percent + 0.0001) {
      printf "%6d %6d %6.1f%%  %s\n", lh, lf, pct, file >> rows_file
    }
    next
  }
  END {
    total_pct = (total_lf > 0) ? (total_lh * 100.0 / total_lf) : 0
    printf "%6d %6d %6.1f%%  TOTAL\n", total_lh, total_lf, total_pct
  }
' "$LCOV_FILE")"

sort -k3 -n "$ROWS_FILE"
echo "------ ------ -------  ----"
echo "$TOTAL_LINE"
