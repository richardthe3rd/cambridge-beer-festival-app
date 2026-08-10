import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/services.dart';
import 'firebase_options.dart';
// Guarded on dart.library.js_interop, not dart.library.html: `dart:html` is
// only provided by dart2js, so a `--wasm` build would silently fall through to
// the no-op stub and revert to hash routing (see ADR 0004, issue #525).
import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // coverage:ignore-start
  // Configure path-based URLs for web (removes # from URLs)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();

  // The bundled typefaces in assets/fonts/ are redistributed under the SIL
  // Open Font License, which requires the licence to ship with them.
  registerFontLicenses();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught Flutter errors to Crashlytics. Transient google_fonts
    // font-fetch failures are downgraded to non-fatal (see
    // isTransientFontLoadError).
    FlutterError.onError = (details) {
      final isBenign = isTransientFontLoadError(
        details.exception,
        details.stack,
      );
      if (isBenign) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      } else {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      final isBenign = isTransientFontLoadError(error, stack);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: !isBenign);
      return true;
    };

    // Log app launch
    await AnalyticsService().logAppLaunch();
  } catch (e) {
    // Log to console in debug mode, but allow app to continue
    debugPrint('Failed to initialize Firebase: $e');
  }

  runApp(const BeerFestivalApp());
  // coverage:ignore-end
}

/// Whether [error] originates from `google_fonts` runtime font fetching.
///
/// google_fonts downloads fonts over HTTP on first use. When the device is
/// offline or the font CDN fails, the load throws an uncaught async error.
/// The app keeps running with a fallback font, so such failures are transient
/// and non-fatal — they must not be recorded to Crashlytics as fatal crashes,
/// which would otherwise distort the crash-free metric.
bool isTransientFontLoadError(Object error, StackTrace? stack) {
  if (error.toString().contains('Failed to load font')) return true;
  return stack != null && stack.toString().contains('google_fonts');
}

class BeerFestivalApp extends StatelessWidget {
  const BeerFestivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // coverage:ignore-start
    return ChangeNotifierProvider(
      create: (_) => BeerProvider(),
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<BeerProvider>().themeMode;
          return MaterialApp.router(
            title: 'Cambridge Beer Festival',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: themeMode,
            routerConfig: appRouter,
          );
        },
      ),
    );
    // coverage:ignore-end
  }
}
