import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/preference_keys.dart';
import '../models/drink_visibility_filter.dart';

/// Owns all SharedPreferences I/O for the three user-level preference groups:
/// theme mode, drink-visibility filters, and allergen exclusions.
///
/// Pure application logic: no Flutter UI or analytics dependencies, so it can
/// be unit-tested in isolation. [BeerProvider] composes this controller,
/// creates it with an already-open [SharedPreferences] instance, and calls
/// [hydrate] once at startup to restore saved state.
class UserPreferencesController {
  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;

  UserPreferencesController(this._prefs);

  ThemeMode get themeMode => _themeMode;

  /// Reads all preference fields from SharedPreferences and returns them as a
  /// named record so [BeerProvider] can pass the values to other controllers.
  ///
  /// Also updates [themeMode] on this controller so callers can access it via
  /// the getter after hydration.
  ({
    ThemeMode themeMode,
    Set<DrinkVisibilityFilter> visibilityFilters,
    Set<String> excludedAllergens,
  })
  hydrate() {
    // Theme mode
    final themeIndex =
        _prefs.getInt(PreferenceKeys.themeMode) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Visibility filters (with migration from legacy hideUnavailable key)
    final visibilityFilters = <DrinkVisibilityFilter>{};
    final savedFilters = _prefs.getStringList(PreferenceKeys.visibilityFilters);
    if (savedFilters != null) {
      for (final name in savedFilters) {
        final filter = DrinkVisibilityFilter.values.firstWhereOrNull(
          (f) => f.name == name,
        );
        if (filter != null) visibilityFilters.add(filter);
      }
    } else {
      // Migrate from legacy 'hideUnavailable' boolean preference
      if (_prefs.getBool(PreferenceKeys.hideUnavailableLegacy) ?? false) {
        visibilityFilters.add(DrinkVisibilityFilter.availableOnly);
      }
    }

    // Excluded allergens
    final excludedAllergens = Set<String>.from(
      _prefs.getStringList(PreferenceKeys.excludedAllergens) ?? [],
    );

    return (
      themeMode: _themeMode,
      visibilityFilters: visibilityFilters,
      excludedAllergens: excludedAllergens,
    );
  }

  /// Persist [mode] and update the in-memory [themeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(PreferenceKeys.themeMode, mode.index);
  }

  /// Persist the full set of active visibility [filters].
  Future<void> persistVisibilityFilters(
    Set<DrinkVisibilityFilter> filters,
  ) async {
    await _prefs.setStringList(
      PreferenceKeys.visibilityFilters,
      filters.map((f) => f.name).toList(),
    );
  }

  /// Persist the full set of excluded [allergens].
  Future<void> persistAllergens(Set<String> allergens) async {
    await _prefs.setStringList(
      PreferenceKeys.excludedAllergens,
      allergens.toList(),
    );
  }
}
