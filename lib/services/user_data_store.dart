import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preference_keys.dart';
import '../models/models.dart';

/// Persists the unified per-drink personal record ([UserDrinkState]).
///
/// One structured JSON entry per drink-per-festival, replacing the three
/// separate key schemes previously hand-rolled by `FavoritesService`,
/// `RatingsService`, and `TastingLogService`. Keeping all personal data behind
/// a single store gives later work a clean seam: a synced backend (vision
/// Phase 3) becomes a constructor swap, and personal data can be enumerated for
/// a festival without the catalogue being loaded (see [readAll]).
///
/// Entries are pruned when they carry no user signal ([UserDrinkState.isEmpty]),
/// so an unrated, un-flagged drink leaves no key behind.
class SharedPreferencesUserDataStore {
  static const String _prefix = PreferenceKeys.userStatePrefix;

  final SharedPreferences _prefs;

  SharedPreferencesUserDataStore(this._prefs);

  String _key(String festivalId, String drinkId) =>
      '$_prefix${festivalId}_$drinkId';

  String _festivalPrefix(String festivalId) => '$_prefix${festivalId}_';

  /// Read the stored record for a drink, or null if none exists.
  UserDrinkState? read(String festivalId, String drinkId) {
    return _decode(_prefs.getString(_key(festivalId, drinkId)));
  }

  /// Persist a record, or remove the entry entirely when it is empty.
  Future<void> write(
    String festivalId,
    String drinkId,
    UserDrinkState state,
  ) async {
    final key = _key(festivalId, drinkId);
    if (state.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, jsonEncode(state.toJson()));
  }

  /// Remove a drink's record.
  Future<void> remove(String festivalId, String drinkId) async {
    await _prefs.remove(_key(festivalId, drinkId));
  }

  /// All records for a festival, keyed by drink ID.
  ///
  /// This is the catalogue-independent query: it answers "which drinks do I
  /// have state for in festival X?" without any drinks being loaded. Corrupt
  /// entries are skipped rather than throwing.
  Map<String, UserDrinkState> readAll(String festivalId) {
    final prefix = _festivalPrefix(festivalId);
    final result = <String, UserDrinkState>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final state = _decode(_prefs.getString(key));
      if (state != null) result[key.substring(prefix.length)] = state;
    }
    return result;
  }

  /// Clear every record for a festival.
  Future<void> clearFestival(String festivalId) async {
    final prefix = _festivalPrefix(festivalId);
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  UserDrinkState? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return UserDrinkState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A malformed entry is treated as absent rather than crashing the load.
      return null;
    }
  }
}
