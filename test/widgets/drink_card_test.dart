import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/drink_card.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  late Drink testDrink;
  late Producer testProducer;
  late Product testProduct;

  setUp(() {
    testProducer = Producer.fromJson({
      'id': 'brewery-1',
      'name': 'Test Brewery',
      'location': 'Cambridge',
      'products': [],
    });

    testProduct = Product.fromJson({
      'id': 'drink-1',
      'name': 'Test IPA',
      'category': 'beer',
      'style': 'IPA',
      'dispense': 'cask',
      'abv': '5.5',
      'status_text': 'Plenty left',
    });

    testDrink = Drink(
      product: testProduct,
      producer: testProducer,
      festivalId: 'cbf2025',
    );
  });

  Widget createTestWidget({
    required Drink drink,
    VoidCallback? onTap,
    VoidCallback? onFavoriteTap,
    Brightness brightness = Brightness.light,
    String searchQuery = '',
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B3170),
          brightness: brightness,
        ),
        useMaterial3: true,
        brightness: brightness,
      ),
      home: Scaffold(
        body: DrinkCard(
          drink: drink,
          onTap: onTap,
          onFavoriteTap: onFavoriteTap,
          searchQuery: searchQuery,
        ),
      ),
    );
  }

  group('DrinkCard', () {
    testWidgets('displays drink name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Test IPA'), findsOneWidget);
    });

    testWidgets('displays brewery name and location', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Test Brewery • Cambridge'), findsOneWidget);
    });

    testWidgets('displays brewery name only when location is empty', (
      WidgetTester tester,
    ) async {
      final producerNoLocation = Producer.fromJson({
        'id': 'brewery-2',
        'name': 'Another Brewery',
        'location': '',
        'products': [],
      });

      final drink = Drink(
        product: testProduct,
        producer: producerNoLocation,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Another Brewery'), findsOneWidget);
      expect(find.text('Another Brewery • '), findsNothing);
    });

    testWidgets('displays ABV percentage', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('5.5%'), findsOneWidget);
    });

    testWidgets('displays style when available', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('IPA'), findsOneWidget);
    });

    testWidgets('displays dispense method', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Cask'), findsOneWidget);
    });

    testWidgets('displays availability status when present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('does not render a favorite/heart icon (removed in #413)', (
      WidgetTester tester,
    ) async {
      final drink = testDrink.copyWith(
        userState: UserDrinkState.initial().copyWith(wantToTry: true),
      );
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.byIcon(Icons.favorite_outline), findsNothing);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestWidget(drink: testDrink, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls onTap when the drink name text is tapped', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestWidget(drink: testDrink, onTap: () => tapped = true),
      );

      await tester.tap(find.text('Test IPA'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls onTap when the brewery text is tapped', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestWidget(drink: testDrink, onTap: () => tapped = true),
      );

      await tester.tap(find.textContaining('Test Brewery'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('does not show style chip when style is null', (
      WidgetTester tester,
    ) async {
      final productNoStyle = Product.fromJson({
        'id': 'drink-2',
        'name': 'Basic Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
      });

      final drink = Drink(
        product: productNoStyle,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      // Should still show ABV and dispense but not style
      expect(find.text('4.0%'), findsOneWidget);
      expect(find.text('Cask'), findsOneWidget);
    });

    testWidgets('shows low availability chip correctly', (
      WidgetTester tester,
    ) async {
      final productLow = Product.fromJson({
        'id': 'drink-3',
        'name': 'Low Stock Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'status_text': 'A little remaining',
      });

      final drink = Drink(
        product: productLow,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows sold out chip correctly', (WidgetTester tester) async {
      final productOut = Product.fromJson({
        'id': 'drink-4',
        'name': 'Gone Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'status_text': 'Sold out',
      });

      final drink = Drink(
        product: productOut,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Sold Out'), findsOneWidget);
    });

    testWidgets('handles drink without availability status', (
      WidgetTester tester,
    ) async {
      final productNoStatus = Product.fromJson({
        'id': 'drink-5',
        'name': 'No Status Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
      });

      final drink = Drink(
        product: productNoStatus,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      // Should render without availability chip
      expect(find.text('Available'), findsNothing);
      expect(find.text('Low'), findsNothing);
      expect(find.text('Sold Out'), findsNothing);
    });

    testWidgets('formats dispense method with capital first letter', (
      WidgetTester tester,
    ) async {
      final productKeg = Product.fromJson({
        'id': 'drink-6',
        'name': 'Keg Beer',
        'category': 'beer',
        'dispense': 'keg',
        'abv': '5.0',
      });

      final drink = Drink(
        product: productKeg,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Keg'), findsOneWidget);
      expect(find.text('keg'), findsNothing);
    });
  });

  group('DrinkCard accent bar', () {
    Drink drinkWithCategory(String category) {
      final product = Product.fromJson({
        'id': 'drink-accent',
        'name': 'Accent Test',
        'category': category,
        'dispense': 'cask',
        'abv': '4.0',
      });
      return Drink(
        product: product,
        producer: testProducer,
        festivalId: 'cbf2025',
      );
    }

    Color? accentBorderColor(WidgetTester tester) {
      for (final c in tester.widgetList<Container>(find.byType(Container))) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border) {
            final left = border.left;
            if (left.width == 4) return left.color;
          }
        }
      }
      return null;
    }

    testWidgets('cider uses green accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('cider')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF22C55E)));
    });

    testWidgets('perry uses lime accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('perry')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF84CC16)));
    });

    testWidgets('mead uses gold accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('mead')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFFD97706)));
    });

    testWidgets('wine uses purple accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('wine')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF9333EA)));
    });

    testWidgets('international-beer uses red accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('international-beer')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFFEF4444)));
    });

    testWidgets('low-no uses cyan accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('low-no')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF06B6D4)));
    });

    testWidgets('apple-juice uses apple-green accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('apple-juice')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF65A30D)));
    });

    testWidgets('unknown category uses navy fallback accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('unknown-type')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF2B3170)));
    });
  });

  group('DrinkCard status badge (#413)', () {
    // These tests use a product with no `status_text`, so DrinkCard never
    // renders an `_AvailabilityChip` — that chip also uses `Icons.check_circle`
    // for the "plenty" status, which would collide with the tasted badge's
    // icon in `find.byIcon` assertions.
    Product noStatusProduct() => Product.fromJson({
      'id': 'drink-badge',
      'name': 'Badge Test Beer',
      'category': 'beer',
      'dispense': 'cask',
      'abv': '4.5',
    });

    Drink drinkWithState({bool wantToTry = false, List<DateTime>? tasted}) {
      return Drink(
        product: noStatusProduct(),
        producer: testProducer,
        festivalId: 'cbf2025',
        userState: UserDrinkState.initial().copyWith(
          wantToTry: wantToTry,
          tastingEvents: tasted ?? const [],
        ),
      );
    }

    testWidgets('renders no badge when neither wanted nor tasted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: drinkWithState()));

      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('renders grey circle-outline badge for want-to-try', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(wantToTry: true);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('renders green check for tasted once (no count text)', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(tasted: [DateTime(2026, 7, 1)]);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      expect(find.text('1×'), findsNothing);
    });

    testWidgets('renders green check plus "3×" count for multiple tastings', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        tasted: [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
        ],
      );
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('3×'), findsOneWidget);
    });

    testWidgets('tasted badge takes priority when also want-to-try', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        wantToTry: true,
        tasted: [DateTime(2026, 7, 1)],
      );
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('want-to-try badge has a descriptive Semantics label', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(wantToTry: true);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Want to try',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tasted-once badge has a descriptive Semantics label', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(tasted: [DateTime(2026, 7, 1)]);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Tasted',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tasted-3-times badge has a descriptive Semantics label', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        tasted: [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
        ],
      );
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Tasted 3 times',
        ),
        findsOneWidget,
      );
    });

    testWidgets('card semantic label appends want-to-try state', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(wantToTry: true);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('Added to want to try') ??
                  false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('card semantic label appends tasted-once state', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(tasted: [DateTime(2026, 7, 1)]);
      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('Tasted once') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('card semantic label appends tasted-3-times state', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        tasted: [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
        ],
      );
      await tester.pumpWidget(createTestWidget(drink: drink));

      // Both the aggregated card label and the badge's own Semantics label
      // legitimately contain "Tasted 3 times" here — see AGENTS.md's
      // "duplicate semantics nodes" gotcha — so assert findsWidgets rather
      // than findsOneWidget.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('Tasted 3 times') ?? false),
        ),
        findsWidgets,
      );
    });

    testWidgets('card semantic label omits status clause when unflagged', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: drinkWithState()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('want to try') ?? false),
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('Tasted') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('want-to-try badge - light theme', (WidgetTester tester) async {
      final drink = drinkWithState(wantToTry: true);
      await tester.binding.setSurfaceSize(const Size(400, 200));
      await tester.pumpWidget(createTestWidget(drink: drink));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinkCard),
        matchesGoldenFile('goldens/drink_card_want_to_try_light.png'),
      );
    });

    testWidgets('tasted multiple badge - light theme', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        tasted: [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(400, 200));
      await tester.pumpWidget(createTestWidget(drink: drink));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinkCard),
        matchesGoldenFile('goldens/drink_card_tasted_multiple_light.png'),
      );
    });

    testWidgets('tasted multiple badge - dark theme', (
      WidgetTester tester,
    ) async {
      final drink = drinkWithState(
        tasted: [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(400, 200));
      await tester.pumpWidget(
        createTestWidget(drink: drink, brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinkCard),
        matchesGoldenFile('goldens/drink_card_tasted_multiple_dark.png'),
      );
    });
  });

  group('DrinkCard search decoration', () {
    Drink describedDrink({
      String name = 'Mystery Mild',
      String? description = 'A rich chocolate finish with roasted malt',
      String? userNote,
    }) {
      final now = DateTime(2026, 6, 10);
      return Drink(
        product: Product.fromJson({
          'id': 'drink-x',
          'name': name,
          'category': 'beer',
          'style': 'Mild',
          'dispense': 'cask',
          'abv': '3.4',
          if (description != null) 'notes': description,
        }),
        producer: testProducer,
        festivalId: 'cbf2025',
        userState: userNote == null
            ? null
            : UserDrinkState(notes: userNote, createdAt: now, updatedAt: now),
      );
    }

    // A tall surface so the optional excerpt line never overflows the golden
    // tests' leftover 400x200 surface (real cards live in a scrollable list).
    Future<void> pump(
      WidgetTester tester,
      Drink drink, {
      String searchQuery = '',
    }) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        createTestWidget(drink: drink, searchQuery: searchQuery),
      );
    }

    testWidgets('highlights the matched query within the drink name', (
      tester,
    ) async {
      await pump(tester, testDrink, searchQuery: 'ipa');

      // Full name is still resolvable via the Text.rich plain-text form.
      expect(find.text('Test IPA'), findsOneWidget);

      final nameWidget = tester.widget<Text>(find.text('Test IPA'));
      final root = nameWidget.textSpan! as TextSpan;
      final highlighted = <String>[];
      root.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor != null) {
          highlighted.add(span.text ?? '');
        }
        return true;
      });
      expect(highlighted, contains('IPA'));
    });

    testWidgets(
      'shows a match excerpt when the query matches the description',
      (tester) async {
        await pump(tester, describedDrink(), searchQuery: 'chocolate');

        expect(find.textContaining('chocolate'), findsOneWidget);
      },
    );

    testWidgets('shows a match excerpt when the query matches the user note', (
      tester,
    ) async {
      await pump(
        tester,
        describedDrink(description: null, userNote: 'Reminded me of Prague'),
        searchQuery: 'prague',
      );

      expect(find.textContaining('Prague'), findsOneWidget);
    });

    testWidgets('suppresses the excerpt when the query matches a visible field', (
      tester,
    ) async {
      // Query hits the name (visible) and the description (hidden). The visible
      // match is self-evident, so no excerpt line is added.
      await pump(
        tester,
        describedDrink(
          name: 'Chocolate Stout',
          description: 'a chocolate bomb',
        ),
        searchQuery: 'chocolate',
      );

      expect(find.textContaining('bomb'), findsNothing);
    });

    testWidgets('adds no highlight or excerpt when there is no query', (
      tester,
    ) async {
      await pump(tester, describedDrink());

      // Description is not surfaced, and the name renders as a plain Text.
      expect(find.textContaining('chocolate'), findsNothing);
      final nameWidget = tester.widget<Text>(find.text('Mystery Mild'));
      expect(nameWidget.textSpan, isNull);
      expect(nameWidget.data, 'Mystery Mild');
    });

    testWidgets('exposes the excerpt in the card Semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pump(tester, describedDrink(), searchQuery: 'chocolate');

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('matching text:') ??
                    false) &&
                (widget.properties.label?.toLowerCase().contains('chocolate') ??
                    false),
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('highlight + excerpt - light theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        createTestWidget(drink: describedDrink(), searchQuery: 'chocolate'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinkCard),
        matchesGoldenFile('goldens/drink_card_search_excerpt_light.png'),
      );
    });

    testWidgets('highlight + excerpt - dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        createTestWidget(
          drink: describedDrink(),
          searchQuery: 'chocolate',
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinkCard),
        matchesGoldenFile('goldens/drink_card_search_excerpt_dark.png'),
      );
    });
  });
}
