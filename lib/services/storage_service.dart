import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing favorites locally
class FavoritesService {
  static const _favoritesKey = 'favorites';
  
  final SharedPreferences _prefs;

  FavoritesService(this._prefs);

  /// Get all favorite drink IDs for a festival
  Set<String> getFavorites(String festivalId) {
    final key = '${_favoritesKey}_$festivalId';
    final favorites = _prefs.getStringList(key) ?? [];
    return favorites.toSet();
  }

  /// Add a drink to favorites
  Future<void> addFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    favorites.add(drinkId);
    await _saveFavorites(festivalId, favorites);
  }

  /// Remove a drink from favorites
  Future<void> removeFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    favorites.remove(drinkId);
    await _saveFavorites(festivalId, favorites);
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String festivalId, String drinkId) async {
    final favorites = getFavorites(festivalId);
    final isFavorite = favorites.contains(drinkId);
    
    if (isFavorite) {
      favorites.remove(drinkId);
    } else {
      favorites.add(drinkId);
    }
    
    await _saveFavorites(festivalId, favorites);
    return !isFavorite;
  }

  /// Check if a drink is a favorite
  bool isFavorite(String festivalId, String drinkId) {
    return getFavorites(festivalId).contains(drinkId);
  }

  Future<void> _saveFavorites(String festivalId, Set<String> favorites) async {
    final key = '${_favoritesKey}_$festivalId';
    await _prefs.setStringList(key, favorites.toList());
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

  /// Set rating for a drink
  Future<void> setRating(String festivalId, String drinkId, int rating) async {
    final key = '${_ratingsKey}_${festivalId}_$drinkId';
    await _prefs.setInt(key, rating.clamp(1, 5));
  }

  /// Remove rating for a drink
  Future<void> removeRating(String festivalId, String drinkId) async {
    final key = '${_ratingsKey}_${festivalId}_$drinkId';
    await _prefs.remove(key);
  }
}
