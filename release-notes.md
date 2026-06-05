
## [2026.6.0] - 2026-06-05

### Bug Fixes

- **screens**: Show festival name instead of ID in drink detail app bar (#365)
- **models**: Make Drink user-state fields immutable with copyWith (#366)
- **analytics**: Filter connectivity failures from partial-fetch log (#375)
- **connectivity**: Replace runtimeType string-matching with conditional imports (#376)
- **provider**: Don't update lastDrinksRefresh when festival has no types (#382)
- **models**: Add == and hashCode to Drink, Product, and Producer (#380)

### Documentation

- **agents**: Add parallel subagent/worktree workflow rules (#368)
- **agents**: Clarify worktree PRs target main, not the session branch (#374)

### Features

- **claude**: Add ship-issues workflow commands and tighten agent docs (#378)
- **models**: Introduce BeverageCategories constants, replace magic strings (#381)

### Refactoring

- **models**: Add Drink-level accessors to remove feature envy in screens (#367)
- **screens**: Extract DetailHeader widget, deduplicate sort label logic (#377)


