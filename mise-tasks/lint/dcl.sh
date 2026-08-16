#!/usr/bin/env bash
#MISE description="Gate on dart_code_linter rules (correctness rules flutter analyze cannot see)"

# Rules only — deliberately NO metric threshold flags. Metric warnings also trip
# --set-exit-on-violation-level (verified: exit 2), and the metrics are a report,
# not a gate. Keep them in `mise run metrics`; keep the gate here.
#
# The enabled rule set lives in analysis_options.yaml under `dart_code_linter:`,
# along with the measured reason each rejected rule was rejected. It is currently
# 3 rules with zero violations across lib/ and test/, so any output here is a
# regression.
#
# NOT run by CI — .github/workflows/ is off-limits without an explicit request,
# so this gates locally via `mise run check` only.

set -uo pipefail

# "${@:-lib test}" would collapse the default into a single argv entry, which
# DCL rejects as an unparseable path. Rewrite argv instead.
if [ "$#" -eq 0 ]; then
	set -- lib test
fi

dart run dart_code_linter:metrics analyze "$@" \
	--set-exit-on-violation-level=warning \
	--reporter=console 2>&1 |
	grep -v -E "Woah! You appear|superuser privileges" |
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g' |
	grep -v -E "Processing [0-9]+ file|Analysis is completed"

exit "${PIPESTATUS[0]}"
