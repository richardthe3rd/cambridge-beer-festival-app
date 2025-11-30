import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'widgets/widgets.dart';

void main() {
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
            home: const BeerFestivalHome(),
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
    return Scaffold(
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
                  drink: drink,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DrinkDetailScreen(drinkId: drink.id),
                    ),
                  ),
                  onFavoriteTap: () => provider.toggleFavorite(drink),
                );
              },
            ),
    );
  }
}
