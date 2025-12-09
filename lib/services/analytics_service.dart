import 'package:firebase_analytics/firebaseanalytics.dart';
import 'package:firebase_crashlytics/firebasecrashlytics.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'environment_service.dart';

/// Service for Firebase Analytics and Crashlytics
class AnalyticsService {
  /// Lazy initialization to avoid Firebase initialization errors in tests
  FirebaseAnalytics? _analytics;
  FirebaseAnalytics get analytics => _analytics ??= FirebaseAnalytics.instance;
  
  FirebaseCrashlytics? _crashlytics;
  FirebaseCrashlytics get crashlytics => _crashlytics ??= FirebaseCrashlytics.instance;
  
  /// Check if analytics should be enabled
  /// Analytics are disabled in staging and preview environments to avoid mixing test data
  bool get _isAnalyticsEnabled => EnvironmentService.isProduction();

  /// Helper method to execute analytics calls only when enabled
  Future<void> _logIfEnabled(Future<void> Function() analyticsCall, {bool showDebug = false}) async {
    if (!_isAnalyticsEnabled) {
      if (showDebug) {
        debugPrint('Analytics disabled in ${EnvironmentService.getEnvironmentName()} environment');
      }
      return;
    }
    try {
      await analyticsCall();
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log app launch event
  Future<void> logAppLaunch() async {
    await _logIfEnabled(() => analytics.logAppOpen(), showDebug: true);
  }

  /// Log festival selection
  Future<void> logFestivalSelected(Festival festival) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'festival_selected',
      parameters: {
        'festival_id': festival.id,
        'festival_name': festival.name,
      },
    ));
  }

  /// Log search usage
  Future<void> logSearch(String query) async {
    await _logIfEnabled(() => analytics.logSearch(searchTerm: query));
  }

  /// Log category filter usage
  Future<void> logCategoryFilter(String? category) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'filter_category',
      parameters: {
        'category': category ?? 'all',
      },
    ));
  }

  /// Log style filter usage
  Future<void> logStyleFilter(Set<String> styles) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'filter_style',
      parameters: {
        'style_count': styles.length,
        'styles': styles.join(','),
      },
    ));
  }

  /// Log sort change
  Future<void> logSortChange(String sortType) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'sort_changed',
      parameters: {
        'sort_type': sortType,
      },
    ));
  }

  /// Log favorite added
  Future<void> logFavoriteAdded(Drink drink) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'favorite_added',
      parameters: {
        'drink_id': drink.id,
        'drink_name': drink.name,
        'brewery': drink.breweryName,
        'category': drink.category,
      },
    ));
  }

  /// Log favorite removed
  Future<void> logFavoriteRemoved(Drink drink) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'favorite_removed',
      parameters: {
        'drink_id': drink.id,
        'drink_name': drink.name,
      },
    ));
  }

  /// Log drink details viewed
  Future<void> logDrinkViewed(Drink drink) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'drink_viewed',
      parameters: {
        'drink_id': drink.id,
        'drink_name': drink.name,
        'brewery': drink.breweryName,
        'category': drink.category,
        'abv': drink.abv,
      },
    ));
  }

  /// Log brewery details viewed
  Future<void> logBreweryViewed(String breweryName) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'brewery_viewed',
      parameters: {
        'brewery_name': breweryName,
      },
    ));
  }

  /// Log style details viewed
  Future<void> logStyleViewed(String style) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'style_viewed',
      parameters: {
        'style': style,
      },
    ));
  }

  /// Log rating given
  Future<void> logRatingGiven(Drink drink, int rating) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'rating_given',
      parameters: {
        'drink_id': drink.id,
        'drink_name': drink.name,
        'rating': rating,
      },
    ));
  }

  /// Log drink shared
  Future<void> logDrinkShared(Drink drink) async {
    await _logIfEnabled(() => analytics.logEvent(
      name: 'drink_shared',
      parameters: {
        'drink_id': drink.id,
        'drink_name': drink.name,
      },
    ));
  }

  /// Log error to Crashlytics (non-fatal)
  Future<void> logError(Object error, StackTrace? stackTrace, {String? reason}) async {
    try {
      awaitcrashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }

  /// Set user property (e.g., preferred theme)
  Future<void> setUserProperty(String name, String? value) async {
    await _logIfEnabled(() => analytics.setUserProperty(name: name, value: value));
  }

  /// Set user ID for tracking across sessions
  Future<void> setUserId(String? userId) async {
    // Analytics respects environment settings
    await _logIfEnabled(() => analytics.setUserId(id: userId));
    
    // Crashlytics always sets user ID for debugging in all environments
    try {
      awaitcrashlytics.setUserIdentifier(userId ?? '');
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }
}
