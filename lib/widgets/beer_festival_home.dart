import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'environment_badge.dart';

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
                label:
                    'My Festival tab, view your want-to-try list and'
                    ' tasting log',
                child: const Icon(Icons.bookmark_outline),
              ),
              selectedIcon: Semantics(
                label:
                    'My Festival tab, view your want-to-try list and'
                    ' tasting log',
                child: const Icon(Icons.bookmark),
              ),
              label: 'My Festival',
            ),
          ],
        ),
      ),
    );
  }
}
