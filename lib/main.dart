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

class BeerFestivalHome extends StatefulWidget {
  final Widget child;

  const BeerFestivalHome({super.key, required this.child});

  @override
  State<BeerFestivalHome> createState() => _BeerFestivalHomeState();
}

class _BeerFestivalHomeState extends State<BeerFestivalHome> with WidgetsBindingObserver {
  bool _initialized = false;

  int get _currentIndex {
    // Try to get the current location from GoRouter
    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location == '/favorites') return 1;
      return 0;
    } catch (e) {
      // If GoRouter is not available (e.g., in tests), default to 0
      return 0;
    }
  }

  void _onDestinationSelected(int index) {
    // Try to use GoRouter navigation
    try {
      if (index == 0) {
        context.go('/');
      } else if (index == 1) {
        context.go('/favorites');
      }
    } catch (e) {
      // If GoRouter is not available, this is a no-op
      // (tests that don't use GoRouter won't navigate)
    }
  }

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
      // Initialize and load drinks
      final provider = context.read<BeerProvider>();
      provider.initialize().then((_) => provider.loadDrinks());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        height: 60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: Semantics(
              label: 'Drinks tab, browse all festival drinks',
              child: const Icon(Icons.local_drink_outlined),
            ),
            selectedIcon: Semantics(
              label: 'Drinks tab, browse all festival drinks',
              child: const Icon(Icons.local_drink),
            ),
            label: 'Drinks',
          ),
          NavigationDestination(
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
  const FavoritesScreen({super.key});

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
          ? Center(
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
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final drink = favorites[index];
                return DrinkCard(
                  key: ValueKey(drink.id),
                  drink: drink,
                  onTap: () => context.go('/drink/${drink.id}'),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
            ),
    );
  }
}
