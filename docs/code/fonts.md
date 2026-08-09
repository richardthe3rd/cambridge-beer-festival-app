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

## Known gap

Material icon glyphs still render as hollow boxes in goldens — `MaterialIcons`
is not loaded by `flutter_test`. That is unrelated to this setup and unchanged by
it; goldens cover icon *position and size*, not the glyph itself.
