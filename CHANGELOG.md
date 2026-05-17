
## [2026.5.6] - 2026-05-17

### Bug Fixes

- **sharing**: Extract producers array from wrapped API response in fetchDrinkData (#286)



## [2026.5.5] - 2026-05-17

### Bug Fixes

- Remove stale 180s timeout note from task table
- Address Copilot review comments on PR #259
- **release**: Address Copilot review comments on PR #260
- **release**: Release.yml owns GitHub Release; android uploads assets
- **release**: Address second round of Copilot review comments
- **release**: Address reviewer comments on automated release PR
- **release**: Address second-round Copilot review comments
- **release**: Fail loudly if release notes extraction produces empty output
- **release**: Fix broken deploy chain caused by GITHUB_TOKEN cascade limitation
- **release**: Address final Copilot review comments
- **release**: Remove labels from create-pull-request — label did not exist
- **provider**: Discard stale drinks responses on rapid festival switch (#263)
- **mise**: Add bash shebang to analyze and test task scripts (#274)
- **routing**: Deep links and browser refresh load wrong festival data (#275)
- **release**: Remove GITHUB_REPO from git-cliff action env (#276)
- **ci**: Don't trigger Android build on functions-only changes (#282)

### Documentation

- **agents**: Document conventional commits requirement for PR titles
- **agents**: Clarify that CI rejects non-conforming PR titles
- Fix factual errors and outdated references in AGENTS.md and CLAUDE.md
- Trim copilot-instructions.md — remove content covered by AGENTS.md
- Replace duplicated AGENTS.md content in CLAUDE.md with @AGENTS.md import
- Move all agent-useful content into AGENTS.md, CLAUDE.md becomes @AGENTS.md
- Restructure AGENTS.md — project context first, remove redundancy
- Fix three issues in AGENTS.md
- Demote TEST_LOG to a footnote, not the primary example
- **release**: Update release process to reflect workflow_dispatch deploy trigger

### Features

- **mise**: Add check, goldens:update tasks; add timeout to test task
- **mise**: Capture test/analyze output via mktemp + tee pattern
- **release**: Automate release via PR model
- **release**: Add workflow_dispatch to release-pr.yml for manual testing
- **sharing**: Include deep link URL in drink share message (#279)
- **sharing**: Add Cloudflare Pages Function for drink OG previews (#280)



## [2026.5.5] - 2026-05-17

### Bug Fixes

- Remove stale 180s timeout note from task table
- Address Copilot review comments on PR #259
- **release**: Address Copilot review comments on PR #260
- **release**: Release.yml owns GitHub Release; android uploads assets
- **release**: Address second round of Copilot review comments
- **release**: Address reviewer comments on automated release PR
- **release**: Address second-round Copilot review comments
- **release**: Fail loudly if release notes extraction produces empty output
- **release**: Fix broken deploy chain caused by GITHUB_TOKEN cascade limitation
- **release**: Address final Copilot review comments
- **release**: Remove labels from create-pull-request — label did not exist
- **provider**: Discard stale drinks responses on rapid festival switch (#263)
- **mise**: Add bash shebang to analyze and test task scripts (#274)
- **routing**: Deep links and browser refresh load wrong festival data (#275)
- **release**: Remove GITHUB_REPO from git-cliff action env (#276)
- **ci**: Don't trigger Android build on functions-only changes (#282)

### Documentation

- **agents**: Document conventional commits requirement for PR titles
- **agents**: Clarify that CI rejects non-conforming PR titles
- Fix factual errors and outdated references in AGENTS.md and CLAUDE.md
- Trim copilot-instructions.md — remove content covered by AGENTS.md
- Replace duplicated AGENTS.md content in CLAUDE.md with @AGENTS.md import
- Move all agent-useful content into AGENTS.md, CLAUDE.md becomes @AGENTS.md
- Restructure AGENTS.md — project context first, remove redundancy
- Fix three issues in AGENTS.md
- Demote TEST_LOG to a footnote, not the primary example
- **release**: Update release process to reflect workflow_dispatch deploy trigger

### Features

- **mise**: Add check, goldens:update tasks; add timeout to test task
- **mise**: Capture test/analyze output via mktemp + tee pattern
- **release**: Automate release via PR model
- **release**: Add workflow_dispatch to release-pr.yml for manual testing
- **sharing**: Include deep link URL in drink share message (#279)
- **sharing**: Add Cloudflare Pages Function for drink OG previews (#280)


