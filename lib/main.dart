import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/services.dart';
import 'utils/utils.dart';
import 'widgets/widgets.dart';
import 'firebase_options.dart';
import 'url_strategy_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // Configure path-based URLs for web (removes # from URLs)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Log app launch
    await AnalyticsService().logAppLaunch();
  } catch (e) {
    // Log to console in debug mode, but allow app to continue
    debugPrint('Failed to initialize Firebase: $e');
  }

  runApp(const BeerFestivalApp());
}

class BeerFestivalApp extends StatelessWidget {
  const BeerFestivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BeerProvider(),
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<BeerProvider>().themeMode;
          return MaterialApp.router(
            title: 'Cambridge Beer Festival',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD97706), // Amber/copper beer color
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD97706),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeMode,
            routerConfig: appRouter,
          );
        },
      ),
    );
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

class _ProviderInitializerState extends State<ProviderInitializer> with WidgetsBindingObserver {
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
        return; // Already on valid route, no redirect needed
      }

      // Path pattern: /:festivalId or /:festivalId/...
      // Extract first path segment as potential festival ID
      if (segments.isEmpty) return;

      final firstSegment = segments.first;

      // If first segment is not a valid festival ID, redirect
      if (!provider.isValidFestivalId(firstSegment)) {
        // Preserve the rest of the path and query parameters
        final restOfPath = segments.length > 1 ? '/${segments.sublist(1).join('/')}' : '';
        final queryString = currentUri.query.isNotEmpty ? '?${currentUri.query}' : '';
        router.go('/${provider.currentFestival.id}$restOfPath$queryString');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Post-init redirect error: $e');
        debugPrint(stackTrace.toString());
      } else {
        // In production, log to crashlytics
        final provider = context.read<BeerProvider>();
        provider.analyticsService.logError(
          e,
          stackTrace,
          reason: 'Post-initialization redirect failed',
        );
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

class _BeerFestivalHomeState extends State<BeerFestivalHome> {

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
      final festivalId = _festivalId ?? context.read<BeerProvider>().currentFestival.id;

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          const EnvironmentBadge(),
        ],
      ),
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
    );
  }
}

/// Screen showing favorited drinks
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.festivalId,
    super.key,
  });

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
            Text(provider.currentFestival.name, style: theme.textTheme.titleMedium),
            Text('${favorites.length} favorites', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: favorites.isEmpty
          ? Semantics(
              label: 'No favorites yet. Tap the heart icon on drinks you want to try.',
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
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
                  onTap: () => context.go(buildDrinkDetailPath(festivalId, drink.id)),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
            ),
    );
  }
}
