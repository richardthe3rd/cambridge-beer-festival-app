import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing feature tour state
class TourService {
  static const _tourKey = 'has_seen_tour';

  final SharedPreferences _prefs;

  TourService(this._prefs);

  /// Check if the user has seen the feature tour
  bool hasSeen() {
    return _prefs.getBool(_tourKey) ?? false;
  }

  /// Mark the tour as seen
  Future<void> markAsSeen() async {
    await _prefs.setBool(_tourKey, true);
  }

  /// Reset tour state (useful for testing or if user wants to see it again)
  Future<void> reset() async {
    await _prefs.setBool(_tourKey, false);
  }
}
