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
  final AnalyticsService _analyticsService;

  ApiFestivalRepository({
    required FestivalService festivalService,
    required FestivalStorageService festivalStorageService,
    required FestivalCacheService cacheService,
    required AnalyticsService analyticsService,
  })  : _festivalService = festivalService,
        _festivalStorageService = festivalStorageService,
        _cacheService = cacheService,
        _analyticsService = analyticsService;

  @override
  Future<FestivalsResponse> getFestivals() async {
    final response = await _festivalService.fetchFestivals();
    // Persist in the background so caching stays off the load critical path;
    // surface persistence failures via analytics rather than letting them
    // become unhandled async errors.
    unawaited(_cacheService.save(response).catchError((Object e, StackTrace s) {
      return _analyticsService.logError(
        e,
        s,
        reason: 'Festival cache write failed',
      );
    }));
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
