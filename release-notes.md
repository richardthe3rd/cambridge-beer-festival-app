
## [2026.9.0] - 2026-09-05

### Bug Fixes

- Correctness fixes from a codebase review (#498)
- **filters**: Scope drink facets by all filters but their own (#505)
- **mise**: Unblock check in fresh worktrees, plus domain-architecture doc refresh (#514)
- **filters**: Make sort sheet options dense like the other sheets (#516)
- **web**: Guard URL strategy import on js_interop, not html (#537)
- **drinks**: Move provider mutations out of setState (#538)
- **worker**: Unblock deploys by removing the unprovisioned D1 binding (#542)
- **worker**: Make npm run typecheck work on a fresh checkout (#549)
- **a11y**: Sort style names in the style-filter screen-reader label (#558)
- **build**: Untrack the .mise symlink committed to main (#565)
- **state**: Replace the catalogue instead of mutating it in place (#570)
- **drinks**: Observe the filtered catalogue by identity (#575)
- **drinks**: Stop the filter button losing its label when active (#581)
- **router**: Decouple router construction from static flag (#587)
- **models**: Stop one odd feed record costing a whole category (#594)
- **models**: Tell a missing ABV apart from a real 0.0% (#603)
- **theme**: Pair filled-button colours with their own on-colours (#605)
- **release**: Correct stale SDK levels in Android release notes (#613)
- **a11y**: Stop Your Take controls announcing their label twice (#616)
- **festival-info**: Badge the date-derived status, not the is_active flag (#631)
- **festival-info**: Keep a gap between day name and festival hours (#633)
- **colours**: Key category accents by the category drinks carry (#634)
- **filters**: Keep sheet headers a constant height so sheets stop jumping (#635)

### Documentation

- **copilot**: Add a Dart code-review skill to stop false compile claims (#546)
- **skills**: Update architecture-contract for the v2 storage model (#566)
- **skills**: Record the collection-selector equality invariant (#576)
- **agents**: Record background-job and worktree-base lessons (#590)
- **processes**: Add a Flutter upgrade playbook (#592)
- **skills**: Record the Flutter-web semantics dead end (#606)
- **adr**: Record the integration_test re-decision and drop the unused dep (#615)
- **adr**: Decline the BeerProvider split, with the measurement (#620)
- **skills**: Retire the stale AGENTS.md doc-drift callout (#624)

### Features

- **drinks**: Multi-select categories and grouped style filter (#506)
- **theme**: Establish a deliberate colour system (#519)
- **tooling**: Add dart_code_linter metrics report and rule gate (#567)
- **festival-info**: Make beverage type chips open that drinks list (#628)

### Performance

- **drinks**: Memoise facet scopes in DrinkFilterController (#586)

### Refactoring

- Remove dead widgets and navigation helpers (#502)
- **widgets**: Share festival status badge and sheet handle (#501)
- Clear five low-priority backlog issues (#539)
- Enforce the declared lint rules and break the main/router import cycle (#540)
- **drinks**: Narrow DrinksScreen to per-concern provider selects (#550)
- **app**: Narrow app-level provider watches to selects (#553)
- **brewery,style**: Narrow provider selects for #523 (#554)
- **drinks**: Narrow DrinkDetailScreen to per-concern provider selects (#557)
- **screens**: Narrow remaining bare provider watches (#523) (#559)
- **providers**: Inject clock for testable staleness logic (#560)
- **drinks**: Extract DrinksScreen build helpers to widgets (#561)
- **providers**: Finish provider narrowing left over from #523 (#569)
- **my-festival**: Extract build helpers to widget classes (#571)


