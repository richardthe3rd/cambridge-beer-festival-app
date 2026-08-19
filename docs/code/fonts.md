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

## The bundled font families are registered for tests

`MaterialIcons` is not one of the families in the table above. It arrives in the
app bundle from `uses-material-design: true`, which puts it in the generated
`FontManifest.json` alongside `cupertino_icons`. Flutter registers everything in
that manifest when the app starts — but `flutter test` does not, so for a long
time every icon in every golden rendered as the same hollow box. Two icons as
different as `Icons.search` and `Icons.visibility_outlined` compared
**byte-identical**, which meant no golden could catch an icon regression
(issue #580, the icon analogue of #520 above).

`test/flutter_test_config.dart` now reads that same manifest through
`rootBundle` and registers every family it declares, before any test runs. This
is the approach the ecosystem's golden helpers take (`golden_toolkit`'s
`loadAppFonts`, `alchemist`), and it is worth preferring over reading the
Flutter SDK's own `bin/cache/artifacts/material_fonts/` directory:

- The bundle is built from this package's `pubspec.yaml`, so the glyphs a golden
  renders are *by construction* the ones the app ships.
- There is no `FLUTTER_ROOT` lookup and no platform-specific path
  (`artifacts/engine/<platform>/flutter_tester`) to keep working across
  machines and CI.
- A family added to `pubspec.yaml` later is picked up without editing the test
  config.

One wrinkle: `rootBundle` reaches through `ServicesBinding`, which is not set up
at the point that wrapper runs, so it calls
`TestWidgetsFlutterBinding.ensureInitialized()` first. Without it every test file
fails to load with *"Binding has not yet been initialized"*. The call is
idempotent and the test framework makes it again itself.

Because icons now render for real, a Flutter SDK upgrade that changes a Material
glyph will show up as a golden diff. That is signal, not noise — regenerate and
review the diff as you would for any other visual change.

### If the icon font is missing

The loader **throws** when the manifest declares no `MaterialIcons` family,
rather than loading nothing and quietly returning. The only symptom of a silent
skip would be 27 goldens regenerating to hollow boxes the next time somebody ran
`goldens:update`, long after the cause:

```
FontManifest.json declared no MaterialIcons family, so every icon in every
golden would render as a placeholder box.
```

Check that `uses-material-design: true` is still set in `pubspec.yaml` rather
than removing the guard.
