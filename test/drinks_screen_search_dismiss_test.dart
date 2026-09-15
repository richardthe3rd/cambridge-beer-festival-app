import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

/// Covers the paths that dismiss the search field, and the app-bar takeover
/// that replaces the festival header while search is open (#664).
///
/// The two dismissal paths used to call
/// `provider.setSearchQuery('')` from inside a `setState` closure, firing
/// `notifyListeners()` while the element was being marked dirty (issue #526).
/// These tests assert the user-visible outcome of each path — the bar closes
/// and the full list comes back — so the behaviour is pinned regardless of how
/// the rebuild is scheduled.
void main() {
  group('DrinksScreen search dismissal', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final testDrinks = [
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Alpha IPA',
          abv: 5.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink2',
          name: 'Beta Bitter',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      // Dates and a location so FestivalBanner actually renders: with neither
      // it collapses to SizedBox.shrink, and a zero-extent sliver child is not
      // matched by the default finders — the takeover test below would then
      // pass against a banner that was never on screen.
      final testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        startDate: DateTime(2025, 5, 20),
        endDate: DateTime(2025, 5, 24),
        location: 'Jesus Green',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      final festivalsResponse = FestivalsResponse(
        festivals: [testFestival],
        defaultFestivalId: 'cbf2025',
        baseUrl: 'https://example.com',
        version: '1.0.0',
      );
      when(
        mockFestivalRepository.getFestivals(),
      ).thenAnswer((_) async => festivalsResponse);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => testDrinks);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(home: DrinksScreen(festivalId: 'cbf2025')),
      );
    }

    Future<void> tapBySemanticsLabel(WidgetTester tester, String label) async {
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      semantics.dispose();
    }

    /// Opens the search bar and applies [query], waiting out the 300ms debounce
    /// so the provider has actually filtered the list.
    Future<void> searchFor(WidgetTester tester, String query) async {
      await tapBySemanticsLabel(tester, 'Search drinks');
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('clear button empties the query without leaving search', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await searchFor(tester, 'Alpha');
      // The provider normalises the query to lower case.
      expect(provider.searchQuery, 'alpha');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsNothing);

      await tapBySemanticsLabel(tester, 'Clear search');

      // The unfiltered list is back but the field stays open, so a missed
      // find can be retried with a different word without reopening search
      // and losing the keyboard (#664). Exiting is the back arrow's job.
      expect(find.byType(TextField), findsOneWidget);
      expect(provider.searchQuery, '');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsOneWidget);
    });

    testWidgets('the clear button appears only once there is text to clear', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();

      // An empty field has nothing to clear, and the button's absence is what
      // gives the hint its width back after the back arrow took ~56px.
      expect(find.bySemanticsLabel('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Alpha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the exit arrow closes search and restores the app bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await searchFor(tester, 'Alpha');
      expect(find.text('Beta Bitter'), findsNothing);

      // Deliberately not labelled 'Close search' — the bottom search button
      // holds that label while open, and a duplicate would make this very
      // lookup ambiguous.
      await tapBySemanticsLabel(tester, 'Exit search');

      expect(find.byType(TextField), findsNothing);
      expect(provider.searchQuery, '');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsOneWidget);
    });

    testWidgets('search takes over the app bar and the festival banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();

      // Before: the app bar carries the festival identity and the overflow
      // menu, and the banner sits beneath it.
      expect(find.byType(FestivalHeader), findsOneWidget);
      expect(find.byType(FestivalBanner), findsOneWidget);
      expect(find.bySemanticsLabel('Menu'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();

      // During: all three give way to the field rather than stacking a third
      // row of chrome above the list (#664). This is the accepted cost of the
      // takeover, pinned here so losing it is a deliberate act.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FestivalHeader), findsNothing);
      expect(find.byType(FestivalBanner), findsNothing);
      expect(find.bySemanticsLabel('Menu'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Exit search'));
      await tester.pumpAndSettle();

      // After: everything comes straight back.
      expect(find.byType(FestivalHeader), findsOneWidget);
      expect(find.byType(FestivalBanner), findsOneWidget);
      expect(find.bySemanticsLabel('Menu'), findsWidgets);
      semantics.dispose();
    });

    testWidgets('the app bar pins itself while search is open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      SliverAppBar appBar() =>
          tester.widget<SliverAppBar>(find.byType(SliverAppBar));

      // Closed, the bar floats and snaps back on scroll-up as before.
      expect(appBar().floating, isTrue);
      expect(appBar().snap, isTrue);
      expect(appBar().pinned, isFalse);

      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();
      semantics.dispose();

      // Open, it pins: a field that scrolls away mid-typing is wrong.
      expect(appBar().floating, isFalse);
      expect(appBar().snap, isFalse);
      expect(appBar().pinned, isTrue);
    });

    testWidgets('collapsing via the search button clears the query', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await searchFor(tester, 'Alpha');
      expect(find.text('Beta Bitter'), findsNothing);

      // The search button relabels itself while the bar is open.
      await tapBySemanticsLabel(tester, 'Close search');

      expect(find.byType(TextField), findsNothing);
      expect(provider.searchQuery, '');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsOneWidget);
    });

    testWidgets('expanding the search bar leaves an existing query intact', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // A query set from elsewhere (e.g. a deep link) survives opening the bar:
      // only collapsing clears it.
      provider.setSearchQuery('Alpha');
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      expect(find.byType(TextField), findsOneWidget);
      expect(provider.searchQuery, 'alpha');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsNothing);

      // And the field adopts it rather than opening empty. An empty field
      // over a list narrowed by an invisible word is unexplainable, and with
      // the clear button hidden while empty there would be nothing in the
      // field to act on either.
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'alpha');
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the soft keyboard does not lift the bottom filter row', (
      WidgetTester tester,
    ) async {
      // Pumped inside the real shell: BeerFestivalHome's Scaffold is what
      // used to consume the bottom inset, so a bare MaterialApp would pass
      // this test whatever the shell did (#664).
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: DrinksScreen(festivalId: 'cbf2025')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double filterRowTop() =>
          tester.getRect(find.byType(FilterButton).first).top;
      final restingTop = filterRowTop();

      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();
      semantics.dispose();

      // Simulate a 300px soft keyboard.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // The row stays behind the keyboard rather than riding up to sit on it.
      // Before this was fixed it moved from y=686 to y=446 — 240px up, into
      // the middle of the screen, taking 48px out of an already-shrunken
      // list. The search field is in the app bar, so nothing down here needs
      // to clear the keyboard.
      expect(
        filterRowTop(),
        restingTop,
        reason:
            'The filter row moved from $restingTop to ${filterRowTop()} when '
            'the keyboard appeared; it should stay put.',
      );
    });

    testWidgets('the field keeps an accessible name once text is entered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'alpha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // A bare TextField's name is its hint only while it is empty; once the
      // user types, the node carries the value and no label. The takeover
      // removed FestivalHeader, so without this the app bar would announce
      // 'alpha' and nothing about what it is.
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, 'Search drinks');
      expect(node.value, 'alpha');
      semantics.dispose();
    });

    testWidgets('search bar hint names the fields search reaches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      // Pins the exact string so changing the hint is a deliberate act.
      // This guards one direction only: it fails when the hint changes, not
      // when SearchMatchService._searchableFields gains a field. Nothing can
      // assert the latter — _searchableFields is private and the mapping from
      // fields to hint wording is a judgement about width and discoverability,
      // not a derivation. The comment at the hintText carries that duty.
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .decoration
            ?.hintText,
        'Search drinks, styles, notes...',
      );
    });

    testWidgets('search bar hint is not ellipsised on a 375px screen', (
      WidgetTester tester,
    ) async {
      // The hint is the only place the note search is discoverable, so a hint
      // that truncates defeats its own purpose. 375px is the narrowest phone
      // still worth supporting; the field's prefix icon, clear button and
      // padding leave the hint 239px to render in.
      //
      // The theme matters: the app renders the hint in NunitoSans via
      // buildAppTheme, whereas a bare MaterialApp falls back to a font
      // flutter_test cannot resolve and draws every glyph as a fixed-width
      // placeholder box. Measuring against that would be measuring nothing.
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const DrinksScreen(festivalId: 'cbf2025'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      final hint = tester.renderObject<RenderParagraph>(
        find.text('Search drinks, styles, notes...').first,
      );
      expect(
        hint.didExceedMaxLines,
        isFalse,
        reason:
            'The hint renders in ${hint.size.width}px but needs '
            '${hint.getMaxIntrinsicWidth(double.infinity)}px, so it is being '
            'ellipsised. Shorten it rather than widening the field.',
      );
    });
  });
}
