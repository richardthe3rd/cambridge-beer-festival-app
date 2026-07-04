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
      expect(PreferenceKeys.hideUnavailableLegacy, 'hideUnavailable');
      expect(PreferenceKeys.excludedAllergens, 'excludedAllergens');
      expect(PreferenceKeys.userStatePrefix, 'user_state_');
      expect(PreferenceKeys.logEntryPrefix, 'log_entry_');
      expect(PreferenceKeys.wantToTryPrefix, 'want_to_try_');
      expect(
        PreferenceKeys.legacyMigrationComplete,
        'personal_state_migration_v1',
      );
      expect(
        PreferenceKeys.logEntryMigrationComplete,
        'my_festival_migration_v2',
      );
      expect(PreferenceKeys.favoritesLegacy, 'favorites');
      expect(PreferenceKeys.ratingsLegacy, 'ratings');
      expect(PreferenceKeys.tastingLogLegacyPrefix, 'tasting_log_');
      expect(PreferenceKeys.selectedFestivalId, 'selected_festival_id');
      expect(PreferenceKeys.drinksCachePrefix, 'drinks_cache');
      expect(PreferenceKeys.festivalsCache, 'festivals_cache');
    });

    test('keys are unique', () {
      final keys = <String>[
        PreferenceKeys.themeMode,
        PreferenceKeys.visibilityFilters,
        PreferenceKeys.hideUnavailableLegacy,
        PreferenceKeys.excludedAllergens,
        PreferenceKeys.userStatePrefix,
        PreferenceKeys.logEntryPrefix,
        PreferenceKeys.wantToTryPrefix,
        PreferenceKeys.legacyMigrationComplete,
        PreferenceKeys.logEntryMigrationComplete,
        PreferenceKeys.favoritesLegacy,
        PreferenceKeys.ratingsLegacy,
        PreferenceKeys.tastingLogLegacyPrefix,
        PreferenceKeys.selectedFestivalId,
        PreferenceKeys.drinksCachePrefix,
        PreferenceKeys.festivalsCache,
      ];
      expect(keys.toSet().length, keys.length);
    });
  });
}
