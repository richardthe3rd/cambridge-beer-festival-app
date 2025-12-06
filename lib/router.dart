import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'main.dart';

/// Application router configuration using go_router for better web support
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
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
    GoRoute(
      path: '/drink/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null) {
          // Redirect to home if ID is missing
          return const Scaffold(
            body: Center(child: Text('Invalid drink ID')),
          );
        }
        return DrinkDetailScreen(drinkId: id);
      },
    ),
    GoRoute(
      path: '/brewery/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null) {
          // Redirect to home if ID is missing
          return const Scaffold(
            body: Center(child: Text('Invalid brewery ID')),
          );
        }
        return BreweryScreen(breweryId: id);
      },
    ),
    GoRoute(
      path: '/style/:name',
      builder: (context, state) {
        final name = state.pathParameters['name'];
        if (name == null) {
          // Redirect to home if name is missing
          return const Scaffold(
            body: Center(child: Text('Invalid style name')),
          );
        }
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
);
