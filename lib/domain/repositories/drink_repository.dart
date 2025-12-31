import '../../models/models.dart';

/// Repository interface for drink data access
///
/// Abstracts data access for drinks, favorites, ratings, and tasting logs.
/// Implementations can use different data sources (API, local DB, cache).
abstract class DrinkRepository {
  /// Fetch all drinks for a festival
  ///
  /// Returns drinks with favorite, rating, and tasting status already populated.
  Future<List<Drink>> getDrinks(Festival festival);

  /// Get list of favorited drink IDs for a festival
  Future<List<String>> getFavorites(String festivalId);

  /// Toggle favorite status for a drink
  ///
  /// Returns the new favorite status (true if now favorited, false if unfavorited).
  Future<bool> toggleFavorite(String festivalId, String drinkId);

  /// Get rating for a drink (1-5 stars, or null if not rated)
  Future<int?> getRating(String festivalId, String drinkId);

  /// Set rating for a drink (1-5 stars)
  Future<void> setRating(String festivalId, String drinkId, int rating);

  /// Remove rating for a drink
  Future<void> removeRating(String festivalId, String drinkId);

  /// Check if a drink has been tasted at a festival
  Future<bool> hasTasted(String festivalId, String drinkId);

  /// Toggle tasted status for a drink
  ///
  /// Returns the new tasted status (true if now tasted, false if untasted).
  Future<bool> toggleTasted(String festivalId, String drinkId);

  /// Get list of tasted drink IDs for a festival
  Future<List<String>> getTastedDrinks(String festivalId);
}
