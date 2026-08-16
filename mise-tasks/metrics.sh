#!/usr/bin/env bash
#MISE description="Code metrics report (complexity, nesting, params) — pass a path to limit scope"
#MISE depends=["generate"]
#USAGE arg "[paths]" help="Paths to measure, space-separated" default="lib"

# depends=["generate"] is load-bearing, not cosmetic. DCL silently skips
# compilation units it cannot resolve — with a *.mocks.dart absent it still
# prints "no issues found!" and exits 0 (verified). Without the dependency,
# `mise run check` schedules this before `generate` and the report would quietly
# cover less than it claims.
#
# Thresholds MUST be passed explicitly. `metrics analyze` with no threshold flags
# prints "no issues found!" even when a member scores 32 — the values in `--help`
# are display text, not applied defaults. A bare run is silently useless, which
# is the whole reason this wrapper exists.
#
# Only structural metrics are enabled. The suite's other metrics were measured
# against this codebase on 2026-08-16 and rejected as noise for declarative
# Flutter code:
#   maintainability-index=50  flagged 80 members (~14% of the codebase) — MI
#                             penalises long widget trees, which are normal here.
#   source-lines-of-code=50   flagged 46, almost all long-but-flat build()
#   lines-of-code=100         flagged 20, same reason
#   weight-of-class=0.33      flagged 10, no actionable signal on State classes
# Pass them by hand for a one-off survey:
#   dart run dart_code_linter:metrics analyze lib --maintainability-index=50
#
# number-of-methods is 15, not DCL's 10: State classes here legitimately carry
# several _build* helpers (the pattern #561 moved toward).
#
# Known blind spot: DCL does not count Dart 3 switch-expression arms or
# collection-`if`. Members whose branching lives there read lower than they are —
# DrinkCard._buildCardSemanticLabel has 16 real decision points and scores 10;
# Festival.toJson has 13 and is not flagged. Clean is necessary, not sufficient.

set -uo pipefail

read -ra PATHS <<<"${usage_paths:-lib}"

METRICS_LOG="${METRICS_LOG:-$(mktemp /tmp/metrics-XXXXXX.log)}"
echo "METRICS_LOG=$METRICS_LOG"

dart run dart_code_linter:metrics analyze "${PATHS[@]}" \
	--cyclomatic-complexity=10 \
	--maximum-nesting-level=5 \
	--number-of-parameters=4 \
	--number-of-methods=15 \
	--reporter=console 2>&1 |
	grep -v -E "Woah! You appear|superuser privileges" |
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g' |
	grep -v -E "Processing [0-9]+ file|Analysis is completed" |
	tee "$METRICS_LOG"

EXIT_CODE=${PIPESTATUS[0]}
echo "---"
echo "Grep with: grep -nE 'ALARM|WARNING' $METRICS_LOG"
exit "$EXIT_CODE"
