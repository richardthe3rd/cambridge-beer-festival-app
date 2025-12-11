# Cambridge Beer Festival App

[![Build and Deploy](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/build-deploy.yml/badge.svg)](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/build-deploy.yml)
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
- 📋 Select and copy text from anywhere in the app
- 📱 Works on Android, iOS, and Web

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.38.3 or later)
- Android Studio, Xcode, or VS Code with Flutter extensions
- (Optional) [mise](https://mise.jdx.dev/) for automatic tool version management

### Installation

```bash
# Clone the repository
git clone https://github.com/richardthe3rd/cambridge-beer-festival-app.git
cd cambridge-beer-festival-app

# Option 1: Using mise (recommended)
mise install  # Automatically installs Flutter 3.38.3, Node 21, and other tools
flutter pub get

# Option 2: Manual setup
flutter pub get

# Run the app
flutter run
```

### Development Tasks

If using mise, you can run these convenient tasks:

```bash
mise run test      # Run all tests
mise run coverage  # Generate code coverage report
mise run analyze   # Analyze code for issues
mise run dev       # Run app on web (localhost:8080)
```

Or run them directly:

```bash
flutter test                    # Run tests
flutter test --coverage         # Run tests with coverage
flutter analyze --no-fatal-infos # Analyze code
flutter run -d web-server --web-port 8080  # Run on web
```

### Building

```bash
# Build for web
flutter build web

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
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

This project uses Flutter's built-in testing framework and includes comprehensive test coverage:

```bash
# Run all tests
flutter test

# Generate coverage report
flutter test --coverage

# Or using mise
mise run coverage
```

Code coverage is automatically collected and reported in CI using GitHub's native coverage reporting. Coverage reports are displayed in:

- Pull request comments showing overall coverage percentage and file-by-file breakdown
- GitHub Actions job summaries with coverage metrics
- Commit status checks indicating if coverage meets the 70% threshold

Coverage fails if it drops below 70% overall, helping maintain code quality.

## Data API

This app uses the Cambridge Beer Festival data API via a Cloudflare Worker proxy:
- Base URL: `https://cbf-data-proxy.richard-alcock.workers.dev`
- Example: `https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025/beer.json`

### Documentation

API documentation and JSON schemas are available in the [docs/api](docs/api/) directory:

- [API Overview](docs/api/README.md) - Quick reference and schema usage
- [Data API Reference](docs/api/data-api-reference.md) - Complete API documentation
- [Beer List Schema](docs/api/beer-list-schema.json) - JSON Schema for beverage data
- [Festival Registry Schema](docs/api/festival-registry-schema.json) - JSON Schema for festival configuration

## Architecture & Documentation

Technical documentation is available in the [docs](docs/) directory:

- [URL Routing](docs/URL_ROUTING.md) - Path-based routing implementation and configuration
- [Cloudflare Pages Setup](docs/CLOUDFLARE_PAGES_SETUP.md) - Deployment configuration
- [CI/CD](docs/CICD.md) - Complete CI/CD workflow documentation
- [Testing](docs/TESTING_FLUTTER_WEB.md) - Testing Flutter web applications

## Deployment

The app is deployed to multiple environments:

- **Production** (Cloudflare Pages): [cambeerfestival.app](https://cambeerfestival.app)
  - Deployed on version tags (e.g., `v2025.12.0`)
  - Uses Cloudflare Pages project `cambeerfestival`, branch `release`
  - Workflow: `.github/workflows/release-web.yml`
- **Staging** (Cloudflare Pages): [staging.cambeerfestival.app](https://staging.cambeerfestival.app)
  - Stable staging environment
  - Deployed automatically on push to `main`
  - Uses Cloudflare Pages project `cambeerfestival-staging`, branch `main`
  - Workflow: `.github/workflows/build-deploy.yml` (deploy-web-preview job)
- **PR Previews** (Cloudflare Pages): Unique URL per pull request
  - Each PR gets its own preview environment (e.g., `<branch>.cambeerfestival-staging.pages.dev`)
  - Preview URL posted as comment on the PR
  - Workflow: `.github/workflows/build-deploy.yml` (deploy-web-preview job)

### Deployment Strategy

1. **Development changes**: Push to `main` → Staging (Cloudflare Pages)
2. **PR reviews**: Open PR → Unique Cloudflare Pages preview created
3. **Production releases**: Create tag (e.g., `v2025.12.0`) → Production deployment to cambeerfestival.app

For deployment setup and configuration, see [Cloudflare Pages Setup Guide](docs/CLOUDFLARE_PAGES_SETUP.md).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app (Java)