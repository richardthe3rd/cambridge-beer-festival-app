import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps the `main()` of every test file under `test/`, discovered
/// automatically by `flutter test` and run once per file.
///
/// Two fonts have to be in place before any golden renders, for the same
/// reason: a font `flutter_test` cannot resolve is drawn as a placeholder box,
/// and a golden full of placeholder boxes cannot catch a regression in the
/// thing it is supposed to be guarding.
///
///  * **The app's typefaces.** Turning off runtime fetching forces
///    `google_fonts` to resolve Playfair/Nunito from the bundled assets in
///    `assets/fonts/` instead of downloading them from fonts.gstatic.com.
///    Goldens then render the real faces on every machine, online or not, and
///    if `buildAppTextTheme` gains a weight with no matching file the load
///    throws rather than silently papering over it with a network fetch.
///  * **The Material icon font.** `MaterialIcons` is injected into the app
///    bundle by the build tooling (`uses-material-design: true`), not by the
///    asset list, so `flutter test` never sees it. Registering the SDK's own
///    copy makes icons render as themselves — before this, every icon in
///    every golden was the same hollow box, and two different icons compared
///    byte-identical (issue #580).
///
/// If a test starts failing with "allowRuntimeFetching is false but font
/// X was not found", the fix is to add that variant to `assets/fonts/` — not to
/// re-enable fetching. See docs/code/fonts.md.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadMaterialIcons();
  await testMain();
}

/// Registers the Flutter SDK's `MaterialIcons-Regular.otf` with the test
/// engine.
///
/// The font is read from the SDK rather than vendored into this repo: a copy
/// under `assets/` would be bundled into the production web and Android
/// builds — 1.6MB, unshaken, defeating Flutter's icon tree-shaking — and a
/// copy under `test/` would drift from whichever glyphs the app actually
/// ships as the SDK moves.
///
/// This throws rather than skipping when the font cannot be found. A silent
/// skip would make goldens depend on the machine that generated them, so a
/// developer and CI could disagree about a "correct" golden with nothing to
/// show for it; a hard failure names the problem immediately.
Future<void> _loadMaterialIcons() async {
  final file = _findMaterialIconsFont();
  if (file == null) {
    throw StateError(
      'Could not find MaterialIcons-Regular.otf in the Flutter SDK.\n'
      'Goldens render every icon as a placeholder box without it, so the '
      'test suite refuses to run rather than produce goldens that disagree '
      'with CI.\n'
      'Expected it at '
      '\$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf\n'
      'FLUTTER_ROOT=${Platform.environment['FLUTTER_ROOT'] ?? '(unset)'}\n'
      'See docs/code/fonts.md.',
    );
  }

  final loader = FontLoader('MaterialIcons')
    ..addFont(file.readAsBytes().then(ByteData.sublistView));
  await loader.load();
}

/// Locates the SDK's icon font, preferring `FLUTTER_ROOT` (which the flutter
/// tool exports into the test process) and falling back to a walk up from the
/// running `flutter_tester` binary. The fallback exists because the engine
/// directory in that path is platform-named
/// (`artifacts/engine/linux-x64/flutter_tester`), so a fixed number of hops
/// is not portable across machines.
File? _findMaterialIconsFont() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final fromEnv = File('$root/$relative');
    if (fromEnv.existsSync()) {
      return fromEnv;
    }
  }

  var dir = Directory(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File('${dir.path}/$relative');
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return null;
}
