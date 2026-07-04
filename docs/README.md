# Documentation

Organized documentation for the Cambridge Beer Festival app.

## 📁 Structure

### 📘 code/ - Current Code Documentation

How the codebase works -- implementation guides, architecture, and technical references.

- **[accessibility.md](code/accessibility.md)** - Accessibility implementation (WCAG 2.1 Level AA)
- **[domain-architecture.md](code/domain-architecture.md)** - Domain layer architecture (filter/sort services, repositories)
- **[routing.md](code/routing.md)** - URL routing (path-based with GoRouter)
- **[navigation.md](code/navigation.md)** - Navigation helper API reference
- **[widget-standards.md](code/widget-standards.md)** - Widget patterns and standards
- **[ui-components.md](code/ui-components.md)** - Shared UI components (OverflowMenu, BreadcrumbBar)
- **[network.md](code/network.md)** - Network security configuration and allowlist
- **[api/](code/api/)** - API documentation
  - [README.md](code/api/README.md) - API overview
  - [data-api-reference.md](code/api/data-api-reference.md) - Complete API reference
  - [beer-list-schema.json](code/api/beer-list-schema.json) - JSON Schema for beverage data
  - [festival-registry-schema.json](code/api/festival-registry-schema.json) - JSON Schema for festival config

### 📐 adr/ - Architecture Decision Records

Key decisions with context, alternatives considered, and consequences.

- **[0001](adr/0001-github-actions-caching-strategy.md)** - GitHub Actions Caching Strategy
- **[0002](adr/0002-composite-actions-and-test-deduplication.md)** - Composite Actions and Test Deduplication
- **[0003](adr/0003-parallel-build-strategy.md)** - Parallel Build Strategy for Android Releases
- **[0004](adr/0004-path-based-url-strategy.md)** - Path-Based URL Strategy for Deep Linking
- **[0005](adr/0005-e2e-testing-strategy.md)** - E2E Testing Strategy (Playwright for URL smoke tests)
- **[0006](adr/0006-check-in-as-primary-my-festival-entity.md)** - The Check-in as the Primary My Festival Entity (Proposed)

### 🔄 processes/ - Development & Operational Processes

- **[development.md](processes/development.md)** - Development workflow and best practices
- **[ci-cd.md](processes/ci-cd.md)** - CI/CD workflows and pipeline
- **[festival-data-prs.md](processes/festival-data-prs.md)** - FAQ for handling festival data pull requests
- **[safe-cache-strategy.md](processes/safe-cache-strategy.md)** - What to cache (and avoid) in GitHub Actions

### 🛠️ tooling/ - Setup & Configuration Guides

- **[android-debug.md](tooling/android-debug.md)** - Android debug build configuration
- **[android-release.md](tooling/android-release.md)** - Android release build process
- **[firebase.md](tooling/firebase.md)** - Firebase setup and configuration
- **[cloudflare-pages.md](tooling/cloudflare-pages.md)** - Cloudflare Pages deployment setup
- **[github-secrets.md](tooling/github-secrets.md)** - GitHub secrets management
- **[flutter-web-testing.md](tooling/flutter-web-testing.md)** - Flutter web testing (Playwright E2E)
- **[play-store.md](tooling/play-store.md)** - Play Store metadata and publishing

### 📋 planning/ - Active Proposals

- **[my-festival/](planning/my-festival/)** - "My Festival" personal companion feature (product vision; implementation tracked in GitHub issues)
- **[rating-service/](planning/rating-service/)** - Community ratings backend design (Cloudflare Worker + D1)

### 🗄️ planning/archive/ - Historical Records

Completed or superseded planning documents retained for context:

- **[archive/deep-linking/](planning/archive/deep-linking/)** - Deep linking design, implementation plans, and reviews (Phase 1 complete, decisions captured in ADR 0004)
- **[archive/patrol-firebase-testing/](planning/archive/patrol-firebase-testing/)** - Patrol + Firebase Test Lab evaluation (not implemented, decision captured in ADR 0005)
- **[archive/ci-review/](planning/archive/ci-review/)** - CI/CD review and optimisations (implemented, decisions captured in ADRs 0001-0003)

### 📋 Project Tracking

Bugs, features, and tasks are tracked in [GitHub Issues](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues). The legacy **[todos.md](todos.md)** is archived and kept for historical reference only.

## 🔍 Quick Reference

### I want to...

**Understand the codebase:**
- How accessibility works → [code/accessibility.md](code/accessibility.md)
- How routing works → [code/routing.md](code/routing.md)
- How the API works → [code/api/data-api-reference.md](code/api/data-api-reference.md)
- Navigation helpers → [code/navigation.md](code/navigation.md)
- Shared UI components → [code/ui-components.md](code/ui-components.md)

**Understand a past decision:**
- Why is a check-in (incl. non-drink) the primary My Festival entity? → [ADR 0006](adr/0006-check-in-as-primary-my-festival-entity.md) (Proposed)
- Why path-based URLs? → [ADR 0004](adr/0004-path-based-url-strategy.md)
- Why Playwright for E2E? → [ADR 0005](adr/0005-e2e-testing-strategy.md)
- Why cache pub/npm but not build artifacts? → [ADR 0001](adr/0001-github-actions-caching-strategy.md)

**Set up development tools:**
- Android builds → [tooling/android-debug.md](tooling/android-debug.md) or [tooling/android-release.md](tooling/android-release.md)
- Firebase → [tooling/firebase.md](tooling/firebase.md)
- E2E testing → [tooling/flutter-web-testing.md](tooling/flutter-web-testing.md)
- Cloudflare deployment → [tooling/cloudflare-pages.md](tooling/cloudflare-pages.md)

**Follow a process:**
- Contribute code → [processes/development.md](processes/development.md)
- Understand CI/CD → [processes/ci-cd.md](processes/ci-cd.md)
- Handle festival data PRs → [processes/festival-data-prs.md](processes/festival-data-prs.md)

**Plan future work:**
- "My Festival" feature → [planning/my-festival/vision.md](planning/my-festival/vision.md)
- Community ratings backend → [planning/rating-service/design.md](planning/rating-service/design.md)
- Bugs and TODOs → [GitHub Issues](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues)

## 🤝 Contributing to Docs

1. **Choose the right category:**
   - Documenting existing code? → `code/`
   - Recording a decision? → `adr/` (use next sequential number)
   - Describing a process? → `processes/`
   - Writing a setup guide? → `tooling/`
   - Proposing future work? → `planning/`

2. **Use clear, descriptive filenames** (lowercase, kebab-case)

3. **Update this README** when adding new documents

4. **Completed planning docs** should be archived to `planning/archive/` with decisions extracted into ADRs

## 📚 Related Documentation

- **[../CLAUDE.md](../CLAUDE.md)** - Instructions for Claude AI
- **[../AGENTS.md](../AGENTS.md)** - Guide for AI agents
- **[../README.md](../README.md)** - Project overview

---

**Last Updated**: July 2026
