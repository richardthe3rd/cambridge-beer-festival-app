import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs once before every test under `test/`, discovered automatically by
/// `flutter test`.
///
/// Turning off runtime fetching forces `google_fonts` to resolve the app's
/// typefaces from the bundled assets in `assets/fonts/` instead of downloading
/// them from fonts.gstatic.com. That matters for two reasons:
///
///  * **Determinism.** Goldens render the real Playfair/Nunito faces on every
///    machine, online or not, instead of depending on whether the runner
///    happened to reach Google's CDN.
///  * **It fails loudly.** If `buildAppTextTheme` gains a weight that has no
///    matching file in `assets/fonts/`, `google_fonts` throws and the test
///    fails, rather than silently papering over it with a network fetch that
///    only works on a connected machine.
///
/// If a test starts failing with "allowRuntimeFetching is false but font
/// X was not found", the fix is to add that variant to `assets/fonts/` — not to
/// re-enable fetching. See docs/code/fonts.md.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
