import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/services.dart';
import 'utils/utils.dart';
import 'widgets/widgets.dart';
import 'firebase_options.dart';
import 'url_strategy_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // coverage:ignore-start
  // Configure path-based URLs for web (removes # from URLs)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught Flutter errors to Crashlytics. Transient google_fonts
    // font-fetch failures are downgraded to non-fatal (see
    // isTransientFontLoadError).
    FlutterError.onError = (details) {
      final isBenign =
          isTransientFontLoadError(details.exception, details.stack) ||
          isBenignRestorationError(details.exception, details.stack);
      if (isBenign) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      } else {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      final isBenign =
          isTransientFontLoadError(error, stack) ||
          isBenignRestorationError(error, stack);
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

/// Whether [error] is a known benign Flutter 3.44.0 regression in state restoration.
///
/// The root redirect (`/` → `/cbf2025`) causes Flutter's hardcoded
/// `restorationScopeId: 'router'` bucket (in WidgetsApp) to serialize a named
/// route entry. On flush, `_NamedRestorationInformation.createRoute` calls
/// `navigator._routeNamed(name)!` which is always null under go_router (no
/// `onGenerateRoute`). The error is caught, the app continues, and there is no
/// user-visible impact — but without this guard it records as a fatal crash in
/// Crashlytics and distorts the crash-free metric.
///
/// On native and web debug/profile builds the stack must contain a restoration
/// frame so unrelated null-deref crashes are not incorrectly downgraded. On
/// web release builds dart2js minifies class names so the check falls back to
/// message alone.
@visibleForTesting
bool isBenignRestorationError(Object error, StackTrace? stack) {
  if (error.toString() != 'Null check operator used on a null value') {
    return false;
  }
  // Web release stacks are minified by dart2js — class names are not
  // preserved so the call site cannot be identified. Accept on message alone.
  // In web debug/profile builds the stack is readable, so fall through to the
  // frame check below.
  if (kIsWeb && kReleaseMode) return true;
  // Native or web debug/profile: require a restoration-related frame to avoid
  // downgrading unrelated null-check crashes to non-fatal.
  if (stack == null) return false;
  final s = stack.toString();
  return s.contains('_NamedRestorationInformation') ||
      s.contains('RestorationBucket');
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

/// Widget that initializes the BeerProvider before rendering children
/// This ensures provider is initialized for all routes, including deep links
class ProviderInitializer extends StatefulWidget {
  final Widget child;

  const ProviderInitializer({super.key, required this.child});

  @override
  State<ProviderInitializer> createState() => _ProviderInitializerState();
}

class _ProviderInitializerState extends State<ProviderInitializer>
    with WidgetsBindingObserver {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes to foreground, refresh data if stale
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<BeerProvider>();
      provider.refreshIfStale();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Initialize and load drinks for all routes
      final provider = context.read<BeerProvider>();
      provider.initialize().then((_) {
        provider.loadDrinks();
        // After initialization, trigger redirects that were deferred
        _handlePostInitRedirect();
      });
    }
  }

  /// Handle route redirects after provider initialization
  ///
  /// CONTEXT: go_router's redirect callbacks run once on initial navigation and
  /// don't re-run when provider state changes. This method explicitly handles
  /// redirects that were deferred during initialization.
  ///
  /// KNOWN LIMITATIONS:
  /// - Deep links with invalid festival IDs in subpaths are NOT redirected
  ///   Example: /invalid-fest/drink/abc stays at /invalid-fest/drink/abc
  ///   Reason: These match route patterns directly (/:festivalId/drink/:id)
  ///           bypassing the festival home redirect logic
  ///   Impact: User sees 404 or broken state until they navigate away
  ///   Fix: Requires adding festival ID validation to ALL route builders
  ///
  /// - URL fragments are not preserved during redirects
  ///   Example: /invalid-fest#section → /cbf2025 (loses #section)
  ///   Impact: Scroll position hints from deep links are lost
  ///   Fix: Preserve currentUri.fragment in redirect URL construction
  void _handlePostInitRedirect() {
    if (!mounted) return;

    try {
      final router = GoRouter.of(context);
      final state = GoRouterState.of(context);
      final provider = context.read<BeerProvider>();

      final currentUri = state.uri;
      final currentPath = currentUri.path;
      final segments = currentUri.pathSegments;

      // Check if we're on root path - redirect to festival home
      if (currentPath == '/') {
        router.go('/${provider.currentFestival.id}');
        return;
      }

      // Global routes (no festival scope) - do NOT redirect these
      // Uses constant from router.dart to avoid duplication
      if (globalRoutes.contains(currentPath)) {
        return; // Stay on global route
      }

      // For festival-scoped routes, validate the festival ID
      // Early return: if already on valid festival route, skip expensive checks
      if (segments.isNotEmpty && provider.isValidFestivalId(segments.first)) {
        // Sync provider when the URL festival differs from the current one.
        // This is the primary fix for cold-loading a non-default festival URL
        // (browser refresh, shared link opened fresh).
        if (segments.first != provider.currentFestival.id) {
          final festival = provider.getFestivalById(segments.first);
          if (festival != null) {
            unawaited(provider.setFestival(festival, persist: false));
          }
        }
        return;
      }

      // Path pattern: /:festivalId or /:festivalId/...
      // Extract first path segment as potential festival ID
      if (segments.isEmpty) return;

      final firstSegment = segments.first;

      // If first segment is not a valid festival ID, redirect
      if (!provider.isValidFestivalId(firstSegment)) {
        // Preserve the rest of the path and query parameters
        final restOfPath = segments.length > 1
            ? '/${segments.sublist(1).join('/')}'
            : '';
        final queryString = currentUri.query.isNotEmpty
            ? '?${currentUri.query}'
            : '';
        router.go('/${provider.currentFestival.id}$restOfPath$queryString');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Post-init redirect error: $e');
        debugPrint(stackTrace.toString());
      } else {
        // coverage:ignore-start
        // In production, log to crashlytics
        final provider = context.read<BeerProvider>();
        provider.analyticsService.logError(
          e,
          stackTrace,
          reason: 'Post-initialization redirect failed',
        );
        // coverage:ignore-end
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    // Show loading screen until provider is initialized
    if (provider.isLoading && provider.allDrinks.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading festival data...'),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

class BeerFestivalHome extends StatefulWidget {
  final Widget child;

  const BeerFestivalHome({super.key, required this.child});

  @override
  State<BeerFestivalHome> createState() => _BeerFestivalHomeState();
}

const Duration _exitConfirmationWindow = Duration(seconds: 2);
const String _exitConfirmationMessage = 'Press back again to exit';

class _BeerFestivalHomeState extends State<BeerFestivalHome> {
  Timer? _exitConfirmationTimer;

  int get _currentIndex {
    // Try to get the current location from GoRouter
    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location.endsWith('/favorites')) return 1;
      return 0;
    } catch (e) {
      // If GoRouter is not available (e.g., in tests), default to 0
      return 0;
    }
  }

  /// Get festivalId from current route
  String? get _festivalId {
    try {
      final params = GoRouterState.of(context).pathParameters;
      return params['festivalId'];
    } catch (e) {
      return null;
    }
  }

  void _onDestinationSelected(int index) {
    // Try to use GoRouter navigation
    try {
      // Get festival ID from URL or fall back to provider
      final festivalId =
          _festivalId ?? context.read<BeerProvider>().currentFestival.id;

      if (index == 0) {
        context.go(buildFestivalHome(festivalId));
      } else if (index == 1) {
        context.go(buildFavoritesPath(festivalId));
      }
    } catch (e) {
      // If GoRouter is not available, this is a no-op
      // (tests that don't use GoRouter won't navigate)
    }
  }

  @override
  void dispose() {
    _exitConfirmationTimer?.cancel();
    super.dispose();
  }

  void _handleExitConfirmation() {
    if (!mounted) return;

    if (_exitConfirmationTimer?.isActive ?? false) {
      _exitConfirmationTimer!.cancel();
      _exitConfirmationTimer = null;
      if (!kIsWeb) {
        SystemNavigator.pop();
      }
      return;
    }

    _exitConfirmationTimer = Timer(_exitConfirmationWindow, () {
      _exitConfirmationTimer = null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(_exitConfirmationMessage),
          duration: _exitConfirmationWindow,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasNavigationHistory = canPopNavigation(context);

    return PopScope(
      canPop: kIsWeb || hasNavigationHistory,
      onPopInvokedWithResult: (didPop, result) {
        final canPopNow = canPopNavigation(context);
        if (didPop || canPopNow) {
          _exitConfirmationTimer?.cancel();
          _exitConfirmationTimer = null;
          return;
        }
        _handleExitConfirmation();
      },
      child: Scaffold(
        body: Stack(children: [widget.child, const EnvironmentBadge()]),
        bottomNavigationBar: NavigationBar(
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              key: const Key('drinks_tab'),
              icon: Semantics(
                label: 'Drinks tab, browse all festival drinks',
                child: Opacity(
                  opacity: 0.6,
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              selectedIcon: Semantics(
                label: 'Drinks tab, browse all festival drinks',
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 24,
                  height: 24,
                ),
              ),
              label: 'Drinks',
            ),
            NavigationDestination(
              key: const Key('favorites_tab'),
              icon: Semantics(
                label: 'Favorites tab, view your favorite drinks',
                child: const Icon(Icons.favorite_outline),
              ),
              selectedIcon: Semantics(
                label: 'Favorites tab, view your favorite drinks',
                child: const Icon(Icons.favorite),
              ),
              label: 'Favorites',
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen showing favorited drinks
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({required this.festivalId, super.key});

  final String festivalId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();
    final favorites = provider.favoriteDrinks;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.currentFestival.name,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '${favorites.length} favorites',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [buildOverflowMenu(context)],
      ),
      body: favorites.isEmpty
          ? Semantics(
              label:
                  'No favorites yet. Tap the heart icon on drinks you want to try.',
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text('No favorites yet', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Tap the ♡ on drinks you want to try'),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final drink = favorites[index];
                return DrinkCard(
                  key: ValueKey(drink.id),
                  drink: drink,
                  onTap: () => navigateToRoute(
                    context,
                    buildDrinkDetailPath(festivalId, drink.category, drink.id),
                  ),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
            ),
    );
  }
}
