import 'dart:async';

import '../../services/services.dart';
import 'festival_repository.dart';

/// Implementation of FestivalRepository using API services
///
/// Delegates to FestivalService and FestivalStorageService.
class ApiFestivalRepository implements FestivalRepository {
  final FestivalService _festivalService;
  final FestivalStorageService _festivalStorageService;
  final FestivalCacheService _cacheService;

  ApiFestivalRepository({
    required FestivalService festivalService,
    required FestivalStorageService festivalStorageService,
    required FestivalCacheService cacheService,
  })  : _festivalService = festivalService,
        _festivalStorageService = festivalStorageService,
        _cacheService = cacheService;

  @override
  Future<FestivalsResponse> getFestivals() async {
    final response = await _festivalService.fetchFestivals();
    // Persist in the background so caching stays off the load critical path.
    unawaited(_cacheService.save(response));
    return response;
  }

  @override
  Future<FestivalsResponse?> getCachedFestivals() async {
    return _cacheService.read();
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
