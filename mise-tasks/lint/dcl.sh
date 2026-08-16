#!/usr/bin/env bash
#MISE description="Gate on dart_code_linter rules (correctness rules flutter analyze cannot see)"
#MISE depends=["generate"]
#USAGE arg "[paths]" help="Paths to check, space-separated" default="lib test"

# depends=["generate"] is load-bearing, not cosmetic. DCL silently skips
# compilation units it cannot resolve: with test/provider_test.mocks.dart absent
# this gate still prints "no issues found!" and exits 0 (verified), which would
# skip every test importing it. Without the dependency, `mise run check`
# schedules this task first — before `generate` — so a new test carrying a fresh
# @GenerateNiceMocks annotation would sail through unchecked.
#
# Rules only — deliberately NO metric threshold flags. Metric warnings also trip
# --set-exit-on-violation-level (verified: exit 2), and the metrics are a report,
# not a gate. Keep those in `mise run metrics`; keep the gate here.
#
# The enabled rule set lives in analysis_options.yaml under `dart_code_linter:`,
# with the measured reason each rejected rule was rejected. It is currently 3
# rules with zero violations across lib/ and test/, so any output is a
# regression.
#
# Mirrored in CI as the "Lint (dart_code_linter rules)" step of ci.yml's
# `analyze` job (that job generates mocks, which DCL needs — it silently skips
# units it cannot resolve). Keep the flags here and there in sync; the rule set
# itself is shared via analysis_options.yaml.

set -uo pipefail

read -ra PATHS <<<"${usage_paths:-lib test}"

dart run dart_code_linter:metrics analyze "${PATHS[@]}" \
	--set-exit-on-violation-level=warning \
	--reporter=console 2>&1 |
	grep -v -E "Woah! You appear|superuser privileges" |
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g' |
	grep -v -E "Processing [0-9]+ file|Analysis is completed"

exit "${PIPESTATUS[0]}"
