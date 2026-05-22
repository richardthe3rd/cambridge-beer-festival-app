import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'beer_api_service.dart';
import 'festival_service.dart';

/// Persists the last successfully fetched drinks per festival so the app can
/// render immediately on launch (stale-while-revalidate) instead of blocking on
/// the network.
class DrinkCacheService {
  static const _keyPrefix = 'drinks_cache';

  final SharedPreferences _prefs;

  DrinkCacheService(this._prefs);

  String _key(String festivalId) => '${_keyPrefix}_$festivalId';

  /// Store the given drinks for a festival, serialized in the same
  /// `{ "producers": [...] }` shape the API returns so reads can reuse
  /// [BeerApiService.parseProducers].
  Future<void> save(String festivalId, List<Drink> drinks) async {
    final byProducerId = <String, List<Drink>>{};
    for (final drink in drinks) {
      byProducerId.putIfAbsent(drink.producer.id, () => []).add(drink);
    }

    final producers = byProducerId.values.map((group) {
      final producer = group.first.producer;
      return {
        'id': producer.id,
        'name': producer.name,
        'location': producer.location,
        if (producer.yearFounded != null) 'year_founded': producer.yearFounded,
        if (producer.notes != null) 'notes': producer.notes,
        'products': group.map((d) => d.product.toJson()).toList(),
      };
    }).toList();

    final payload = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'producers': producers,
    };

    await _prefs.setString(_key(festivalId), json.encode(payload));
  }

  /// Read cached drinks for a festival, or null if nothing usable is stored.
  ///
  /// Returns null on absent, empty, or corrupt data so callers can fall back to
  /// a network fetch.
  List<Drink>? read(String festivalId) {
    final raw = _prefs.getString(_key(festivalId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final drinks = BeerApiService.parseProducers(data, festivalId);
      return drinks.isEmpty ? null : drinks;
    } catch (_) {
      // Corrupt or unexpected payload — treat as a cache miss.
      return null;
    }
  }

  /// Remove cached drinks for a festival.
  Future<void> clear(String festivalId) async {
    await _prefs.remove(_key(festivalId));
  }
}

/// Persists the last successfully fetched festival registry so the festival
/// switcher and a saved festival selection work offline at startup.
class FestivalCacheService {
  static const _key = 'festivals_cache';

  final SharedPreferences _prefs;

  FestivalCacheService(this._prefs);

  /// Store the festivals response. Festival URLs are already absolute at this
  /// point, so [FestivalsResponse.fromJson]'s relative-URL resolution is a
  /// no-op when reading back.
  Future<void> save(FestivalsResponse response) async {
    final payload = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'base_url': response.baseUrl,
      'version': response.version,
      if (response.lastUpdated != null)
        'last_updated': response.lastUpdated!.toIso8601String(),
      'default_festival_id': response.defaultFestivalId,
      'festivals': response.festivals.map((f) => f.toJson()).toList(),
    };

    await _prefs.setString(_key, json.encode(payload));
  }

  /// Read the cached festivals response, or null if nothing usable is stored.
  FestivalsResponse? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final baseUrl = (data['base_url'] as String?) ?? '';
      final response = FestivalsResponse.fromJson(data, baseUrl);
      return response.festivals.isEmpty ? null : response;
    } catch (_) {
      return null;
    }
  }

  /// Remove the cached festivals response.
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
