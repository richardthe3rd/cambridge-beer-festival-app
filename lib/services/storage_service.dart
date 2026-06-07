import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preference_keys.dart';

/// Service for managing festival selection persistence
class FestivalStorageService {
  static const _selectedFestivalKey = PreferenceKeys.selectedFestivalId;

  final SharedPreferences _prefs;

  FestivalStorageService(this._prefs);

  /// Get the ID of the last selected festival
  String? getSelectedFestivalId() {
    return _prefs.getString(_selectedFestivalKey);
  }

  /// Save the selected festival ID
  Future<void> setSelectedFestivalId(String festivalId) async {
    await _prefs.setString(_selectedFestivalKey, festivalId);
  }

  /// Clear the selected festival
  Future<void> clearSelectedFestival() async {
    await _prefs.remove(_selectedFestivalKey);
  }
}
