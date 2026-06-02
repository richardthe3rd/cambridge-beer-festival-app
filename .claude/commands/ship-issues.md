# Ship Issues

Full plan → implement → review → fix → PR → watch cycle for one or more GitHub issues.

Usage: `/ship-issues #270 #324 #355`

---

## Workflow

Work through these stages in order. Pause for user approval at each ✋ gate.

### Stage 1 — Plan
Invoke `/plan-issues` for all issue numbers. Present plans. ✋ Wait for approval.

### Stage 2 — Implement
For each approved plan, spawn an implementation agent with `isolation: "worktree"`:
- Branch name: `fix/<issue-number>-<short-slug>` (created inside the worktree)
- Pass: phase steps, allowed-file manifest as a hard constraint, explicit "do not modify files outside this list"
- The agent must run `./bin/mise run check` before committing and push to its branch

Run all implementation agents **in parallel**.

After all agents complete, verify each branch:
```bash
git diff <base-commit>..<branch> --stat
```
Confirm only planned files changed. ✋ Flag any drift before continuing.

### Stage 3 — Review
Run `/fix-review` across all fix branches. Apply fixup commits for clear findings. ✋ Ask about ambiguous ones.

### Stage 4 — Push PRs
Create one PR per fix branch targeting `main`. Subscribe to all PRs with `mcp__github__subscribe_pr_activity`.

### Stage 5 — Watch
Monitor CI and review activity. For each event:
- Green CI on all checks → nothing to do
- Test/analyze failure → diagnose and push a fix commit
- Copilot review comment → triage per `/fix-review` heuristics
- Human review comment → surface to user if ambiguous, otherwise fix and push

The session ends when all PRs are green and have no unresolved review threads.

---

## Notes

- Implementation agents use `isolation: "worktree"` — this creates worktrees inside the repo at `.claude/worktrees/`, which is required for commit signing in the managed environment.
- Fix branches target `main` directly. The session branch (`claude/session-*`) is for session-level changes (AGENTS.md updates, etc.).
- Always run `./bin/mise run` commands, never raw `flutter` — see AGENTS.md for the full command reference.
