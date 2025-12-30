import '../../models/models.dart';

/// Repository interface for drink data access
///
/// Abstracts data access for drinks, favorites, and ratings.
/// Implementations can use different data sources (API, local DB, cache).
abstract class DrinkRepository {
  /// Fetch all drinks for a festival
  ///
  /// Returns drinks with favorite and rating status already populated.
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
}
