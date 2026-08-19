import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps the `main()` of every test file under `test/`, discovered
/// automatically by `flutter test` and run once per file.
///
/// Two sets of fonts have to be in place before any golden renders, for the
/// same reason: a font `flutter_test` cannot resolve is drawn as a placeholder
/// box, and a golden full of placeholder boxes cannot catch a regression in
/// the thing it is supposed to be guarding.
///
///  * **The app's typefaces.** Turning off runtime fetching forces
///    `google_fonts` to resolve Playfair/Nunito from the bundled assets in
///    `assets/fonts/` instead of downloading them from fonts.gstatic.com.
///    Goldens then render the real faces on every machine, online or not, and
///    if `buildAppTextTheme` gains a weight with no matching file the load
///    throws rather than silently papering over it with a network fetch.
///  * **The declared font families**, `MaterialIcons` above all. Flutter
///    registers these when the app starts, but `flutter test` does not, so
///    every icon in every golden used to render as the same hollow box — two
///    icons as different as `Icons.search` and `Icons.visibility_outlined`
///    compared byte-identical (issue #580).
///
/// If a test starts failing with "allowRuntimeFetching is false but font
/// X was not found", the fix is to add that variant to `assets/fonts/` — not to
/// re-enable fetching. See docs/code/fonts.md.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadBundledFonts();
  await testMain();
}

/// Registers every font family the app bundle declares with the test engine,
/// by reading the same `FontManifest.json` Flutter itself uses at startup.
///
/// Going through the asset bundle rather than the Flutter SDK's own
/// `material_fonts` directory is deliberate: the bundle is built from this
/// package's `pubspec.yaml`, so the glyphs a golden renders are by
/// construction the ones the app ships, and there is no `FLUTTER_ROOT` lookup
/// or platform-specific path to keep working across machines and CI. It is
/// also the approach the ecosystem's golden helpers take (`golden_toolkit`'s
/// `loadAppFonts`, `alchemist`).
///
/// Loading every declared family rather than naming `MaterialIcons` means a
/// font added to `pubspec.yaml` later is covered without editing this file.
Future<void> _loadBundledFonts() async {
  // `rootBundle` reaches through ServicesBinding, which `flutter test` has not
  // set up yet at the point this wrapper runs — without this the whole file
  // fails to load with "Binding has not yet been initialized". Idempotent, and
  // the test framework calls it again itself.
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;

  var loadedMaterialIcons = false;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final fonts = entry['fonts'] as List<dynamic>;
    final loader = FontLoader(family);
    for (final font in fonts) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
    loadedMaterialIcons |= family == 'MaterialIcons';
  }

  // Guard the case this exists for. An empty or icon-less manifest would load
  // nothing and quietly return, and the only symptom would be 27 goldens
  // regenerating to hollow boxes the next time somebody ran goldens:update.
  if (!loadedMaterialIcons) {
    throw StateError(
      'FontManifest.json declared no MaterialIcons family, so every icon in '
      'every golden would render as a placeholder box.\n'
      'Check that `uses-material-design: true` is still set in pubspec.yaml.\n'
      'See docs/code/fonts.md.',
    );
  }
}
