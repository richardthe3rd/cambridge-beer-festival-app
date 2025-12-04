import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'widgets/widgets.dart';
import 'firebase_options.dart';

void main() async {
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
          return MaterialApp(
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
            initialRoute: '/',
            onGenerateRoute: (settings) {
              // Parse route name and extract parameters
              final uri = Uri.parse(settings.name ?? '/');

              switch (uri.path) {
                case '/':
                  return MaterialPageRoute(
                    builder: (_) => const BeerFestivalHome(),
                    settings: settings,
                  );
                case '/about':
                  return MaterialPageRoute(
                    builder: (_) => const AboutScreen(),
                    settings: settings,
                  );
                case '/festival-info':
                  final festival = settings.arguments as Festival?;
                  if (festival != null) {
                    return MaterialPageRoute(
                      builder: (_) => FestivalInfoScreen(festival: festival),
                      settings: settings,
                    );
                  }
                  // Fallback to home if no festival provided
                  return MaterialPageRoute(
                    builder: (_) => const BeerFestivalHome(),
                    settings: settings,
                  );
                case '/drink':
                  final drinkId = settings.arguments as String?;
                  if (drinkId != null) {
                    return MaterialPageRoute(
                      builder: (_) => DrinkDetailScreen(drinkId: drinkId),
                      settings: settings,
                    );
                  }
                  // Fallback to home if no drink ID provided
                  return MaterialPageRoute(
                    builder: (_) => const BeerFestivalHome(),
                    settings: settings,
                  );
                case '/brewery':
                  final breweryId = settings.arguments as String?;
                  if (breweryId != null) {
                    return MaterialPageRoute(
                      builder: (_) => BreweryScreen(breweryId: breweryId),
                      settings: settings,
                    );
                  }
                  // Fallback to home if no brewery ID provided
                  return MaterialPageRoute(
                    builder: (_) => const BeerFestivalHome(),
                    settings: settings,
                  );
                default:
                  // Unknown route - fallback to home
                  return MaterialPageRoute(
                    builder: (_) => const BeerFestivalHome(),
                    settings: settings,
                  );
              }
            },
          );
        },
      ),
    );
  }
}

class BeerFestivalHome extends StatefulWidget {
  const BeerFestivalHome({super.key});

  @override
  State<BeerFestivalHome> createState() => _BeerFestivalHomeState();
}

class _BeerFestivalHomeState extends State<BeerFestivalHome> with WidgetsBindingObserver {
  int _currentIndex = 0;
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
      // Initialize and load drinks
      final provider = context.read<BeerProvider>();
      provider.initialize().then((_) => provider.loadDrinks());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Show a snackbar when user tries to exit from home screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            DrinksScreen(),
            FavoritesScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
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
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/drink',
                    arguments: drink.id,
                  ),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
            ),
    );
  }
}
