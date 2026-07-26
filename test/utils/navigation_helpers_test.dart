import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Navigation Helpers', () {
    group('buildFestivalPath', () {
      test('builds path with leading slash', () {
        expect(
          buildFestivalPath('cbf2025', '/drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('builds path without leading slash', () {
        expect(
          buildFestivalPath('cbf2025', 'drinks'),
          equals('/cbf2025/drinks'),
        );
      });

      test('handles nested paths', () {
        expect(
          buildFestivalPath('cbf2025', '/brewery/123'),
          equals('/cbf2025/brewery/123'),
        );
      });

      test('handles festival IDs with special characters', () {
        expect(
          buildFestivalPath('cbf-2025', '/drinks'),
          equals('/cbf-2025/drinks'),
        );
      });
    });

    group('buildFestivalHome', () {
      test('builds home path', () {
        expect(buildFestivalHome('cbf2025'), equals('/cbf2025'));
      });
    });

    group('buildFavoritesPath', () {
      test('builds favorites path', () {
        expect(buildFavoritesPath('cbf2025'), equals('/cbf2025/favorites'));
      });
    });

    group('buildFestivalInfoPath', () {
      test('builds festival info path', () {
        expect(buildFestivalInfoPath('cbf2025'), equals('/cbf2025/info'));
      });
    });

    group('buildDrinkDetailPath', () {
      test('builds drink detail path', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'beer', 'drink-123'),
          equals('/cbf2025/drink/beer/drink-123'),
        );
      });

      test('handles drink IDs with special characters', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'beer', 'drink-123-abc'),
          equals('/cbf2025/drink/beer/drink-123-abc'),
        );
      });

      test('URL-encodes category with spaces', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'foreign beer', 'drink-123'),
          equals('/cbf2025/drink/foreign%20beer/drink-123'),
        );
      });
    });

    group('buildBreweryPath', () {
      test('builds brewery path', () {
        expect(
          buildBreweryPath('cbf2025', 'brewery-123'),
          equals('/cbf2025/brewery/brewery-123'),
        );
      });
    });

    group('buildStylePath', () {
      test('builds style path with lowercase', () {
        expect(buildStylePath('cbf2025', 'IPA'), equals('/cbf2025/style/ipa'));
      });

      test('converts mixed case to lowercase and URL-encodes', () {
        expect(
          buildStylePath('cbf2025', 'American IPA'),
          equals('/cbf2025/style/american%20ipa'),
        );
      });

      test('converts to lowercase and URL-encodes special characters', () {
        expect(
          buildStylePath('cbf2025', 'Barrel-Aged Stout'),
          equals('/cbf2025/style/barrel-aged%20stout'),
        );
      });
    });

    group('URL encoding edge cases', () {
      test('encodes drink IDs with spaces', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'beer', 'drink 123'),
          equals('/cbf2025/drink/beer/drink%20123'),
        );
      });

      test('encodes drink IDs with special characters', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'beer', 'drink/456'),
          equals('/cbf2025/drink/beer/drink%2F456'),
        );
      });

      test('encodes brewery IDs with ampersands', () {
        expect(
          buildBreweryPath('cbf2025', 'Oak & Elm'),
          equals('/cbf2025/brewery/Oak%20%26%20Elm'),
        );
      });

      test(
        'converts to lowercase and encodes Unicode characters in style names',
        () {
          expect(
            buildStylePath('cbf2025', 'Märzen'),
            equals('/cbf2025/style/m%C3%A4rzen'),
          );
        },
      );
    });

    group('Input validation', () {
      test('buildFestivalPath asserts on empty festival ID', () {
        expect(() => buildFestivalPath('', '/drinks'), throwsAssertionError);
      });

      test('buildFestivalPath asserts on empty path', () {
        expect(() => buildFestivalPath('cbf2025', ''), throwsAssertionError);
      });

      test('buildDrinkDetailPath asserts on empty drink ID', () {
        expect(
          () => buildDrinkDetailPath('cbf2025', 'beer', ''),
          throwsAssertionError,
        );
      });

      test('buildBreweryPath asserts on empty brewery ID', () {
        expect(() => buildBreweryPath('cbf2025', ''), throwsAssertionError);
      });
    });

    group('Edge cases', () {
      test('handles very long festival IDs', () {
        final longId = 'x' * 100;
        expect(buildFestivalHome(longId), equals('/$longId'));
      });

      test('handles URL-encoded characters in IDs', () {
        expect(
          buildDrinkDetailPath('cbf2025', 'beer', 'test%20drink'),
          equals('/cbf2025/drink/beer/test%2520drink'),
        );
      });
    });

    group('navigateToRoute', () {
      testWidgets(
        'navigates to the specified path, updates the URL, and keeps the '
        'base route mounted underneath',
        (tester) async {
          // This is a standalone fixture GoRouter, separate from the app's
          // `appRouter`, so it must set the flag itself rather than relying
          // on router.dart's side effect. The flag is a process-global
          // static; setting it to true here is safe and idempotent even if
          // another test (or router.dart's _buildRouter()) already set it.
          GoRouter.optionURLReflectsImperativeAPIs = true;

          bool detailVisited = false;
          final baseKey = GlobalKey();
          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  key: baseKey,
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => navigateToRoute(context, '/detail'),
                      child: const Text('Navigate'),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/detail',
                builder: (context, state) {
                  detailVisited = true;
                  return const Scaffold(body: Text('Detail'));
                },
              ),
            ],
          );

          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.tap(find.text('Navigate'));
          await tester.pumpAndSettle();

          expect(detailVisited, isTrue);

          // The URL bar reflects the pushed route rather than staying stuck
          // at '/' — this is the property that drives the real browser URL
          // bar (NOT routerDelegate.currentConfiguration.uri, which does not
          // reflect imperative pushes the same way).
          expect(
            router.routeInformationProvider.value.uri.toString(),
            '/detail',
          );

          // The base route's widget is still present in the tree underneath
          // the pushed route (offstage, not disposed) — proving push()
          // preserves the calling screen's state instead of replacing it.
          expect(find.byKey(baseKey, skipOffstage: false), findsOneWidget);
        },
      );
    });

    group('returnToDrinksList', () {
      // A fixture router: a festival-home base ('/:festivalId') under which
      // detail routes are pushed, mirroring the app's shape closely enough to
      // exercise pop-to-root and the deep-link fallback.
      GoRouter buildFixtureRouter(String initialLocation) {
        return GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: '/:festivalId',
              builder: (context, state) => Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Drinks list'),
                      ElevatedButton(
                        onPressed: () => context.push('/cbf2025/drink/a'),
                        child: const Text('Go to drink'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/:festivalId/drink/:id',
              builder: (context, state) => Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      Text('Drink ${state.pathParameters['id']}'),
                      ElevatedButton(
                        onPressed: () => context.push('/cbf2025/drink/b'),
                        child: const Text('Go deeper'),
                      ),
                      ElevatedButton(
                        onPressed: () => returnToDrinksList(context, 'cbf2025'),
                        child: const Text('Back to drinks'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }

      testWidgets('collapses a multi-level detail stack back to the list', (
        tester,
      ) async {
        final router = buildFixtureRouter('/cbf2025');
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        // Drill down two levels: drinks list → drink a → drink b.
        await tester.tap(find.text('Go to drink'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Go deeper'));
        await tester.pumpAndSettle();
        expect(find.text('Drink b'), findsOneWidget);
        expect(router.canPop(), isTrue);

        // A single action returns all the way to the list.
        await tester.tap(find.text('Back to drinks'));
        await tester.pumpAndSettle();

        expect(find.text('Drinks list'), findsOneWidget);
        expect(find.textContaining('Drink '), findsNothing);
        expect(router.canPop(), isFalse);
      });

      testWidgets('falls back to festival home when the stack cannot pop', (
        tester,
      ) async {
        // Deep-linked straight onto a detail route — no list underneath.
        final router = buildFixtureRouter('/cbf2025/drink/a');
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        expect(router.canPop(), isFalse);

        await tester.tap(find.text('Back to drinks'));
        await tester.pumpAndSettle();

        expect(find.text('Drinks list'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/cbf2025',
        );
      });

      testWidgets(
        'reaches the drinks list when deep-linked then drilled deeper',
        (tester) async {
          // Deep-linked onto a detail route (the stack base), then pushed a
          // further detail — so canPop() is now true but the base underneath is
          // still a detail screen, not the list. Collapsing must land on the
          // festival home, not the deep-linked detail root.
          final router = buildFixtureRouter('/cbf2025/drink/a');
          addTearDown(router.dispose);
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));

          await tester.tap(find.text('Go deeper'));
          await tester.pumpAndSettle();
          expect(find.text('Drink b'), findsOneWidget);
          expect(router.canPop(), isTrue);

          await tester.tap(find.text('Back to drinks'));
          await tester.pumpAndSettle();

          expect(find.text('Drinks list'), findsOneWidget);
          expect(find.textContaining('Drink '), findsNothing);
          expect(
            router.routeInformationProvider.value.uri.toString(),
            '/cbf2025',
          );
        },
      );
    });

    group('canPopNavigation', () {
      testWidgets('returns false when GoRouter is not available', (
        tester,
      ) async {
        // In test environment with MaterialApp but without GoRouter
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final result = canPopNavigation(context);
                return Scaffold(body: Text('Can pop: $result'));
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Without GoRouter, canPopNavigation should return false
        expect(find.text('Can pop: false'), findsOneWidget);
      });
    });
  });
}
