import 'package:flutter/material.dart';

/// The blocking "error" branch of the four-signal loading/error contract
/// (see AGENTS.md and skill `ui-and-accessibility` Part 4.2) — an icon, a
/// title, the provider's own error message, and a Retry action.
///
/// Originally lived only inside `DrinksScreen`'s `_DrinksListSliver`. Issue
/// #639: the three detail screens (`DrinkDetailScreen`, `BreweryScreen`,
/// `StyleScreen`) never rendered this branch at all — they select
/// `isLoading` and the entity's presence in `allDrinks`, but not `error`, so
/// a cold load that fails with nothing cached (e.g. a shared drink URL
/// opened offline) fell through to the "Not Found" scaffold instead: no
/// Retry, and the provider's own error message never shown. This widget is
/// the one shared implementation so all four screens render the same error
/// view rather than four near-duplicate copies drifting apart.
///
/// Not a [Sliver] itself — callers that need one wrap it (`DrinksScreen`
/// puts it inside a `SliverFillRemaining`); the detail screens drop it
/// straight into a `Scaffold`'s `body`.
class CatalogueErrorView extends StatelessWidget {
  const CatalogueErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  /// The message from `BeerProvider.error` — already user-friendly text
  /// (e.g. "Server error. Please try again later."), not a raw exception.
  final String error;

  /// Calls back into `BeerProvider.loadDrinks` (or equivalent) to retry the
  /// failed catalogue load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Error loading drinks',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Semantics(
          key: const ValueKey('catalogue-error-retry'),
          label: 'Retry loading drinks',
          hint: 'Double tap to reload festival data',
          button: true,
          excludeSemantics: true,
          child: ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
