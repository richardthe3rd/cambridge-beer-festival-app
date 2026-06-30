---
description: Triage review comments on PRs and spawn fixup agents for actionable findings
argument-hint: "[branch ...] (omit to triage all watched PRs)"
---

# Address Review Findings

Triage review comments on one or more PRs and spawn fixup agents for actionable findings.

Usage: `/address-review fix/270-partial-fetch-failures fix/324-connectivity-failure-detection`
Or just: `/address-review` to triage all open PRs being watched in this session.

---

## Steps

For each branch / PR:

1. Fetch review threads via `mcp__github__pull_request_read` (method: `get_review_comments`). Each thread carries `isResolved` / `isOutdated` flags — skip threads already resolved or outdated; they need no action.
2. Check current CI status via `mcp__github__pull_request_read` (method: `get_check_runs`) before evaluating any comment.
3. Triage each comment:
   - **Fix** — correct finding, confined to the PR's allowed files, clear how to resolve
   - **Skip** — contradicted by passing CI, factually wrong, out of scope, or pure style preference
   - **Ask** — ambiguous interpretation or architecturally significant change
4. Spawn one haiku agent per **Fix** item (or group related fixes on the same branch into one agent) with `isolation: "worktree"`.
5. Surface **Ask** items to the user with enough context to answer without scrolling.
6. Do not post GitHub replies to skip items unless the comment is factually wrong in a way that could mislead other reviewers.

## Triage principles

The shared triage facts live in AGENTS.md — consult them before evaluating any comment:
- **CI and Coverage** — CI is ground truth; coverage warnings are informational unless `codecov/patch` itself fails; pure refactors inherit prior coverage.
- **Dart / Flutter Type Facts** and **Proto / AIP Design Facts** — verify subtype/annotation claims; internal conditional-import stubs don't belong in barrel exports.

Automated reviewers are frequently wrong about type hierarchies and "won't compile" claims when CI is green. When in doubt, trust the analyzer over the comment.

## Fixup agent constraints

Each agent must:
- Work only on files within the branch's original allowed-file manifest
- Run `./bin/mise run check` before committing
- Use conventional commit format: `fix(<scope>): <subject>`
- Push to the existing fix branch (not a new branch)
