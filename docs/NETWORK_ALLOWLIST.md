# Network Allowlist for Development

This document lists all the network domains that need to be allowed for GitHub Copilot agents (or other sandboxed development environments) to build, test, run, and take screenshots of the Cambridge Beer Festival web app.

## Summary

| Domain | Purpose | Required For |
|--------|---------|--------------|
| `storage.googleapis.com` | Flutter SDK downloads | Installing Flutter |
| `pub.dev` | Dart packages | `flutter pub get` |
| `www.gstatic.com` | Flutter CanvasKit engine | Running web app |
| `fonts.gstatic.com` | Google Fonts (Roboto) | Running web app |
| `cbf-data-proxy.richard-alcock.workers.dev` | Festival API (via Cloudflare Worker) | App runtime data |
| `data.cambridgebeerfestival.com` | Upstream festival data | App runtime data (proxied) |

## Detailed Breakdown

### 1. Flutter SDK Installation

**Domain:** `storage.googleapis.com`

Required to download the Flutter SDK tarball.

```
https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_*.tar.xz
```

### 2. Dart Package Manager (pub.dev)

**Domain:** `pub.dev`

Required for `flutter pub get` to download dependencies defined in `pubspec.yaml`.

```
https://pub.dev/
```

### 3. Flutter Web Runtime - CanvasKit

**Domain:** `www.gstatic.com`

Flutter web uses CanvasKit (based on Skia) for rendering. Without this, the web app shows a blank white page.

```
https://www.gstatic.com/flutter-canvaskit/a18df97ca57a249df5d8d68cd0820600223ce262/canvaskit.js
https://www.gstatic.com/flutter-canvaskit/a18df97ca57a249df5d8d68cd0820600223ce262/canvaskit.wasm
```

**Error when blocked:**
```
Failed to fetch dynamically imported module: https://www.gstatic.com/flutter-canvaskit/...
```

### 4. Google Fonts

**Domain:** `fonts.gstatic.com`

Flutter uses Roboto as its default font. Without this, text may not render correctly.

```
https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Me5WZLCzYlKw.ttf
```

**Error when blocked:**
```
Failed to load font Roboto at https://fonts.gstatic.com/s/roboto/v20/...
```

### 5. Festival Data API

**Domain:** `cbf-data-proxy.richard-alcock.workers.dev`

The app's Cloudflare Worker proxy that serves festival data with CORS headers enabled for web access.

```
https://cbf-data-proxy.richard-alcock.workers.dev/festivals.json
https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025/beer.json
https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025/cider.json
# ... other beverage types
```

### 6. Upstream Data Source (Optional)

**Domain:** `data.cambridgebeerfestival.com`

The upstream data source that the Cloudflare Worker proxies. Not directly accessed by the web app (due to CORS restrictions), but may be useful to allow for testing the proxy or direct API access.

```
https://data.cambridgebeerfestival.com/cbf2025/beer.json
```

## Testing Without Network Access

The app includes comprehensive unit tests that can run without network access using mocked HTTP clients. Run:

```bash
flutter test
```

All 74 tests should pass without any network dependencies.

## Screenshot of Blocked App

When the required domains are blocked, the Flutter web app displays a blank white page:

![Flutter web app blocked](https://github.com/user-attachments/assets/eb57410a-830a-4963-ac35-1d8b2dba5722)

Console errors will show:
- `Failed to load font Roboto at https://fonts.gstatic.com/...`

## Minimal Allowlist

For the **minimum** functionality to build and test:

1. `storage.googleapis.com` - Flutter SDK
2. `pub.dev` - Dart packages

For **running the web app and taking screenshots**:

3. `www.gstatic.com` - CanvasKit rendering engine
4. `fonts.gstatic.com` - Fonts

For **full app functionality with live data**:

5. `cbf-data-proxy.richard-alcock.workers.dev` - Festival API
