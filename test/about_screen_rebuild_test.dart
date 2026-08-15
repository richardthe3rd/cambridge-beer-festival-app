// Regression/proof test for issue #523: AboutScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one AboutScreen never renders, like the search query —
// rebuilt the entire screen. Narrowing to a single context.select on
// themeMode (the only provider value this screen renders) means an
// unrelated notifyListeners() no longer touches AboutScreen.build() at all.
//
// AboutScreen has no debugBuildCount-style hook (unlike DrinkCard), and
// adding one is out of scope for this change per AGENTS.md's "keep the
// manifest tight" guidance — so this test proves rebuild activity from
// outside the widget instead: AboutScreen.build() always constructs a
// fresh (non-const) PageTitle instance, and Flutter's element diffing only
// swaps in that new instance if build() actually ran. Comparing the
// PageTitle instance's identity across pumps is therefore an exact proxy
// for "did AboutScreen.build() execute again" — not a proxy state
// variable, but the same instance-identity trick #523's own controllers
// rely on elsewhere (Drink/Festival ==).
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('AboutScreen narrowed rebuilds (#523)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Cambridge Beer Festival',
        packageName: 'ralcock.cbf',
        version: '2025.12.0',
        buildNumber: '20251200',
        buildSignature: '',
      );

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(home: AboutScreen()),
      );
    }

    PageTitle currentPageTitle(WidgetTester tester) =>
        tester.widget<PageTitle>(find.byType(PageTitle));

    testWidgets(
      'a provider change AboutScreen does not render leaves the build '
      'count unchanged',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final pageTitleBefore = currentPageTitle(tester);

        // The search query is never read by AboutScreen or its narrowed
        // select.
        provider.setSearchQuery('ipa');
        await tester.pump();

        expect(
          identical(currentPageTitle(tester), pageTitleBefore),
          isTrue,
          reason:
              'An unrelated provider field change must not rebuild '
              'AboutScreen — this is the literal acceptance bar for #523',
        );
      },
    );

    testWidgets(
      'control: changing themeMode does rebuild it and shows the new label',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('System mode'), findsOneWidget);
        final pageTitleBefore = currentPageTitle(tester);

        await provider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          identical(currentPageTitle(tester), pageTitleBefore),
          isFalse,
          reason: 'Test setup check: the counter must be provably live',
        );
        expect(find.text('Dark mode'), findsOneWidget);
        expect(find.text('System mode'), findsNothing);
      },
    );
  });
}
