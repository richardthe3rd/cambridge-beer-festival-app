---
description: Spawn parallel planning agents for one or more GitHub issues
argument-hint: "<issue-number> [issue-number ...]"
---

# Plan Issues

Spawn parallel planning agents for one or more GitHub issue numbers.

Usage: `/plan-issues #270 #324` or `/plan-issues 270 324 355`

---

For each issue number provided:

1. Read the issue from GitHub: `mcp__github__issue_read` (method: `get`) for the title and body, then (method: `get_comments`) for any triage comments — `get` alone does not return comments.
2. Explore the affected files to understand the current code.
3. Produce a plan in the exact contract format below.

Spawn all planning agents **in parallel** (one per issue, `subagent_type: claude`). Use `model: haiku` for single-file mechanical fixes; `model: sonnet` for multi-file or architectural changes. Each agent receives: the issue body, relevant file excerpts, and the planning contract below.

---

## Planning Agent Contract

Every plan must output exactly these three sections — implementation agents receive them verbatim:

```
### Allowed files (HARD CONSTRAINT)
- lib/path/to/file.dart
- test/path/to/file_test.dart
# Nothing outside this list may be touched.

### Model recommendation
haiku / sonnet — one-line rationale

### Phase N — <short name>
Files: (subset of allowed list)
Changes: (exact description — line numbers where possible)
Verification: (command to run)
Done signal: (what "done" looks like)
```

## Model selection guide

See the model selection table in AGENTS.md ("Parallel Work with Subagents → Model Selection"). In short: **haiku** for single-file mechanical changes and pattern-following tests; **sonnet** for multi-file or architectural changes, nullable/sentinel patterns, and type-system work.

---

After all planning agents complete, present the plans to the user for approval before any implementation begins.
