# Address Review Findings

Triage review comments on one or more PRs and spawn fixup agents for actionable findings.

Usage: `/address-review fix/270-partial-fetch-failures fix/324-connectivity-failure-detection`
Or just: `/address-review` to triage all open PRs being watched in this session.

---

## Steps

For each branch / PR:

1. Fetch review comments via `mcp__github__pull_request_read` (method: `get_review_comments`).
2. Check current CI status (`get_check_runs`) before evaluating any comment.
3. Triage each comment:
   - **Fix** — correct finding, confined to the PR's allowed files, clear how to resolve
   - **Skip** — contradicted by passing CI, factually wrong, out of scope, or pure style preference
   - **Ask** — ambiguous interpretation or architecturally significant change
4. Spawn one haiku agent per **Fix** item (or group related fixes on the same branch into one agent) with `isolation: "worktree"`.
5. Surface **Ask** items to the user with enough context to answer without scrolling.
6. Do not post GitHub replies to skip items unless the comment is factually wrong in a way that could mislead other reviewers.

## Triage principles

- **CI is ground truth.** If tests and analyzer pass, a "this won't compile" comment is wrong — skip it.
- **Verify type hierarchy claims.** Automated reviewers sometimes get subtype relationships wrong; check the language/SDK docs before acting.
- **Internal implementation files don't need barrel exports.** Files only meant to be imported via conditional imports or as private implementation details should not be added to public barrels.
- **Coverage warnings are informational** unless the `codecov/patch` check itself fails (not just the comment).
- **Pure refactors inherit prior coverage.** Moved code that was untested before is not a new gap.

## Fixup agent constraints

Each agent must:
- Work only on files within the branch's original allowed-file manifest
- Run `./bin/mise run check` before committing
- Use conventional commit format: `fix(<scope>): <subject>`
- Push to the existing fix branch (not a new branch)
