import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'main.dart';

/// Application router configuration using go_router for better web support
///
/// Router structure:
/// - Parent ShellRoute: Initializes provider for ALL routes (critical for deep linking)
/// - Nested ShellRoute: Adds bottom navigation bar for main screens only
/// - Direct routes: Detail pages without navigation bar
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // Parent shell - Ensures provider initialization for ALL routes
    // This fixes deep linking by initializing data before any screen renders
    ShellRoute(
      builder: (context, state, child) => ProviderInitializer(child: child),
      routes: [
        // Nested shell - Main screens with bottom navigation bar
        ShellRoute(
          builder: (context, state, child) => BeerFestivalHome(child: child),
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DrinksScreen(),
              ),
            ),
            GoRoute(
              path: '/favorites',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: FavoritesScreen(),
              ),
            ),
          ],
        ),
        // Detail routes - Provider initialized, but no navigation bar
        GoRoute(
          path: '/drink/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DrinkDetailScreen(drinkId: id);
          },
        ),
        GoRoute(
          path: '/brewery/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return BreweryScreen(breweryId: id);
          },
        ),
        GoRoute(
          path: '/style/:name',
          builder: (context, state) {
            final name = state.pathParameters['name']!;
            final decodedName = Uri.decodeComponent(name);
            return StyleScreen(style: decodedName);
          },
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/festival-info',
          builder: (context, state) {
            // Get festival from provider
            final festival = context.read<BeerProvider>().currentFestival;
            return FestivalInfoScreen(festival: festival);
          },
        ),
      ],
    ),
  ],
);
