import '../../services/services.dart';
import 'festival_repository.dart';

/// Implementation of FestivalRepository using API services
///
/// Delegates to FestivalService and FestivalStorageService.
class ApiFestivalRepository implements FestivalRepository {
  final FestivalService _festivalService;
  final FestivalStorageService _festivalStorageService;

  ApiFestivalRepository({
    required FestivalService festivalService,
    required FestivalStorageService festivalStorageService,
  })  : _festivalService = festivalService,
        _festivalStorageService = festivalStorageService;

  @override
  Future<FestivalsResponse> getFestivals() async {
    return await _festivalService.fetchFestivals();
  }

  @override
  Future<String?> getSelectedFestivalId() async {
    return _festivalStorageService.getSelectedFestivalId();
  }

  @override
  Future<void> setSelectedFestivalId(String festivalId) async {
    await _festivalStorageService.setSelectedFestivalId(festivalId);
  }
}
