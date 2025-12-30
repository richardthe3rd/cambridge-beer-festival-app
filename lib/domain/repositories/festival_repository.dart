import '../../services/festival_service.dart';

/// Repository interface for festival data access
///
/// Abstracts data access for festival metadata and user preferences.
abstract class FestivalRepository {
  /// Fetch all available festivals
  ///
  /// Returns a response containing the list of festivals and the default festival.
  Future<FestivalsResponse> getFestivals();

  /// Get the ID of the previously selected festival (from local storage)
  ///
  /// Returns null if no festival has been selected before.
  Future<String?> getSelectedFestivalId();

  /// Save the selected festival ID to local storage
  Future<void> setSelectedFestivalId(String festivalId);
}
