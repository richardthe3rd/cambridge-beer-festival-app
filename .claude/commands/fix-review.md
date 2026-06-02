# Fix Review Findings

Triage Copilot/human review comments on one or more branches and spawn fixup agents for actionable findings.

Usage: `/fix-review fix/270-partial-fetch-failures fix/324-connectivity-failure-detection`
Or just: `/fix-review` to triage all open PRs being watched in this session.

---

## Steps

For each branch / PR:

1. Fetch review comments via `mcp__github__pull_request_read` (method: `get_review_comments`).
2. Triage each comment as one of:
   - **Fix** — clear, correct, confined to the PR's allowed files
   - **Skip** — wrong (verify against CI / Dart docs / code), out of scope, or style-only
   - **Ask** — ambiguous or architecturally significant
3. For each **Fix** item, spawn a haiku agent with `isolation: "worktree"` to apply the change, run `./bin/mise run check`, commit, and push.
4. For each **Ask** item, surface it to the user with enough context to answer without scrolling.
5. Skip items silently — do not post GitHub replies unless you need to correct a factually wrong review comment that could mislead other reviewers.

## Triage heuristics

- If CI passes (test + analyze green), `const` constructor concerns from Copilot are likely wrong — `dart:io` exceptions have `const` constructors.
- Conditional import stubs (`connectivity_io.dart` / `connectivity_web.dart`) should NOT be added to barrel exports — skip those suggestions.
- Coverage warnings from Codecov are informational unless the `codecov/patch` check itself fails.
- `CertificateException extends TlsException` in `dart:io` — Copilot sometimes gets this wrong.

## Fixup agent constraints

Each agent must:
- Work only on files within the branch's original allowed-file manifest
- Run `./bin/mise run check` before committing
- Use conventional commit format: `fix(<scope>): <subject>`
- Push to the existing fix branch (not a new branch)
