import 'package:cambridge_beer_festival/constants/preference_keys.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'beer_provider_test.dart' show createSampleDrinks;
import 'provider_test.mocks.dart';

/// The category selection is a saved preference, not session state: it is
/// restored at startup, rewritten whenever the user changes it, and survives a
/// festival switch. The first-run flow ([BeerProvider.applyOnboardingPreferences])
/// is just one writer of it.
void main() {
  late MockDrinkRepository mockDrinkRepository;
  late MockFestivalRepository mockFestivalRepository;
  late MockAnalyticsService mockAnalyticsService;
  late BeerProvider provider;

  final cbf2025 = DefaultFestivals.cambridge2025;
  final cbf2024 = DefaultFestivals.all.firstWhere((f) => f.id != cbf2025.id);

  void stubRepositories() {
    when(mockFestivalRepository.getFestivals()).thenAnswer(
      (_) async => FestivalsResponse(
        festivals: [cbf2025, cbf2024],
        defaultFestivalId: cbf2025.id,
        version: '1.0',
        baseUrl: 'https://data.cambeerfestival.app',
      ),
    );
    when(
      mockFestivalRepository.getSelectedFestivalId(),
    ).thenAnswer((_) async => null);
    when(
      mockFestivalRepository.getCachedFestivals(),
    ).thenAnswer((_) async => null);
    when(
      mockDrinkRepository.getDrinks(any),
    ).thenAnswer((_) async => createSampleDrinks());
    when(
      mockDrinkRepository.getCachedDrinks(any),
    ).thenAnswer((_) async => null);
  }

  BeerProvider buildProvider() => BeerProvider(
    drinkRepository: mockDrinkRepository,
    festivalRepository: mockFestivalRepository,
    analyticsService: mockAnalyticsService,
  );

  setUp(() {
    mockDrinkRepository = MockDrinkRepository();
    mockFestivalRepository = MockFestivalRepository();
    mockAnalyticsService = MockAnalyticsService();
    SharedPreferences.setMockInitialValues({});
    stubRepositories();
    provider = buildProvider();
  });

  tearDown(() {
    provider.dispose();
  });

  group('onboarding flag', () {
    test('is false on a fresh install', () async {
      await provider.initialize();

      expect(provider.hasCompletedOnboarding, isFalse);
    });

    test('is restored from a previous run', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.onboardingComplete: true,
      });
      provider.dispose();
      provider = buildProvider();

      await provider.initialize();

      expect(provider.hasCompletedOnboarding, isTrue);
    });

    test('skipOnboarding records the flag without touching filters', () async {
      await provider.initialize();
      await provider.loadDrinks();
      final before = provider.drinks.length;

      await provider.skipOnboarding();

      expect(provider.hasCompletedOnboarding, isTrue);
      expect(provider.selectedCategories, isEmpty);
      expect(provider.drinks, hasLength(before));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PreferenceKeys.onboardingComplete), isTrue);
    });

    test('survives a restart once skipped', () async {
      await provider.initialize();
      await provider.skipOnboarding();

      provider.dispose();
      provider = buildProvider();
      await provider.initialize();

      expect(provider.hasCompletedOnboarding, isTrue);
    });
  });

  group('applyOnboardingPreferences', () {
    test('narrows the visible list to the chosen categories', () async {
      await provider.initialize();
      await provider.loadDrinks();
      expect(provider.drinks.map((d) => d.name), contains('Alpha Ale'));

      await provider.applyOnboardingPreferences(
        categories: {'cider'},
        visibilityFilters: const {},
      );

      // Assert what the user sees, not just the filter field: the two ciders
      // remain and both beers are gone.
      expect(provider.drinks.map((d) => d.name), [
        'Crisp Cider',
        'Zesty Zider',
      ]);
      expect(provider.selectedCategories, {'cider'});
      expect(provider.hasCompletedOnboarding, isTrue);
    });

    test('an empty selection leaves every drink visible', () async {
      await provider.initialize();
      await provider.loadDrinks();

      await provider.applyOnboardingPreferences(
        categories: const {},
        visibilityFilters: const {},
      );

      expect(provider.drinks, hasLength(4));
      expect(provider.selectedCategories, isEmpty);
    });

    test('applies the chosen visibility filters too', () async {
      await provider.initialize();

      await provider.applyOnboardingPreferences(
        categories: const {},
        visibilityFilters: const {DrinkVisibilityFilter.veganOnly},
      );

      expect(provider.visibilityFilters, {DrinkVisibilityFilter.veganOnly});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.visibilityFilters), [
        'veganOnly',
      ]);
    });

    test('the choice is still applied after a restart', () async {
      await provider.initialize();
      await provider.applyOnboardingPreferences(
        categories: {'cider'},
        visibilityFilters: const {DrinkVisibilityFilter.availableOnly},
      );

      provider.dispose();
      provider = buildProvider();
      await provider.initialize();
      await provider.loadDrinks();

      expect(provider.selectedCategories, {'cider'});
      expect(provider.visibilityFilters, {DrinkVisibilityFilter.availableOnly});
      expect(provider.drinks.map((d) => d.name), isNot(contains('Alpha Ale')));
    });
  });

  group('category selection persistence', () {
    test('toggleCategory writes the new selection', () async {
      await provider.initialize();

      provider.toggleCategory('cider');
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.selectedCategories), ['cider']);
    });

    test('clearCategories writes the empty selection', () async {
      await provider.initialize();
      provider.toggleCategory('cider');
      await pumpEventQueue();

      provider.clearCategories();
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.selectedCategories), isEmpty);
    });

    test('selectOnlyCategory replaces the stored selection', () async {
      await provider.initialize();
      provider.toggleCategory('beer');
      await pumpEventQueue();

      provider.selectOnlyCategory('cider');
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.selectedCategories), ['cider']);
    });

    test(
      'a stored selection is applied to the drinks list at startup',
      () async {
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.selectedCategories: ['cider'],
          PreferenceKeys.onboardingComplete: true,
        });
        provider.dispose();
        provider = buildProvider();

        await provider.initialize();
        await provider.loadDrinks();

        expect(provider.selectedCategories, {'cider'});
        expect(provider.drinks.map((d) => d.name), [
          'Crisp Cider',
          'Zesty Zider',
        ]);
      },
    );

    test('survives a festival switch, unlike style and search', () async {
      await provider.initialize();
      await provider.loadDrinks();
      provider
        ..toggleCategory('cider')
        ..toggleStyle('Dry')
        ..setSearchQuery('crisp');
      await pumpEventQueue();

      await provider.setFestival(cbf2024);

      expect(provider.selectedCategories, {'cider'});
      expect(provider.selectedStyles, isEmpty);
      expect(provider.searchQuery, isEmpty);
      // And it is really applied to the new festival's catalogue, not just
      // held in the field.
      expect(provider.drinks.map((d) => d.name), [
        'Crisp Cider',
        'Zesty Zider',
      ]);
    });
  });
}
