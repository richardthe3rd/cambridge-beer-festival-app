import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/preference_keys.dart';
import '../models/models.dart';
import 'beer_api_service.dart';
import 'festival_service.dart';

/// Persists the last successfully fetched drinks per festival so the app can
/// render immediately on launch (stale-while-revalidate) instead of blocking on
/// the network.
///
/// Drinks are stored per beverage type so a refresh can update only the types
/// that succeeded while keeping the last-good data for types that failed (e.g.
/// a flaky `cider.json`), rather than overwriting a complete cache with a
/// partial fetch.
///
/// Backed by [SharedPreferences] to match the app's other local storage and to
/// work on web; this trades off ideal large-blob handling for simplicity, so a
/// small number of festival snapshots are retained ([_maxCachedFestivals]).
class DrinkCacheService {
  static const _keyPrefix = PreferenceKeys.drinksCachePrefix;
  static const _maxCachedFestivals = 12;

  final SharedPreferences _prefs;
  Future<void> _writeChain = Future.value();

  DrinkCacheService(this._prefs);

  String _key(String festivalId) => '${_keyPrefix}_$festivalId';

  /// Read cached drinks for a festival, or null if nothing usable is stored.
  ///
  /// Returns null on absent, empty, or corrupt data so callers can fall back to
  /// a network fetch.
  List<Drink>? read(String festivalId) {
    final types = _readRawTypes(festivalId);
    if (types == null) return null;
    final drinks = _flatten(types, festivalId);
    return drinks.isEmpty ? null : drinks;
  }

  /// Merge freshly fetched beverage types over the cached snapshot, preserving
  /// any cached types not present in [freshByType].
  ///
  /// Returns the merged drinks immediately (computed in memory); the updated
  /// cache is written in the background. Callers that must observe the write
  /// (e.g. tests) can await [DrinkCacheUpdate.written]; the app intentionally
  /// does not, to keep persistence off the load critical path.
  DrinkCacheUpdate merge(
    String festivalId,
    Map<String, List<Drink>> freshByType,
  ) {
    final types = Map<String, dynamic>.from(_readRawTypes(festivalId) ?? {});
    freshByType.forEach((type, drinks) {
      types[type] = _producersJson(drinks);
    });
    // catchError on _writeChain keeps the serial queue healthy if a write fails.
    final writeTask = _writeChain.then((_) => _persistTypes(festivalId, types));
    _writeChain = writeTask.catchError((_) {});
    final written = writeTask;
    return DrinkCacheUpdate(_flatten(types, festivalId), written);
  }

  /// Remove cached drinks for a festival.
  Future<void> clear(String festivalId) async {
    await _prefs.remove(_key(festivalId));
  }

  Map<String, dynamic>? _readRawTypes(String festivalId) {
    final raw = _prefs.getString(_key(festivalId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final types = data['beverageTypes'];
      if (types is! Map) return null;
      // Drop any entry whose value isn't a producers list — corrupt or
      // partially-migrated payloads should degrade to a miss for that type
      // rather than crash later in _flatten/parseProducers.
      final clean = <String, dynamic>{};
      for (final entry in types.entries) {
        if (entry.value is List) clean[entry.key.toString()] = entry.value;
      }
      return clean;
    } catch (_) {
      // Corrupt or unexpected payload — treat as a cache miss.
      return null;
    }
  }

  List<Drink> _flatten(Map<String, dynamic> types, String festivalId) {
    final drinks = <Drink>[];
    for (final producers in types.values) {
      try {
        drinks.addAll(
          BeerApiService.parseProducers({'producers': producers}, festivalId),
        );
      } catch (_) {
        // Skip a beverage type whose payload fails to parse rather than
        // failing the whole read — the next successful refresh will fix it.
      }
    }
    return drinks;
  }

  List<Map<String, dynamic>> _producersJson(List<Drink> drinks) {
    final byProducerId = <String, List<Drink>>{};
    for (final drink in drinks) {
      byProducerId.putIfAbsent(drink.producer.id, () => []).add(drink);
    }
    return byProducerId.values.map((group) {
      final producer = group.first.producer;
      return <String, dynamic>{
        'id': producer.id,
        'name': producer.name,
        'location': producer.location,
        if (producer.yearFounded != null) 'year_founded': producer.yearFounded,
        if (producer.notes != null) 'notes': producer.notes,
        'products': group.map((d) => d.product.toJson()).toList(),
      };
    }).toList();
  }

  Future<void> _persistTypes(
    String festivalId,
    Map<String, dynamic> types,
  ) async {
    final payload = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'beverageTypes': types,
    };
    await _prefs.setString(_key(festivalId), json.encode(payload));
    await _evictOldCaches();
  }

  /// Drop the oldest festival snapshots once more than [_maxCachedFestivals]
  /// are stored, so the cache cannot grow without bound across festivals.
  Future<void> _evictOldCaches() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith('${_keyPrefix}_'))
        .toList();
    if (keys.length <= _maxCachedFestivals) return;

    int timestampOf(String key) {
      // Guard against a concurrent removal between getKeys() above and this
      // read: the key may have vanished, so treat it as the oldest possible.
      final raw = _prefs.getString(key);
      if (raw == null) return 0;
      try {
        final data = json.decode(raw) as Map<String, dynamic>;
        return data['timestamp'] as int? ?? 0;
      } catch (_) {
        return 0;
      }
    }

    keys.sort((a, b) => timestampOf(a).compareTo(timestampOf(b)));
    for (final key in keys.take(keys.length - _maxCachedFestivals)) {
      await _prefs.remove(key);
    }
  }
}

/// Result of [DrinkCacheService.merge]: the merged drinks plus a future that
/// completes when the background cache write finishes.
class DrinkCacheUpdate {
  final List<Drink> drinks;
  final Future<void> written;

  const DrinkCacheUpdate(this.drinks, this.written);
}

/// Persists the last successfully fetched festival registry so the festival
/// switcher and a saved festival selection work offline at startup.
class FestivalCacheService {
  static const _key = PreferenceKeys.festivalsCache;

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
