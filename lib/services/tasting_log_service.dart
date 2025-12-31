import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking which drinks a user has tasted at festivals
///
/// Stores tasting logs with timestamps, allowing users to mark drinks
/// they've tried during a festival session.
class TastingLogService {
  static const String _tastingLogPrefix = 'tasting_log_';

  final SharedPreferences _prefs;

  TastingLogService(this._prefs);

  /// Get the storage key for a drink's tasting log
  String _getKey(String festivalId, String drinkId) {
    return '$_tastingLogPrefix${festivalId}_$drinkId';
  }

  /// Check if a drink has been tasted at a specific festival
  bool hasTasted(String festivalId, String drinkId) {
    final key = _getKey(festivalId, drinkId);
    return _prefs.containsKey(key);
  }

  /// Get the timestamp when a drink was tasted (null if not tasted)
  DateTime? getTastedTimestamp(String festivalId, String drinkId) {
    final key = _getKey(festivalId, drinkId);
    final timestamp = _prefs.getInt(key);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Mark a drink as tasted with current timestamp
  Future<void> markAsTasted(String festivalId, String drinkId) async {
    final key = _getKey(festivalId, drinkId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(key, timestamp);
  }

  /// Unmark a drink as tasted
  Future<void> unmarkAsTasted(String festivalId, String drinkId) async {
    final key = _getKey(festivalId, drinkId);
    await _prefs.remove(key);
  }

  /// Toggle tasted status for a drink
  Future<void> toggleTasted(String festivalId, String drinkId) async {
    if (hasTasted(festivalId, drinkId)) {
      await unmarkAsTasted(festivalId, drinkId);
    } else {
      await markAsTasted(festivalId, drinkId);
    }
  }

  /// Get all tasted drink IDs for a specific festival
  List<String> getTastedDrinkIds(String festivalId) {
    final prefix = '$_tastingLogPrefix$festivalId';
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix));
    return keys.map((k) => k.replaceFirst('${prefix}_', '')).toList();
  }

  /// Get count of tasted drinks for a festival
  int getTastedCount(String festivalId) {
    return getTastedDrinkIds(festivalId).length;
  }

  /// Clear all tasting logs for a specific festival
  Future<void> clearFestivalLog(String festivalId) async {
    final prefix = '$_tastingLogPrefix$festivalId';
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Clear all tasting logs across all festivals
  Future<void> clearAllLogs() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_tastingLogPrefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
