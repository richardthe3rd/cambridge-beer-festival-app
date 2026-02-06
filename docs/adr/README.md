# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) for the Cambridge Beer Festival app.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences.

ADRs help us:
- **Document why** decisions were made (not just what)
- **Preserve context** for future team members
- **Track alternatives** that were considered
- **Enable reversal** by understanding original reasoning
- **Learn from outcomes** of past decisions

## Format

Each ADR follows this structure:

- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Date**: When the decision was made
- **Context**: What forces are at play (technical, political, social, project local)
- **Decision**: What we decided to do
- **Consequences**: What becomes easier or harder as a result

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-github-actions-caching-strategy.md) | GitHub Actions Caching Strategy | Accepted | 2025-12-27 |
| [0002](0002-composite-actions-and-test-deduplication.md) | Composite Actions and Test Deduplication | Accepted | 2025-12-27 |
| [0003](0003-parallel-build-strategy.md) | Parallel Build Strategy for Android Releases | Accepted | 2025-12-27 |
| [0004](0004-path-based-url-strategy.md) | Path-Based URL Strategy for Deep Linking | Accepted | 2025-12-21 |
| [0005](0005-e2e-testing-strategy.md) | E2E Testing Strategy (Playwright for URL Smoke Tests) | Accepted | 2025-12-21 |

## Creating a New ADR

1. Copy the template (if exists) or use previous ADR as reference
2. Number sequentially: `0002-title.md`, `0003-title.md`, etc.
3. Fill in all sections, especially alternatives considered
4. Update this index with a link
5. Get team review before marking as "Accepted"

## References

- [Michael Nygard's ADR concept](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)
- [When to use ADRs](https://github.com/joelparkerhenderson/architecture-decision-record#when-to-use-adrs)
