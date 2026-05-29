import 'package:cambridge_beer_festival/constants/preference_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // These literals are part of the on-disk SharedPreferences format. Changing a
  // value orphans data already stored under the old key, so this test pins each
  // one: a failure here means a migration is required, not a casual edit.
  group('PreferenceKeys', () {
    test('key values match the shipped on-disk format', () {
      expect(PreferenceKeys.themeMode, 'themeMode');
      expect(PreferenceKeys.visibilityFilters, 'visibilityFilters');
      expect(PreferenceKeys.excludedAllergens, 'excludedAllergens');
      expect(PreferenceKeys.favorites, 'favorites');
      expect(PreferenceKeys.ratings, 'ratings');
      expect(PreferenceKeys.selectedFestivalId, 'selected_festival_id');
      expect(PreferenceKeys.tastingLogPrefix, 'tasting_log_');
      expect(PreferenceKeys.drinksCachePrefix, 'drinks_cache');
      expect(PreferenceKeys.festivalsCache, 'festivals_cache');
    });

    test('keys are unique', () {
      final keys = <String>[
        PreferenceKeys.themeMode,
        PreferenceKeys.visibilityFilters,
        PreferenceKeys.excludedAllergens,
        PreferenceKeys.favorites,
        PreferenceKeys.ratings,
        PreferenceKeys.selectedFestivalId,
        PreferenceKeys.tastingLogPrefix,
        PreferenceKeys.drinksCachePrefix,
        PreferenceKeys.festivalsCache,
      ];
      expect(keys.toSet().length, keys.length);
    });
  });
}
