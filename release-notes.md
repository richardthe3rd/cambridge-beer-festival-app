
## [2026.5.9] - 2026-05-31

### Bug Fixes

- Style screen title casing and google_fonts crash reporting (#295)
- **router**: Handle illegal percent encoding in style route (#300)
- **ci**: Replace report-lcov action with codecov for coverage gating (#303)
- **analytics**: Prevent Cloudflare Pages preview hosts from logging to production (#327)
- **search**: Debounce search input to avoid per-keystroke filtering (#328)
- **festivals**: Skip malformed festival entries instead of crashing (#330)
- **screens**: Return Future from async URL launch handlers (#331)
- **provider**: Make festival/error analytics non-blocking in BeerProvider (#332)
- Dispose http.Client instances owned by repositories (#334)
- **provider**: Rate-limit refreshIfStale retries after failed network calls (#336)
- Prevent `"null"` identifier collisions from malformed drink JSON (#339)
- **provider**: Refresh current festival reference on registry update (#362)
- **models**: Replace fragile substring matching with exact-match status map (#360)

### Documentation

- Add badges, Play Store link, and fix README accuracy (#297)
- Move issue tracking to GitHub, archive todos.md (#316)
- **agents**: Add implicit patterns subsection to Code Style (#325)
- **agents**: Add session startup section for toolchain pre-warming (#333)
- **my-festival**: Add product vision document (#359)

### Features

- **offline**: Cache drinks & festivals for instant stale-while-revalidate startup (#302)
- **android**: Configure App Links to open shared drink URLs in the app (#363)

### Refactoring

- Extract inline shell tasks to mise-tasks file-tasks; add shellcheck + shfmt (#299)
- **storage**: Centralize SharedPreferences keys in PreferenceKeys (#356)
- **provider**: Extract DrinkFilterController from BeerProvider (#357)


