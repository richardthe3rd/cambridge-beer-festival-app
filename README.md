# Cambridge Beer Festival App

[![CI](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/ci.yml/badge.svg)](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/ci.yml)
[![PR Lint](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/pr-lint.yml/badge.svg)](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/pr-lint.yml)
[![codecov](https://codecov.io/gh/richardthe3rd/cambridge-beer-festival-app/graph/badge.svg)](https://codecov.io/gh/richardthe3rd/cambridge-beer-festival-app)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-blue)](https://flutter.dev/multi-platform)
[![GitHub release](https://img.shields.io/github/v/release/richardthe3rd/cambridge-beer-festival-app)](https://github.com/richardthe3rd/cambridge-beer-festival-app/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Play Store](https://img.shields.io/badge/Google_Play-414141?logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=ralcock.cbf)

A Flutter app for browsing, searching, and rating the beers, ciders, perries, meads, and wines on offer at the Cambridge Beer Festival — on Android, iOS, and the web.

Built for real festival conditions: the drinks list is cached so it keeps working when the venue network drops, and every screen is built with screen-reader semantics and keyboard/touch accessibility in mind.

**Production**: [cambeerfestival.app](https://cambeerfestival.app)
**Staging**: [staging.cambeerfestival.app](https://staging.cambeerfestival.app)
**Android**: [Google Play](https://play.google.com/store/apps/details?id=ralcock.cbf)
**API docs**: [richardthe3rd.github.io/cambridge-beer-festival-app](https://richardthe3rd.github.io/cambridge-beer-festival-app/)

## Features

- 🍺 Browse all drinks from the festival (beer, cider, perry, mead, wine, and more)
- 🔍 Search by name, brewery, or style
- 🏷️ Filter by drink category and style
- ↕️ Sort by name, ABV, brewery, or style
- 👁️ Hide unavailable drinks (sold out or not yet available)
- 📋 Build your **My Festival** list — mark drinks "Want to try", then "Tasted"
- ⭐ Rate drinks (1–5 stars) and jot personal tasting notes
- 🏭 View brewery details and all their drinks
- ♿ Accessibility-first: screen-reader semantics on every interactive element
- 📶 Cached data keeps browsing usable when the festival network is patchy
- 📱 Works on Android, iOS, and Web

## Screenshots

<!--
  TODO: add screenshots. Drop images under docs/assets/ (e.g. drinks-list.png,
  drink-detail.png, my-festival.png) and reference them here, for example:

  | Drinks list | Drink detail | My Festival |
  |---|---|---|
  | ![Drinks list](docs/assets/drinks-list.png) | ![Drink detail](docs/assets/drink-detail.png) | ![My Festival](docs/assets/my-festival.png) |
-->

_Screenshots coming soon — try the live app at [cambeerfestival.app](https://cambeerfestival.app)._

## Getting Started

### Prerequisites

- **Flutter SDK 3.44.0** — pinned and installed for you by `./bin/mise` (the repo ships this wrapper, so a global [mise](https://mise.jdx.dev/) install is optional)
- Android Studio, Xcode, or VS Code with Flutter extensions

### Installation

```bash
# Clone the repository
git clone https://github.com/richardthe3rd/cambridge-beer-festival-app.git
cd cambridge-beer-festival-app

# Install tools (Flutter 3.44.0, Node, etc.) — ./bin/mise self-bootstraps,
# so you don't need mise installed globally
./bin/mise install

# Install Dart dependencies and verify setup
./bin/mise run check

# Run the app on web
MISE_ENV=dev ./bin/mise run dev
```

### Development Tasks

```bash
./bin/mise run test             # Run all tests
./bin/mise run coverage         # Run tests with coverage report
./bin/mise run analyze          # Analyze code for issues
./bin/mise run check            # Full pre-commit gate (generate → analyze → test)
MISE_ENV=dev ./bin/mise run dev # Run app on web (localhost:8080)
```

### Building

```bash
# Build for web
MISE_ENV=dev ./bin/mise run build:web:prod

# Build for Android
./bin/mise exec flutter -- flutter build apk

# Build for iOS
./bin/mise exec flutter -- flutter build ios
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models (Drink, Producer, Festival)
├── providers/             # State management (BeerProvider)
├── screens/               # UI screens
│   ├── drinks_screen.dart      # Main drinks list
│   ├── drink_detail_screen.dart # Drink details
│   └── brewery_screen.dart      # Brewery page with drinks
├── services/              # API and storage services
└── widgets/               # Reusable UI components
```

## Testing and Coverage

This project uses multiple testing approaches:

### Unit & Widget Tests

Flutter's built-in testing framework with comprehensive test coverage:

```bash
./bin/mise run test      # Run all tests
./bin/mise run coverage  # Run tests with coverage report
```

Coverage is collected in CI and reported in two places:

- **PR comments and job summaries** — file-by-file breakdown via `github-actions-report-lcov`
- **Codecov** — trend tracking and the badge above

Coverage fails CI if it drops below 70%.

### E2E Testing

- **Web E2E Tests**: Playwright tests for URL routing and accessibility smoke tests - [Testing Flutter Web Guide](docs/tooling/flutter-web-testing.md)

See [ADR 0005](docs/adr/0005-e2e-testing-strategy.md) for the rationale behind this approach.

## Data API

This app uses the Cambridge Beer Festival data API via a Cloudflare Worker proxy:
- Base URL: `https://data.cambeerfestival.app`
- Example: `https://data.cambeerfestival.app/cbf2025/beer.json`

### Documentation

API documentation and JSON schemas are available in the [docs/code/api](docs/code/api/) directory:

- [API Overview](docs/code/api/README.md) - Quick reference and schema usage
- [Data API Reference](docs/code/api/data-api-reference.md) - Complete API documentation
- [Beer List Schema](docs/code/api/beer-list-schema.json) - JSON Schema for beverage data
- [Festival Registry Schema](docs/code/api/festival-registry-schema.json) - JSON Schema for festival configuration

## Architecture & Documentation

Technical documentation is available in the [docs](docs/) directory - see [docs/README.md](docs/README.md) for a complete overview.

### Development & Setup
- [Development Guide](docs/processes/development.md) - Complete development setup and workflows
- [Release Guide](docs/processes/release.md) - Version bumping, branching, and tagging for releases
- [Firebase Setup](docs/tooling/firebase.md) - Firebase integration for Crashlytics and Analytics
- [GitHub Secrets](docs/tooling/github-secrets.md) - Required secrets for CI/CD

### Testing & Quality
- [Testing Flutter Web](docs/tooling/flutter-web-testing.md) - E2E testing with Playwright

### Architecture & Deployment
- [URL Routing](docs/code/routing.md) - Path-based routing implementation
- [Cloudflare Pages Setup](docs/tooling/cloudflare-pages.md) - Deployment configuration
- [CI/CD](docs/processes/ci-cd.md) - Complete CI/CD workflow documentation
- [Accessibility](docs/code/accessibility.md) - Accessibility features and guidelines

### Additional Resources
- [Android Debug Build](docs/tooling/android-debug.md) - Building debug APKs
- [Play Store Metadata](docs/tooling/play-store.md) - App store listing information

## Deployment

| Trigger | Lands on |
|---|---|
| Push to `main` | Staging — [staging.cambeerfestival.app](https://staging.cambeerfestival.app) |
| Open a pull request | A unique per-PR preview (`<branch>.staging-cambeerfestival.pages.dev`), posted as a comment on the PR |
| Push a version tag (e.g. `v2025.12.0`) | Production — [cambeerfestival.app](https://cambeerfestival.app) |

The app is hosted on Cloudflare Pages, with the API served by a Cloudflare Worker. For the full detail — every workflow, the Pages projects, and the release train:

- [CI/CD](docs/processes/ci-cd.md) — each workflow and deploy job
- [Cloudflare Pages Setup](docs/tooling/cloudflare-pages.md) — deployment configuration
- [Release Guide](docs/processes/release.md) — version bumping, branching, and tagging

## Contributing

Contributions are welcome! Before opening a pull request, please read:

- [Development Guide](docs/processes/development.md) — setup, workflows, and conventions
- [AGENTS.md](AGENTS.md) — architecture, code style, testing, and accessibility standards (written for AI agents, but the rules apply to everyone)

Run `./bin/mise run check` (generate → analyze → test) before every commit, and follow [Conventional Commits](https://www.conventionalcommits.org/) for commit and PR titles.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app (Java)