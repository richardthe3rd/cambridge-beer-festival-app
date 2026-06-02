# Plan Issues

Spawn parallel planning agents for one or more GitHub issue numbers.

Usage: `/plan-issues #270 #324` or `/plan-issues 270 324 355`

---

For each issue number provided:

1. Read the issue from GitHub (`mcp__github__issue_read`) to get the title, body, and any triage comments.
2. Explore the affected files to understand the current code.
3. Produce a plan in the exact contract format below.

Spawn all planning agents **in parallel** (one per issue). Each agent should be `subagent_type: Explore` or `claude` depending on complexity. Use `model: haiku` for single-file mechanical fixes; `model: sonnet` for multi-file or architectural changes.

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

| Use haiku for | Use sonnet for |
|---|---|
| Single-file mechanical changes | Multi-file architectural changes |
| Tests following an established pattern | Nullable/sentinel patterns, type system changes |
| ≤2 files with a grep-based done signal | Cascading updates across 6+ files |

---

After all planning agents complete, present the plans to the user for approval before any implementation begins.
