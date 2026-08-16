// AboutScreen fires _loadPackageInfo() unawaited from initState. If the user
// pops the screen while that platform call is still in flight, the continuation
// calls setState() on a disposed State and Flutter raises
// "setState() called after dispose()".
//
// That error does NOT reach the user or fail a test on its own: _loadPackageInfo
// wraps the await in try/catch, so it swallows its own dispose error, logs it
// via debugPrint, and falls into the catch branch. So this is a spurious error
// path and a misleading log line ("Failed to load package info: setState()
// called after dispose()"), not a crash. The assertions below therefore watch
// debugPrint — asserting on tester.takeException() would pass either way.
//
// `flutter analyze` structurally cannot see this: `unawaited_futures` only fires
// inside async function bodies, and initState is sync. It was found by
// dart_code_linter's use-setstate-synchronously rule.
//
// Reproducing it needs a genuinely pending future. `PackageInfo
// .setMockInitialValues` cannot do that — it populates the static
// `PackageInfo._fromPlatform` cache, which `fromPlatform()` returns
// immediately, so the await resolves in a microtask that `pumpWidget` has
// already flushed by the time the screen is disposed. A test written that way
// passes with the mounted guard removed, i.e. it guards nothing.
//
// So this file injects a PackageInfoPlatform whose getAll() completes only when
// the test says so, and never calls setMockInitialValues (which would
// short-circuit the injection via that same cache).
//
// Verified in both directions: removing the `if (!mounted) return;` from the try
// branch of _loadPackageInfo makes the first test below fail with
// "setState() called after dispose()".
import 'dart:async';

import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

/// A platform whose `getAll()` stays pending until [complete] is called, so a
/// widget can be disposed with the load still in flight.
class _PendingPackageInfoPlatform extends PackageInfoPlatform
    with MockPlatformInterfaceMixin {
  final _completer = Completer<PackageInfoData>();

  var getAllCalled = false;

  @override
  Future<PackageInfoData> getAll({String? baseUrl}) {
    getAllCalled = true;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      PackageInfoData(
        appName: 'Cambridge Beer Festival',
        packageName: 'ralcock.cbf',
        version: '2025.12.0',
        buildNumber: '20251200',
        buildSignature: '',
      ),
    );
  }
}

void main() {
  group('AboutScreen disposal during package-info load', () {
    late BeerProvider provider;
    late _PendingPackageInfoPlatform platform;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      platform = _PendingPackageInfoPlatform();
      PackageInfoPlatform.instance = platform;
      provider = BeerProvider(
        drinkRepository: MockDrinkRepository(),
        festivalRepository: MockFestivalRepository(),
        analyticsService: MockAnalyticsService(),
      );
    });

    tearDown(() {
      provider.dispose();
    });

    /// Collects debugPrint output while [body] runs. `debugPrint` is a
    /// foundation debug variable, and flutter_test asserts every one of them is
    /// back to its original value by the time the test body returns — so it must
    /// be restored here, not in tearDown.
    Future<List<String>> captureDebugPrint(Future<void> Function() body) async {
      final log = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) log.add(message);
      };
      try {
        await body();
      } finally {
        debugPrint = original;
      }
      return log;
    }

    Widget wrap(Widget child) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(home: child),
      );
    }

    testWidgets('disposing mid-load does not call setState after dispose', (
      tester,
    ) async {
      final debugLog = await captureDebugPrint(() async {
        await tester.pumpWidget(wrap(const AboutScreen()));

        // The load has started and is parked on the platform call. If this is
        // false the injected platform was bypassed and the test proves nothing.
        expect(platform.getAllCalled, isTrue);

        // Dispose AboutScreen while the load is still pending, then let the
        // continuation run.
        await tester.pumpWidget(wrap(const SizedBox.shrink()));
        expect(find.byType(AboutScreen), findsNothing);

        platform.complete();
        // Two drains: completing the completer resumes PackageInfo.fromPlatform
        // first, and only its return resumes _loadPackageInfo's own await. A
        // single pumpAndSettle can return before that second hop has run, which
        // would close the capture window before the error is printed.
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(
        debugLog,
        isNot(contains(contains('setState() called after dispose'))),
        reason:
            'the load continuation called setState on a disposed State; '
            '_loadPackageInfo needs its `if (!mounted) return;` guard',
      );
      expect(debugLog, isEmpty, reason: 'no error path should have run');
    });

    testWidgets('staying mounted renders the loaded version', (tester) async {
      // Control: proves the load really does reach setState and paint, so the
      // test above cannot pass merely because nothing ever ran.
      //
      // No 'Loading...' pre-assertion here: PackageInfo caches the first
      // successful result in a private static, so by this second test
      // fromPlatform() may return it synchronously and the placeholder is never
      // observable. Only the first test in this file gets a cold cache, which is
      // why the dispose case is ordered first.
      final debugLog = await captureDebugPrint(() async {
        await tester.pumpWidget(wrap(const AboutScreen()));
        platform.complete();
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(debugLog, isEmpty);
      expect(find.textContaining('2025.12.0'), findsWidgets);
    });
  });
}
