import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

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
      unawaited(context.read<BeerProvider>().refreshIfStale());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Initialize and load drinks for all routes. initialize() never throws
      // (a startup failure surfaces as provider.error), so the redirect below
      // always runs and the app never strands on the loading screen.
      final provider = context.read<BeerProvider>();
      unawaited(
        provider.initialize().then((_) {
          unawaited(provider.loadDrinks());
          // After initialization, trigger redirects that were deferred
          _handlePostInitRedirect();
        }),
      );
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
      // Uses constant from utils/navigation_helpers.dart to avoid duplication
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
        unawaited(
          provider.analyticsService.logError(
            e,
            stackTrace,
            reason: 'Post-initialization redirect failed',
          ),
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
