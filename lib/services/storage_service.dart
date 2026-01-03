import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for managing favorites locally with My Festival tracking
class FavoritesService {
  static const _favoritesKey = 'favorites';

  final SharedPreferences _prefs;

  FavoritesService(this._prefs);

  /// Get all favorite items for a festival
  Map<String, FavoriteItem> getFavorites(String festivalId) {
    final key = '${_favoritesKey}_$festivalId';
    final data = _prefs.getString(key);

    if (data == null || data.isEmpty) {
      return {}; // Empty map for new users
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return json.map(
        (key, value) => MapEntry(
          key,
          FavoriteItem.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      return {}; // Return empty on error (corrupted data)
    }
  }

  /// Save all favorites for a festival
  Future<void> saveFavorites(
    String festivalId,
    Map<String, FavoriteItem> favorites,
  ) async {
    final key = '${_favoritesKey}_$festivalId';
    final json = favorites.map((key, value) => MapEntry(key, value.toJson()));
    await _prefs.setString(key, jsonEncode(json));
  }

  /// Add a drink to favorites (want to try status)
  Future<void> addFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    final now = DateTime.now();

    favorites[drinkId] = FavoriteItem(
      id: drinkId,
      status: FavoriteStatus.wantToTry,
      tries: [],
      createdAt: now,
      updatedAt: now,
    );

    await saveFavorites(festivalId, favorites);
  }

  /// Remove a drink from favorites
  Future<void> removeFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    favorites.remove(drinkId);
    await saveFavorites(festivalId, favorites);
  }

  /// Toggle favorite status (add to want to try or remove from log)
  Future<bool> toggleFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    final isFavorite = favorites.containsKey(drinkId);

    if (isFavorite) {
      favorites.remove(drinkId);
    } else {
      final now = DateTime.now();
      favorites[drinkId] = FavoriteItem(
        id: drinkId,
        status: FavoriteStatus.wantToTry,
        tries: [],
        createdAt: now,
        updatedAt: now,
      );
    }

    await saveFavorites(festivalId, favorites);
    return !isFavorite;
  }

  /// Check if a drink is a favorite (in festival log)
  bool isFavorite(String festivalId, String drinkId) {
    return getFavorites(festivalId).containsKey(drinkId);
  }

  /// Get favorite item for a drink
  FavoriteItem? getFavoriteItem(String festivalId, String drinkId) {
    return getFavorites(festivalId)[drinkId];
  }

  /// Mark a drink as tasted (adds timestamp)
  Future<void> markAsTasted(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    final existing = favorites[drinkId];
    final now = DateTime.now();

    if (existing == null) {
      // Not in log yet, add as tasted
      favorites[drinkId] = FavoriteItem(
        id: drinkId,
        status: FavoriteStatus.tasted,
        tries: [now],
        createdAt: now,
        updatedAt: now,
      );
    } else {
      // Already in log, add timestamp and update status
      favorites[drinkId] = existing.copyWith(
        status: FavoriteStatus.tasted,
        tries: [...existing.tries, now],
        updatedAt: now,
      );
    }

    await saveFavorites(festivalId, favorites);
  }

  /// Delete a specific tasting timestamp
  Future<void> deleteTry(
    String festivalId,
    String drinkId,
    DateTime timestamp,
  ) async {
    final favorites = getFavorites(festivalId);
    final existing = favorites[drinkId];
    if (existing == null) return;

    final updatedTries = existing.tries
        .where((t) => t.millisecondsSinceEpoch != timestamp.millisecondsSinceEpoch)
        .toList();

    if (updatedTries.isEmpty) {
      // No more tries, revert to 'want to try'
      favorites[drinkId] = existing.copyWith(
        status: FavoriteStatus.wantToTry,
        tries: [],
        updatedAt: DateTime.now(),
      );
    } else {
      // Still has tries, just update list
      favorites[drinkId] = existing.copyWith(
        tries: updatedTries,
        updatedAt: DateTime.now(),
      );
    }

    await saveFavorites(festivalId, favorites);
  }

  /// Update notes for a favorite item
  Future<void> updateNotes(
    String festivalId,
    String drinkId,
    String? notes,
  ) async {
    final favorites = getFavorites(festivalId);
    final existing = favorites[drinkId];
    if (existing == null) return;

    favorites[drinkId] = existing.copyWith(
      notes: Optional.value(notes),
      updatedAt: DateTime.now(),
    );

    await saveFavorites(festivalId, favorites);
  }
}

/// Service for managing personal ratings locally
class RatingsService {
  static const _ratingsKey = 'ratings';

  final SharedPreferences _prefs;

  RatingsService(this._prefs);

  /// Get rating for a drink (1-5, or null if not rated)
  int? getRating(String festivalId, String drinkId) {
    final key = '${_ratingsKey}_${festivalId}_$drinkId';
    return _prefs.getInt(key);
  }

  /// Set rating for a drink (must be between 1-5 inclusive)
  Future<void> setRating(String festivalId, String drinkId, int rating) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(
        rating,
        'rating',
        'Rating must be between 1 and 5 inclusive',
      );
    }
    final key = '${_ratingsKey}_${festivalId}_$drinkId';
    await _prefs.setInt(key, rating);
  }

  /// Remove rating for a drink
  Future<void> removeRating(String festivalId, String drinkId) async {
    final key = '${_ratingsKey}_${festivalId}_$drinkId';
    await _prefs.remove(key);
  }
}

/// Service for managing festival selection persistence
class FestivalStorageService {
  static const _selectedFestivalKey = 'selected_festival_id';

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
