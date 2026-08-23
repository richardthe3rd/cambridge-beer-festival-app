import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/preference_keys.dart';
import '../models/drink_visibility_filter.dart';

/// Owns all SharedPreferences I/O for the three user-level preference groups:
/// theme mode, drink-visibility filters, and allergen exclusions.
///
/// Pure Dart: no Flutter UI dependencies, so it can be unit-tested in
/// isolation without the Flutter test binding. [BeerProvider] composes this
/// controller, creates it with an already-open [SharedPreferences] instance,
/// and calls [hydrate] once at startup to restore saved state.
class UserPreferencesController {
  final SharedPreferences _prefs;

  UserPreferencesController(this._prefs);

  /// Ids of every currently-shipped colour theme (`AppColorTheme.id` in
  /// `lib/app_theme.dart`). Duplicated here — rather than importing
  /// `app_theme.dart`, which pulls in Flutter — so this controller stays
  /// pure Dart, matching every other controller in `lib/domain/`.
  /// `user_preferences_controller_test.dart` cross-checks this set (and
  /// [defaultThemePaletteId]) against the real catalogue so the two cannot
  /// silently drift.
  static const knownThemePaletteIds = <String>{'cbfNavy', 'chalk'};

  /// The theme id restored when no preference is stored, or the stored id
  /// is unrecognised. Mirrors `defaultAppColorTheme.id` in
  /// `lib/app_theme.dart`.
  static const defaultThemePaletteId = 'cbfNavy';

  /// Reads all preference fields from SharedPreferences and returns them as a
  /// named record so [BeerProvider] can pass the values to other controllers.
  ///
  /// The theme preference is returned as an int index (matching
  /// [ThemeMode.index]) so this class stays free of Flutter dependencies.
  /// [BeerProvider] is responsible for converting it to a [ThemeMode] value.
  ({
    int themeIndex,
    String themePaletteId,
    Set<DrinkVisibilityFilter> visibilityFilters,
    Set<String> excludedAllergens,
  })
  hydrate() {
    // Theme mode — return the raw index; 0 == ThemeMode.system.
    // Clamp to [0, 2] so an out-of-range stored value falls back to system.
    final rawIndex = _prefs.getInt(PreferenceKeys.themeMode) ?? 0;
    final themeIndex = (rawIndex >= 0 && rawIndex <= 2) ? rawIndex : 0;

    // Colour theme — an unknown or missing id falls back to the default,
    // mirroring the themeIndex clamp above.
    final rawPaletteId = _prefs.getString(PreferenceKeys.themePalette);
    final themePaletteId = knownThemePaletteIds.contains(rawPaletteId)
        ? rawPaletteId!
        : defaultThemePaletteId;

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
      themeIndex: themeIndex,
      themePaletteId: themePaletteId,
      visibilityFilters: visibilityFilters,
      excludedAllergens: excludedAllergens,
    );
  }

  /// Persist [themeIndex] (a [ThemeMode.index] value) to SharedPreferences.
  Future<void> persistThemeMode(int themeIndex) async {
    await _prefs.setInt(PreferenceKeys.themeMode, themeIndex);
  }

  /// Persist the selected colour theme [id] (an `AppColorTheme.id`).
  Future<void> persistThemePalette(String id) async {
    await _prefs.setString(PreferenceKeys.themePalette, id);
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
