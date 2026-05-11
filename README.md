# Cambridge Beer Festival App

[![CI](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/ci.yml/badge.svg)](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/richardthe3rd/cambridge-beer-festival-app/graph/badge.svg)](https://codecov.io/gh/richardthe3rd/cambridge-beer-festival-app)

A Flutter app for browsing beers, ciders, meads, and more at the Cambridge Beer Festival.

**Production**: [https://cambeerfestival.app](https://cambeerfestival.app)
**Staging**: [https://staging.cambeerfestival.app](https://staging.cambeerfestival.app)
**Development**: [https://richardthe3rd.github.io/cambridge-beer-festival-app/](https://richardthe3rd.github.io/cambridge-beer-festival-app/)

## Features

- 🍺 Browse all drinks from the festival (beers, ciders, perry, mead, wine)
- 🔍 Search by name, brewery, or style
- 🏷️ Filter by drink category and style
- ↕️ Sort by name, ABV, brewery, or style
- 👁️ Hide unavailable drinks (sold out or not yet available)
- ❤️ Save favorites for easy access
- ⭐ Rate drinks (1-5 stars)
- 🏭 View brewery details and all their drinks
- 📱 Works on Android, iOS, and Web

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.38.3
- Android Studio, Xcode, or VS Code with Flutter extensions
- [mise](https://mise.jdx.dev/) (recommended, and used throughout the repo)

### Installation

```bash
# Clone the repository
git clone https://github.com/richardthe3rd/cambridge-beer-festival-app.git
cd cambridge-beer-festival-app

# Discover available tasks
./bin/mise tasks ls
MISE_ENV=dev ./bin/mise tasks ls

# Install managed tools
./bin/mise install

# Run core checks
./bin/mise run test
./bin/mise run analyze

# Start the web dev server
MISE_ENV=dev ./bin/mise run dev
```

If you are not using mise, install Flutter 3.38.3 manually and run the equivalent
`flutter pub get`, `flutter test`, `flutter analyze --no-fatal-infos`, and
`flutter run -d web-server --web-port 8080` commands yourself.

### Development Tasks

The repository standard is to use `./bin/mise`:

```bash
./bin/mise run generate                # Generate mocks/build_runner output
./bin/mise run test                    # Run unit and widget tests
./bin/mise run coverage                # Generate coverage report
./bin/mise run analyze                 # Run Flutter analyzer
MISE_ENV=dev ./bin/mise run dev        # Start web dev server
MISE_ENV=dev ./bin/mise run build:web  # Build web app for local testing
MISE_ENV=dev ./bin/mise run test:e2e   # Run Playwright smoke tests
```

Use `./bin/mise run <task> --help` to inspect task arguments where supported.

Raw Flutter commands still work when needed, but are not the preferred workflow:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter test --coverage
flutter analyze --no-fatal-infos
flutter run -d web-server --web-port 8080  # Run on web
```

### Building

```bash
# Build for web (local release/testing)
MISE_ENV=dev ./bin/mise run build:web

# Build for web (production settings)
MISE_ENV=dev ./bin/mise run build:web:prod

# Serve an existing release build locally with SPA routing
MISE_ENV=dev ./bin/mise run serve:release

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── router.dart            # GoRouter configuration
├── domain/                # Domain models, repositories, and services
├── models/                # Data models (Drink, Producer, Festival)
├── providers/             # State management (BeerProvider)
├── screens/               # App screens
├── services/              # API, analytics, and storage services
├── utils/                 # Helpers for navigation, formatting, and UI
└── widgets/               # Reusable UI components

test/                      # Unit and widget tests
test-e2e/                  # Playwright tests for Flutter web
docs/                      # Project, tooling, and architecture docs
```

## Testing and Coverage

This project uses multiple testing approaches:

### Unit & Widget Tests

Flutter's built-in testing framework with comprehensive test coverage:

```bash
./bin/mise run test
./bin/mise run coverage
```

Coverage is collected in CI and uploaded to Codecov.

### E2E Testing

```bash
MISE_ENV=dev ./bin/mise run setup:playwright
MISE_ENV=dev ./bin/mise run build:web
MISE_ENV=dev ./bin/mise run serve:release
MISE_ENV=dev ./bin/mise run test:e2e
```

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
- [UX Improvements](docs/planning/ux-improvements.md) - Planned UX enhancements
- [Android Debug Build](docs/tooling/android-debug.md) - Building debug APKs
- [Play Store Metadata](docs/tooling/play-store.md) - App store listing information

## Deployment

The app is deployed to multiple environments:

- **Production** (Cloudflare Pages): [cambeerfestival.app](https://cambeerfestival.app)
  - Deployed on version tags (e.g., `v2025.12.0`)
  - Uses Cloudflare Pages project `cambeerfestival`, branch `release`
  - Workflow: `.github/workflows/release-web.yml`
- **Staging** (Cloudflare Pages): [staging.cambeerfestival.app](https://staging.cambeerfestival.app)
  - Stable staging environment
  - Deployed automatically on push to `main`
  - Uses Cloudflare Pages project `staging-cambeerfestival`, branch `main`
  - Workflow: `.github/workflows/ci.yml` (deploy-web-preview job)
- **PR Previews** (Cloudflare Pages): Unique URL per pull request
  - Each PR gets its own preview environment (e.g., `<branch>.staging-cambeerfestival.pages.dev`)
  - Preview URL posted as comment on the PR
  - Workflow: `.github/workflows/ci.yml` (deploy-web-preview job)

### Deployment Strategy

1. **Development changes**: Push to `main` → Staging (Cloudflare Pages)
2. **PR reviews**: Open PR → Unique Cloudflare Pages preview created
3. **Production releases**: Create tag (e.g., `v2025.12.0`) → Production deployment to cambeerfestival.app

For the full release process (version bumping, branching, tagging), see the [Release Guide](docs/processes/release.md).

For deployment setup and configuration, see [Cloudflare Pages Setup Guide](docs/tooling/cloudflare-pages.md).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app (Java)
