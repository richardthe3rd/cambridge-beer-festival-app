# Documentation

Organized documentation for the Cambridge Beer Festival app.

## 📁 Structure

The documentation is organized into four main categories:

### 📘 code/ - Current Code Documentation

Documentation of how the current codebase works - implementation guides, architecture decisions, and technical references.

- **[accessibility.md](code/accessibility.md)** - Accessibility implementation guide (WCAG 2.1 Level AA compliance)
- **[routing.md](code/routing.md)** - URL routing strategy (path-based routing with go_router)
- **[network.md](code/network.md)** - Network security configuration and allowlist
- **[api/](code/api/)** - API documentation
  - [README.md](code/api/README.md) - API overview
  - [data-api-reference.md](code/api/data-api-reference.md) - Complete API reference
  - [beer-list-schema.json](code/api/beer-list-schema.json) - JSON Schema for beverage data
  - [festival-registry-schema.json](code/api/festival-registry-schema.json) - JSON Schema for festival config

### 🔄 processes/ - Development & Operational Processes

Documented processes for development workflows, CI/CD, and handling contributions.

- **[development.md](processes/development.md)** - Development workflow and best practices
- **[ci-cd.md](processes/ci-cd.md)** - Continuous integration and deployment processes
- **[festival-data-prs.md](processes/festival-data-prs.md)** - FAQ for handling festival data pull requests

### 🛠️ tooling/ - Setup & Configuration Guides

Step-by-step guides for setting up and configuring development tools, build systems, and deployment platforms.

- **[android-debug.md](tooling/android-debug.md)** - Android debug build configuration
- **[android-release.md](tooling/android-release.md)** - Android release build process
- **[firebase.md](tooling/firebase.md)** - Firebase setup and configuration
- **[cloudflare-pages.md](tooling/cloudflare-pages.md)** - Cloudflare Pages deployment setup
- **[github-secrets.md](tooling/github-secrets.md)** - GitHub secrets management
- **[flutter-web-testing.md](tooling/flutter-web-testing.md)** - Flutter web testing setup (Playwright E2E)
- **[play-store.md](tooling/play-store.md)** - Play Store metadata and publishing

### 📋 planning/ - Design Docs, Proposals & Reviews

Planning documents, architecture decision records, design reviews, and future enhancement proposals. **These are historical records or proposals, not current implementation.**

#### Deep Linking Implementation

Complete planning documentation for the deep linking feature (implemented):

- **[deep-linking/design.md](planning/deep-linking/design.md)** - Initial design proposal
- **[deep-linking/design-review.md](planning/deep-linking/design-review.md)** - Design review and feedback
- **[deep-linking/implementation-plan.md](planning/deep-linking/implementation-plan.md)** - Step-by-step implementation plan
- **[deep-linking/testing-strategy.md](planning/deep-linking/testing-strategy.md)** - Testing approach and E2E test plan
- **[deep-linking/architecture-readonly-urls.md](planning/deep-linking/architecture-readonly-urls.md)** - ADR for path-based URLs

**Status**: ✅ Implemented - See [code/routing.md](code/routing.md) for current implementation

#### Patrol Firebase Testing

Exploration of Patrol testing framework with Firebase Test Lab (not implemented):

- **[patrol-firebase-testing/plan.md](planning/patrol-firebase-testing/plan.md)** - Testing plan proposal
- **[patrol-firebase-testing/review.md](planning/patrol-firebase-testing/review.md)** - Review and evaluation
- **[patrol-firebase-testing/summary.md](planning/patrol-firebase-testing/summary.md)** - Summary and decision

**Status**: ❌ Not Implemented - Decided against Patrol, using Playwright for E2E testing instead

**Alternative**: See [tooling/flutter-web-testing.md](tooling/flutter-web-testing.md) for current Playwright-based E2E testing approach

#### Other Planning Documents

- **[readme-review.md](planning/readme-review.md)** - Review and improvement proposals for README
- **[ux-improvements.md](planning/ux-improvements.md)** - Comprehensive UX enhancement proposals
  - **Status**: Partially implemented (8 of 30 features completed as of Dec 2025)
  - **Recommendations**: Phase 1-3 high-value features (~33 hours), remaining 22 features not recommended
  - See document for implementation status and value assessment

## 🔍 Quick Reference

### I want to...

**Understand the codebase:**
- How accessibility works → [code/accessibility.md](code/accessibility.md)
- How routing works → [code/routing.md](code/routing.md)
- How the API works → [code/api/data-api-reference.md](code/api/data-api-reference.md)

**Set up development tools:**
- Set up Android builds → [tooling/android-debug.md](tooling/android-debug.md) or [tooling/android-release.md](tooling/android-release.md)
- Set up Firebase → [tooling/firebase.md](tooling/firebase.md)
- Set up E2E testing → [tooling/flutter-web-testing.md](tooling/flutter-web-testing.md)
- Deploy to Cloudflare → [tooling/cloudflare-pages.md](tooling/cloudflare-pages.md)

**Follow a process:**
- Contribute code → [processes/development.md](processes/development.md)
- Understand CI/CD → [processes/ci-cd.md](processes/ci-cd.md)
- Handle festival data PRs → [processes/festival-data-prs.md](processes/festival-data-prs.md)

**Review a design decision:**
- Why path-based URLs? → [planning/deep-linking/architecture-readonly-urls.md](planning/deep-linking/architecture-readonly-urls.md)
- Why not Patrol testing? → [planning/patrol-firebase-testing/summary.md](planning/patrol-firebase-testing/summary.md)

**Plan future work:**
- UX improvements → [planning/ux-improvements.md](planning/ux-improvements.md) (prioritized recommendations)

## 📝 Documentation Status

### Current Implementation Docs (✅ Up to Date)

These docs reflect the current state of the codebase:

- [code/accessibility.md](code/accessibility.md)
- [code/routing.md](code/routing.md)
- [code/network.md](code/network.md)
- [code/api/](code/api/)

### Process Docs (✅ Up to Date)

These docs describe active processes:

- [processes/development.md](processes/development.md)
- [processes/ci-cd.md](processes/ci-cd.md)
- [processes/festival-data-prs.md](processes/festival-data-prs.md)

### Tooling Docs (✅ Up to Date)

These guides are current and accurate:

- All docs in [tooling/](tooling/)

### Planning Docs (⚠️ Historical/Proposals)

These docs are **not current implementation** - they are historical records or future proposals:

- ✅ **Implemented**: [planning/deep-linking/](planning/deep-linking/) - See [code/routing.md](code/routing.md) for current implementation
- ❌ **Not Implemented**: [planning/patrol-firebase-testing/](planning/patrol-firebase-testing/) - See [tooling/flutter-web-testing.md](tooling/flutter-web-testing.md) for alternative
- ⏳ **Partially Implemented**: [planning/ux-improvements.md](planning/ux-improvements.md) - 8 of 30 features completed, document includes implementation status and prioritized recommendations

## 🔄 Alternatives & Conflicting Approaches

### Testing Strategy

**Conflicting Plans**:

1. **Patrol + Firebase Test Lab** ([planning/patrol-firebase-testing/](planning/patrol-firebase-testing/)) - ❌ Not Implemented
   - Pros: Native Flutter testing, realistic device conditions
   - Cons: Complex setup, Firebase Test Lab costs, limited to mobile platforms

2. **Playwright E2E** ([tooling/flutter-web-testing.md](tooling/flutter-web-testing.md)) - ✅ Currently Used
   - Pros: Simple setup, free, works for web platform, familiar to web developers
   - Cons: Web-only, doesn't test native mobile features
   - **Decision**: Chosen for simplicity and web-first approach

**Recommendation**: Continue with Playwright for web E2E. Consider Patrol only if extensive native mobile testing becomes necessary.

### URL Routing Approaches

**Considered Approaches** (documented in [planning/deep-linking/architecture-readonly-urls.md](planning/deep-linking/architecture-readonly-urls.md)):

1. **Hash-based URLs** (`/#/drink/123`) - ❌ Rejected
   - Simple, no server config needed
   - Poor SEO, unprofessional appearance

2. **Path-based URLs** (`/drink/123`) - ✅ Implemented
   - Better SEO, clean URLs, shareable links
   - Requires server-side routing config (SPA fallback)
   - **Decision**: Chosen for better UX and SEO

**Current Implementation**: See [code/routing.md](code/routing.md)

### UX Enhancement Priorities

**Multiple Phases Proposed** (documented in [planning/ux-improvements.md](planning/ux-improvements.md)):

The original document proposed 30 UX improvements across 4 phases. After implementation review and value assessment:

- ✅ **Phase 1 (Implemented)**: 8 features - Similar drinks, visual variety, filtering, search, favorites, ratings, themes
- 🟢 **Phase 1 Recommended**: 4 features (14 hours) - Bar location, allergen warnings, result count, ABV filters
- 🟢 **Phase 2 Recommended**: 1 feature (12 hours) - "Tried" vs "Want to Try" tracking
- 🟡 **Phase 3 Optional**: 2 features (7 hours) - Filter count badge, clear all filters
- 🔴 **Not Recommended**: 22 features (~236 hours) - Comparison mode, A-Z navigation, social features, etc.

**Decision**: Focus on Phases 1-3 only (33 hours total). Remaining features don't align with festival app needs or have poor effort/value ratios.

**Conflicting Approaches**:
- Original plan: Implement all 30 features (~269 hours)
- Current recommendation: Implement 7 high-value features (33 hours), focus remaining effort on data quality and stability

See [planning/ux-improvements.md](planning/ux-improvements.md) for detailed implementation status and value assessment.

## 🤝 Contributing to Docs

When adding or updating documentation:

1. **Choose the right category:**
   - Documenting existing code? → `code/`
   - Describing a process? → `processes/`
   - Writing a setup guide? → `tooling/`
   - Proposing future work? → `planning/`

2. **Use clear, descriptive filenames** (lowercase, kebab-case)

3. **Update this README** if you add new documents

4. **Mark planning docs with status:**
   - ✅ Implemented (link to current implementation doc)
   - ❌ Not Implemented (explain why, link to alternative if applicable)
   - ⏳ Partially Implemented (describe current status)
   - 🚧 In Progress
   - 💡 Proposal

5. **Document alternatives** when multiple approaches exist (add to "Alternatives & Conflicting Approaches" section)

## 📚 Related Documentation

- **[../CLAUDE.md](../CLAUDE.md)** - Instructions for Claude AI (references these docs)
- **[../AGENTS.md](../AGENTS.md)** - Complete guide for AI agents using this repository
- **[../README.md](../README.md)** - Project overview and quick start guide

---

**Last Updated**: December 2025
**Maintainers**: Development Team
