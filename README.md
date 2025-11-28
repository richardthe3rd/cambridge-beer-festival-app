# Cambridge Beer Festival App

[![Build and Deploy](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/build-deploy.yml/badge.svg)](https://github.com/richardthe3rd/cambridge-beer-festival-app/actions/workflows/build-deploy.yml)

A Flutter app for browsing beers, ciders, meads, and more at the Cambridge Beer Festival.

**[Live Demo](https://richardthe3rd.github.io/cambridge-beer-festival-app/)** (when deployed)

## Features

- 🍺 Browse all drinks from the festival (beers, ciders, perry, mead, wine)
- 🔍 Search by name, brewery, or style
- 🏷️ Filter by drink category
- ↕️ Sort by name, ABV, brewery, or style
- ❤️ Save favorites for easy access
- 🏭 View brewery details and all their drinks
- 📱 Works on Android, iOS, and Web

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24.5 or later)
- Android Studio, Xcode, or VS Code with Flutter extensions

### Installation

```bash
# Clone the repository
git clone https://github.com/richardthe3rd/cambridge-beer-festival-app.git
cd cambridge-beer-festival-app

# Get dependencies
flutter pub get

# Run the app
flutter run
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

## Data API

This app uses the Cambridge Beer Festival data API:
- Base URL: `https://data.cambridgebeerfestival.com`
- Example: `https://data.cambridgebeerfestival.com/cbf2025/beer.json`

See [docs/api](https://github.com/richardthe3rd/BeerFestApp/tree/main/docs/api) in the original repository for API documentation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app (Java)