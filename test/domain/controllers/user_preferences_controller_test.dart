import 'package:cambridge_beer_festival/constants/preference_keys.dart';
import 'package:cambridge_beer_festival/domain/controllers/user_preferences_controller.dart';
import 'package:cambridge_beer_festival/domain/models/drink_visibility_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late UserPreferencesController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    controller = UserPreferencesController(prefs);
  });

  group('initial state', () {
    test('themeMode is ThemeMode.system before hydrate', () {
      expect(controller.themeMode, ThemeMode.system);
    });
  });

  group('hydrate', () {
    test('returns ThemeMode.system when no key stored', () async {
      final result = controller.hydrate();
      expect(result.themeMode, ThemeMode.system);
      expect(result.visibilityFilters, isEmpty);
      expect(result.excludedAllergens, isEmpty);
    });

    test('restores persisted ThemeMode.dark', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.themeMode: ThemeMode.dark.index,
      });
      final prefs = await SharedPreferences.getInstance();
      controller = UserPreferencesController(prefs);

      final result = controller.hydrate();
      expect(result.themeMode, ThemeMode.dark);
    });

    test('restores persisted ThemeMode.light', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.themeMode: ThemeMode.light.index,
      });
      final prefs = await SharedPreferences.getInstance();
      controller = UserPreferencesController(prefs);

      final result = controller.hydrate();
      expect(result.themeMode, ThemeMode.light);
    });

    test('restores persisted visibilityFilters', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.visibilityFilters: ['availableOnly'],
      });
      final prefs = await SharedPreferences.getInstance();
      controller = UserPreferencesController(prefs);

      final result = controller.hydrate();
      expect(
        result.visibilityFilters,
        contains(DrinkVisibilityFilter.availableOnly),
      );
    });

    test('ignores unknown filter names', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.visibilityFilters: ['unknownFilter'],
      });
      final prefs = await SharedPreferences.getInstance();
      controller = UserPreferencesController(prefs);

      final result = controller.hydrate();
      expect(result.visibilityFilters, isEmpty);
    });

    test(
      'migrates legacy hideUnavailable=true when visibilityFilters key absent',
      () async {
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.hideUnavailableLegacy: true,
        });
        final prefs = await SharedPreferences.getInstance();
        controller = UserPreferencesController(prefs);

        final result = controller.hydrate();
        expect(
          result.visibilityFilters,
          contains(DrinkVisibilityFilter.availableOnly),
        );
      },
    );

    test(
      'does not migrate legacy when visibilityFilters key is present',
      () async {
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.visibilityFilters: [],
          PreferenceKeys.hideUnavailableLegacy: true,
        });
        final prefs = await SharedPreferences.getInstance();
        controller = UserPreferencesController(prefs);

        final result = controller.hydrate();
        // The new key wins — migration is NOT applied
        expect(result.visibilityFilters, isEmpty);
      },
    );

    test('restores excludedAllergens', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.excludedAllergens: ['gluten', 'nuts'],
      });
      final prefs = await SharedPreferences.getInstance();
      controller = UserPreferencesController(prefs);

      final result = controller.hydrate();
      expect(result.excludedAllergens, containsAll(['gluten', 'nuts']));
    });

    test('sets themeMode on controller after hydrate', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.themeMode: ThemeMode.dark.index,
      });
      final prefs = await SharedPreferences.getInstance();
      final c = UserPreferencesController(prefs)..hydrate();

      expect(c.themeMode, ThemeMode.dark);
    });
  });

  group('setThemeMode', () {
    test('persists theme index to prefs', () async {
      await controller.setThemeMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PreferenceKeys.themeMode), ThemeMode.dark.index);
    });

    test('updates themeMode getter', () async {
      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
    });

    test('round-trip: dark then light', () async {
      await controller.setThemeMode(ThemeMode.dark);
      await controller.setThemeMode(ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PreferenceKeys.themeMode), ThemeMode.light.index);
    });
  });

  group('persistVisibilityFilters', () {
    test('writes filter names to prefs', () async {
      await controller.persistVisibilityFilters({
        DrinkVisibilityFilter.availableOnly,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.visibilityFilters), [
        'availableOnly',
      ]);
    });

    test('writes empty list when set is empty', () async {
      await controller.persistVisibilityFilters({});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.visibilityFilters), isEmpty);
    });
  });

  group('persistAllergens', () {
    test('writes allergen names to prefs', () async {
      await controller.persistAllergens({'gluten', 'sulphites'});

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(PreferenceKeys.excludedAllergens);
      expect(stored, containsAll(['gluten', 'sulphites']));
    });

    test('writes empty list when set is empty', () async {
      await controller.persistAllergens({});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PreferenceKeys.excludedAllergens), isEmpty);
    });
  });
}
