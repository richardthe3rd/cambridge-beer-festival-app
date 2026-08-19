# Fonts

The app pairs **Playfair Display** (headings, app bar title) with **Nunito Sans**
(body, labels). Both are declared in `lib/app_theme.dart` via `buildAppTextTheme`
and resolved through the `google_fonts` package.

## The font files are bundled, not fetched

`assets/fonts/` ships the exact `.ttf` files `google_fonts` would otherwise
download from `fonts.gstatic.com` at runtime. `google_fonts` checks the asset
bundle before it checks the network, so bundling means the typefaces resolve
locally on every platform.

Two things this buys us:

- **First paint has no network dependency.** Previously the app rendered in a
  fallback face until the font download finished — over festival wifi, or on a
  phone with no signal, that could be the whole session.
- **Golden tests are deterministic.** `test/flutter_test_config.dart` sets
  `GoogleFonts.config.allowRuntimeFetching = false` for the whole test suite,
  so goldens render the real faces identically on any machine, online or not.
  That file also registers the Material icon font, for the same reason — see
  "The icon font is loaded from the SDK" below.

Before this, golden tests rendered every glyph as the blocky `FlutterTest`
placeholder box, which meant no golden could catch a typography or text-layout
regression (issue #520).

## Which variants are bundled

Only the weights `buildAppTextTheme` actually requests:

| File | Used by |
|---|---|
| `NunitoSans-Regular.ttf` (w400) | `bodyLarge`, `bodyMedium`, `bodySmall`, and the `nunitoSansTextTheme()` base |
| `NunitoSans-Medium.ttf` (w500) | `labelSmall`, base theme label styles |
| `NunitoSans-SemiBold.ttf` (w600) | `titleSmall`, `labelLarge`, `labelMedium` |
| `NunitoSans-Bold.ttf` (w700) | `titleMedium` |
| `PlayfairDisplay-SemiBold.ttf` (w600) | `displaySmall`, `headlineLarge/Medium/Small`, `titleLarge` |
| `PlayfairDisplay-Bold.ttf` (w700) | `displayLarge`, `displayMedium`, `appBarTheme.titleTextStyle` |

Roughly 674 KB in total.

## Licensing

Bundling means the app **redistributes** the font binaries rather than linking to
Google's CDN, and both families are licensed under the [SIL Open Font License
1.1](https://openfontlicense.org/), which requires the licence to travel with the
files. `assets/fonts/` therefore also holds `OFL-NunitoSans.txt` and
`OFL-PlayfairDisplay.txt`, and `registerFontLicenses()` in `lib/app_theme.dart`
adds them to Flutter's `LicenseRegistry` so they show up in the app's standard
"View licences" page. It is called from `main()` before `runApp`.

**Bundling a third family means registering its licence too** — add the entry to
`fontLicenseAssets` in `lib/app_theme.dart`. `test/app_theme_test.dart` loads
every declared licence asset for real, so a wrong path fails the suite instead of
silently registering nothing.

## Adding a weight

If you add a style to `buildAppTextTheme` that needs a weight not in the table
above, **the test suite will fail loudly** with:

```
GoogleFonts.config.allowRuntimeFetching is false but font X was not found in
the application assets.
```

That failure is the feature — it stops a new weight from silently depending on a
network fetch that only works on a connected machine. To fix it, add the variant:

1. Find the file hash for the family/weight in the `google_fonts` package
   manifest (`lib/src/google_fonts_parts/part_<letter>.g.dart` in the pub cache);
   each entry is `GoogleFontsFile('<sha256>', <length>)`.
2. Download it and verify both the hash and the length match:

   ```bash
   curl -sSL -o assets/fonts/<Family>-<Variant>.ttf \
     "https://fonts.gstatic.com/s/a/<sha256>.ttf"
   sha256sum assets/fonts/<Family>-<Variant>.ttf   # must equal <sha256>
   stat -c%s assets/fonts/<Family>-<Variant>.ttf   # must equal <length>
   ```

3. The filename must be `<FamilyWithoutSpaces>-<Variant>.ttf` — that is exactly
   the name quoted in the failure message. `assets/fonts/` is already listed in
   `pubspec.yaml`, so no manifest edit is needed.
4. Regenerate the affected goldens and review them by eye:
   `./bin/mise run goldens:update <test_file>`.

Do **not** fix this by re-enabling runtime fetching in tests.

## The icon font is loaded from the SDK

`MaterialIcons` is not one of the bundled families above. The build tooling
injects it into the app bundle from `uses-material-design: true`, not from the
asset list, so `flutter test` never sees it — and for a long time every icon in
every golden rendered as the same hollow box. Two icons as different as
`Icons.search` and `Icons.visibility_outlined` compared **byte-identical**,
which meant no golden could catch an icon regression (issue #580, the icon
analogue of #520 above).

`test/flutter_test_config.dart` now registers the SDK's own copy with a
`FontLoader` before any test runs, resolving it from `FLUTTER_ROOT` (which the
flutter tool exports into the test process) and falling back to a walk up from
the running `flutter_tester`.

The font is read from the SDK rather than copied into this repo, deliberately:

- A copy under `assets/` would be bundled into the production web and Android
  builds — 1.6 MB, unshaken, defeating Flutter's icon tree-shaking. The
  families in the table above are bundled because the *app* needs them at
  runtime; the icon font is only needed by *tests*.
- A copy under `test/` would avoid that, but would drift from whichever glyphs
  the app actually ships as the SDK moves.

Because icons now render for real, a Flutter SDK upgrade that changes a Material
glyph will show up as a golden diff. That is signal, not noise — regenerate and
review the diff as you would for any other visual change.

### If the font cannot be found

The loader **throws** rather than skipping. A silent skip would make goldens
depend on the machine that generated them, so a developer and CI could disagree
about a "correct" golden with nothing on screen to explain why. A hard failure
names the problem instead:

```
Could not find MaterialIcons-Regular.otf in the Flutter SDK.
```

Fix the toolchain (`./bin/mise install`) rather than removing the loader — the
goldens are the guard here, and 27 of them regress to hollow boxes without it.
