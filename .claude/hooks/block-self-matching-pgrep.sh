#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Refuses a command that would wait on, or
# kill by, a `pgrep -f` / `pkill -f` pattern that matches the shell running
# the command itself — the pattern appears verbatim in that shell's own
# command line, so a wait loop never exits and a pkill kills the waiter.
#
# Blocked:  while/until ... pgrep -f "mise run check" ...
#           pkill -f "mise run check"
# Allowed:  pgrep -f "[m]ise run check"     (bracket trick: the literal text
#           "[m]ise" does not match the regex [m]ise, so the waiter is exempt)
#           a one-shot `pgrep -af mise` listing (extra self-line, no hang)
#           pgrep/pkill without -f (matches process names, not command lines)
#           the pattern inside a heredoc body (a file being written, not run)
#
# The right fix is usually not to wait at all: a job started with the Bash
# tool's run_in_background re-invokes the session when it exits. See
# AGENTS.md → "Parallel Work with Subagents → Lessons Learned".
set -euo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# Drop heredoc bodies (<<EOF ... EOF, quoted or not, one opener per line):
# text being written to a file is not a command being run.
strip_heredocs() {
	awk '
		inhd { if ($0 == term) inhd = 0; next }
		{
			if (match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*["'"'"']?/)) {
				term = substr($0, RSTART, RLENGTH)
				sub(/^<<-?[[:space:]]*/, "", term)
				gsub(/["'"'"']/, "", term)
				inhd = 1
			}
			print
		}'
}
code=$(printf '%s\n' "$cmd" | strip_heredocs)

# `pgrep`/`pkill`, a flag cluster containing f, then the first character of
# the pattern (after an optional opening quote).
re='p(grep|kill)[[:space:]]+((-[[:alnum:]]*f[[:alnum:]]*|--full)[[:space:]]+)+["'"'"']?([^[:space:]"'"'"'])'
loop_re='(^|[;&|[:space:](])(while|until)[[:space:]]'

rest=$code
while [[ $rest =~ $re ]]; do
	tool=${BASH_REMATCH[1]}
	first=${BASH_REMATCH[4]}
	# Advance past this match so a later pgrep/pkill is also checked.
	rest=${rest#*"${BASH_REMATCH[0]}"}
	[ "$first" = '[' ] && continue
	if [ "$tool" = kill ] || [[ $code =~ $loop_re ]]; then
		reason="Blocked: p$tool -f with a pattern that matches the shell running this command (the pattern is in its own command line), so a wait loop never exits and pkill kills the waiter. Instead: (1) do not wait — a run_in_background job re-invokes the session when it exits; (2) bracket the pattern's first character so it cannot match its own text, e.g. pgrep -f \"[m]ise run check\"; (3) in the same shell, capture \$! at launch and wait \"\$pid\"."
		jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
		exit 0
	fi
done
exit 0
