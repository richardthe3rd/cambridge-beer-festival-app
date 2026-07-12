import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/beer_provider.dart';
import 'screens/screens.dart';
import 'utils/navigation_helpers.dart';
import 'main.dart';

/// Global routes that exist outside festival scope
/// IMPORTANT: Keep in sync with _handlePostInitRedirect in main.dart
const List<String> globalRoutes = ['/about'];

/// Shared redirect logic for festival-scoped routes.
///
/// Returns null when uninitialized (loading screen is shown) or when the
/// festival ID is invalid without a custom handler.  When the URL festival
/// differs from the provider's current festival, schedules a switch via
/// [WidgetsBinding.addPostFrameCallback] so the router can complete
/// navigation first.
///
/// [onInvalidFestival] — called with the current festival ID when the URL
/// festival is invalid; return a redirect path or null to stay put.
String? _festivalScopeRedirect(
  BuildContext context,
  GoRouterState state, {
  String? Function(String currentFestivalId)? onInvalidFestival,
}) {
  final festivalId = state.pathParameters['festivalId'];
  final provider = context.read<BeerProvider>();
  if (!provider.isInitialized) return null;
  if (!provider.isValidFestivalId(festivalId)) {
    return onInvalidFestival?.call(provider.currentFestival.id);
  }
  final festival = provider.getFestivalById(festivalId!);
  if (festival != null && provider.currentFestival.id != festivalId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.setFestival(festival, persist: false);
    });
  }
  return null;
}

/// Application router configuration using go_router for better web support
///
/// Router structure (Phase 1 - Festival-scoped URLs):
/// - Root redirect: `/` → `/{currentFestivalId}`
/// - Parent ShellRoute: Initializes provider for ALL routes (critical for deep linking)
/// - Festival-scoped routes: `/:festivalId/...` with validation
/// - Nested ShellRoute: Adds bottom navigation bar for main screens only
/// - Direct routes: Detail pages without navigation bar
/// - Global routes: `/about` (no festival scope)
final GoRouter appRouter = _buildRouter();

GoRouter _buildRouter() {
  // Makes context.push() (used by navigateToRoute()) update the browser URL
  // bar when pushing a route that isn't nested inside the enclosing
  // ShellRoute — e.g. a drink detail pushed from the drinks list — matching
  // what context.go() already does. Without this, go_router leaves the URL
  // stuck at the shell's route (the bug navigateToRoute() previously worked
  // around by using go() on web, which had the side effect of disposing the
  // calling screen and losing its scroll position).
  //
  // go_router's own docs caution that this flag isn't always safe because
  // "the URL of the top-most GoRoute is not always deeplink-able" — that
  // doesn't apply here: every route this app pushes (drink/brewery/style
  // detail, festival info, about) is a fully-formed, independently
  // deep-linkable top-level GoRoute with its own redirect/validation logic.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Global routes FIRST (before festival routes)
      // Must come before /:festivalId to avoid being caught as festival ID
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
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
              // Wait for provider initialization before redirecting
              if (!provider.isInitialized) {
                return null; // ProviderInitializer will show loading screen
              }
              return '/${provider.currentFestival.id}';
            },
            // The builder is only reached while the provider is initializing
            // (the redirect above returns null). It must exist: a redirect-only
            // route that stays put leaves go_router with no page to build, so
            // it mounts a Navigator with an empty `pages` list and no
            // `onGenerateRoute`, which crashes with "Null check operator used
            // on a null value" in release builds (issue #386). Once
            // initialization completes, _handlePostInitRedirect in main.dart
            // navigates to the current festival.
            builder: (context, state) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
          // Festival-scoped routes with navigation bar
          ShellRoute(
            builder: (context, state, child) => BeerFestivalHome(child: child),
            routes: [
              GoRoute(
                path: '/:festivalId',
                redirect: (context, state) => _festivalScopeRedirect(
                  context,
                  state,
                  onInvalidFestival: (currentId) {
                    final queryString = state.uri.query.isNotEmpty
                        ? '?${state.uri.query}'
                        : '';
                    return '/$currentId$queryString';
                  },
                ),
                pageBuilder: (context, state) {
                  final festivalId = state.pathParameters['festivalId']!;
                  return NoTransitionPage(
                    child: DrinksScreen(festivalId: festivalId),
                  );
                },
              ),
              GoRoute(
                path: '/:festivalId/favorites',
                redirect: (context, state) => _festivalScopeRedirect(
                  context,
                  state,
                  onInvalidFestival: (currentId) => '/$currentId/favorites',
                ),
                pageBuilder: (context, state) {
                  final festivalId = state.pathParameters['festivalId']!;
                  return NoTransitionPage(
                    child: MyFestivalScreen(festivalId: festivalId),
                  );
                },
              ),
            ],
          ),
          // Detail routes - Provider initialized, but no navigation bar
          GoRoute(
            path: '/:festivalId/drink/:category/:id',
            redirect: (context, state) => _festivalScopeRedirect(
              context,
              state,
              onInvalidFestival: (currentId) =>
                  '/$currentId/drink/${state.pathParameters['category']}/${state.pathParameters['id']}',
            ),
            builder: (context, state) {
              final festivalId = state.pathParameters['festivalId']!;
              final id = state.pathParameters['id']!;
              // Key by drink so navigating drink→drink (e.g. tapping a Similar
              // Drinks card) rebuilds a fresh screen — resetting scroll to the
              // top and re-running the "drink viewed" analytics — instead of
              // reusing the previous drink's State and its scroll offset.
              return DrinkDetailScreen(
                key: ValueKey('$festivalId/$id'),
                festivalId: festivalId,
                drinkId: id,
              );
            },
          ),
          GoRoute(
            path: '/:festivalId/brewery/:id',
            redirect: (context, state) => _festivalScopeRedirect(
              context,
              state,
              onInvalidFestival: (currentId) =>
                  '/$currentId/brewery/${state.pathParameters['id']}',
            ),
            builder: (context, state) {
              final festivalId = state.pathParameters['festivalId']!;
              final id = state.pathParameters['id']!;
              return BreweryScreen(festivalId: festivalId, breweryId: id);
            },
          ),
          GoRoute(
            path: '/:festivalId/style/:name',
            redirect: (context, state) => _festivalScopeRedirect(
              context,
              state,
              onInvalidFestival: (currentId) =>
                  '/$currentId/style/${state.pathParameters['name']}',
            ),
            builder: (context, state) {
              final festivalId = state.pathParameters['festivalId']!;
              final name = state.pathParameters['name']!;
              return StyleScreen(
                festivalId: festivalId,
                style: safeDecodeComponent(name),
              );
            },
          ),
          GoRoute(
            path: '/:festivalId/info',
            redirect: (context, state) => _festivalScopeRedirect(
              context,
              state,
              onInvalidFestival: (currentId) => '/$currentId/info',
            ),
            builder: (context, state) {
              final festivalId = state.pathParameters['festivalId']!;
              return FestivalInfoScreen(festivalId: festivalId);
            },
          ),
        ],
      ),
    ],
  );
}
