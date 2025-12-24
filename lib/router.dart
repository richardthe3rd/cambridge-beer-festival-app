import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/beer_provider.dart';
import 'screens/screens.dart';
import 'main.dart';

/// Application router configuration using go_router for better web support
///
/// Router structure (Phase 1 - Festival-scoped URLs):
/// - Root redirect: `/` → `/{currentFestivalId}`
/// - Parent ShellRoute: Initializes provider for ALL routes (critical for deep linking)
/// - Festival-scoped routes: `/:festivalId/...` with validation
/// - Nested ShellRoute: Adds bottom navigation bar for main screens only
/// - Direct routes: Detail pages without navigation bar
/// - Global routes: `/about` (no festival scope)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // Parent shell - Ensures provider initialization for ALL routes
    // This fixes deep linking by initializing data before any screen renders
    ShellRoute(
      builder: (context, state, child) => ProviderInitializer(child: child),
      routes: [
        // Root redirect to current festival
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final provider = context.read<BeerProvider>();
            return '/${provider.currentFestival.id}';
          },
        ),
        // Festival-scoped routes
        GoRoute(
          path: '/:festivalId',
          redirect: (context, state) {
            final festivalId = state.pathParameters['festivalId'];
            final provider = context.read<BeerProvider>();

            // Validate festival ID
            if (!provider.isValidFestivalId(festivalId)) {
              // Redirect to current festival if invalid
              return '/${provider.currentFestival.id}';
            }

            // Switch festival if different from current
            final festival = provider.getFestivalById(festivalId!);
            if (festival != null && provider.currentFestival.id != festivalId) {
              // Note: This is async, but we can't await in redirect
              // The festival switch will happen, and the screen will rebuild
              WidgetsBinding.instance.addPostFrameCallback((_) {
                provider.setFestival(festival);
              });
            }

            return null; // Allow navigation
          },
          routes: [
            // Nested shell - Main screens with bottom navigation bar
            ShellRoute(
              builder: (context, state, child) => BeerFestivalHome(child: child),
              routes: [
                GoRoute(
                  path: '',
                  pageBuilder: (context, state) {
                    final festivalId = state.pathParameters['festivalId']!;
                    return NoTransitionPage(
                      child: DrinksScreen(festivalId: festivalId),
                    );
                  },
                ),
                GoRoute(
                  path: 'favorites',
                  pageBuilder: (context, state) {
                    final festivalId = state.pathParameters['festivalId']!;
                    return NoTransitionPage(
                      child: FavoritesScreen(festivalId: festivalId),
                    );
                  },
                ),
              ],
            ),
            // Detail routes - Provider initialized, but no navigation bar
            GoRoute(
              path: 'drink/:id',
              builder: (context, state) {
                final festivalId = state.pathParameters['festivalId']!;
                final id = state.pathParameters['id']!;
                return DrinkDetailScreen(
                  festivalId: festivalId,
                  drinkId: id,
                );
              },
            ),
            GoRoute(
              path: 'brewery/:id',
              builder: (context, state) {
                final festivalId = state.pathParameters['festivalId']!;
                final id = state.pathParameters['id']!;
                return BreweryScreen(
                  festivalId: festivalId,
                  breweryId: id,
                );
              },
            ),
            GoRoute(
              path: 'style/:name',
              builder: (context, state) {
                final festivalId = state.pathParameters['festivalId']!;
                final name = state.pathParameters['name']!;
                final decodedName = Uri.decodeComponent(name);
                return StyleScreen(
                  festivalId: festivalId,
                  style: decodedName,
                );
              },
            ),
            GoRoute(
              path: 'info',
              builder: (context, state) {
                final festivalId = state.pathParameters['festivalId']!;
                return FestivalInfoScreen(festivalId: festivalId);
              },
            ),
          ],
        ),
        // Global routes (no festival scope)
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
  ],
);
