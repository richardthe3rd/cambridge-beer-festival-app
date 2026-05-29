import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'environment_service.dart';

/// Service for Firebase Analytics and Crashlytics
class AnalyticsService {
  /// Lazy initialization to avoid Firebase initialization errors in tests
  FirebaseAnalytics? _analytics;
  FirebaseAnalytics get analytics => _analytics ??= FirebaseAnalytics.instance;

  FirebaseCrashlytics? _crashlytics;
  FirebaseCrashlytics get crashlytics =>
      _crashlytics ??= FirebaseCrashlytics.instance;

  /// Check if analytics should be enabled
  /// Analytics are enabled only in production environments (cambeerfestival.app).
  /// Analytics are disabled in staging, preview, and development environments
  /// (including localhost/127.0.0.1) to avoid mixing test data with production metrics.
  bool get _isAnalyticsEnabled => EnvironmentService.isProduction();

  /// Helper method to execute analytics calls only when enabled
  Future<void> _logIfEnabled(
    Future<void> Function() analyticsCall, {
    bool showDebug = false,
  }) async {
    if (!_isAnalyticsEnabled) {
      // coverage:ignore-start
      if (showDebug) {
        debugPrint(
          'Analytics disabled in ${EnvironmentService.getEnvironmentName()} environment',
        );
      }
      // coverage:ignore-end
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
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'festival_selected',
        // coverage:ignore-start
        parameters: {
          'festival_id': festival.id,
          'festival_name': festival.name,
        },
        // coverage:ignore-end
      ),
    );
  }

  /// Log search usage
  Future<void> logSearch(String query) async {
    await _logIfEnabled(() => analytics.logSearch(searchTerm: query));
  }

  /// Log category filter usage
  Future<void> logCategoryFilter(String? category) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'filter_category',
        // coverage:ignore-start
        parameters: {'category': category ?? 'all'},
        // coverage:ignore-end
      ),
    );
  }

  /// Log style filter usage
  Future<void> logStyleFilter(Set<String> styles) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'filter_style',
        // coverage:ignore-start
        parameters: {'style_count': styles.length, 'styles': styles.join(',')},
        // coverage:ignore-end
      ),
    );
  }

  /// Log sort change
  Future<void> logSortChange(String sortType) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'sort_changed',
        // coverage:ignore-start
        parameters: {'sort_type': sortType},
        // coverage:ignore-end
      ),
    );
  }

  /// Log favorite added
  Future<void> logFavoriteAdded(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'favorite_added',
        // coverage:ignore-start
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'brewery': drink.breweryName,
          'category': drink.category,
        },
        // coverage:ignore-end
      ),
    );
  }

  /// Log favorite removed
  Future<void> logFavoriteRemoved(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'favorite_removed',
        // coverage:ignore-start
        parameters: {'drink_id': drink.id, 'drink_name': drink.name},
        // coverage:ignore-end
      ),
    );
  }

  /// Log drink marked as tasted
  Future<void> logTastedAdded(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'tasted_added',
        // coverage:ignore-start
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'brewery': drink.breweryName,
          'category': drink.category,
        },
        // coverage:ignore-end
      ),
    );
  }

  /// Log drink unmarked as tasted
  Future<void> logTastedRemoved(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'tasted_removed',
        // coverage:ignore-start
        parameters: {'drink_id': drink.id, 'drink_name': drink.name},
        // coverage:ignore-end
      ),
    );
  }

  /// Log drink details viewed
  Future<void> logDrinkViewed(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'drink_viewed',
        // coverage:ignore-start
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'brewery': drink.breweryName,
          'category': drink.category,
          'abv': drink.abv,
        },
        // coverage:ignore-end
      ),
    );
  }

  /// Log brewery details viewed
  Future<void> logBreweryViewed(String breweryName) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'brewery_viewed',
        // coverage:ignore-start
        parameters: {'brewery_name': breweryName},
        // coverage:ignore-end
      ),
    );
  }

  /// Log style details viewed
  Future<void> logStyleViewed(String style) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'style_viewed',
        // coverage:ignore-start
        parameters: {'style': style},
        // coverage:ignore-end
      ),
    );
  }

  /// Log rating given
  Future<void> logRatingGiven(Drink drink, int rating) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'rating_given',
        // coverage:ignore-start
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'rating': rating,
        },
        // coverage:ignore-end
      ),
    );
  }

  /// Log drink shared
  Future<void> logDrinkShared(Drink drink) async {
    await _logIfEnabled(
      () => analytics.logEvent(
        name: 'drink_shared',
        // coverage:ignore-start
        parameters: {'drink_id': drink.id, 'drink_name': drink.name},
        // coverage:ignore-end
      ),
    );
  }

  /// Log error to Crashlytics (non-fatal)
  Future<void> logError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    try {
      await crashlytics.recordError(
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
    await _logIfEnabled(
      () => analytics.setUserProperty(name: name, value: value),
    );
  }

  /// Set user ID for tracking across sessions
  Future<void> setUserId(String? userId) async {
    // Analytics respects environment settings
    await _logIfEnabled(() => analytics.setUserId(id: userId));

    // Crashlytics always sets user ID for debugging in all environments
    try {
      if (userId != null) {
        await crashlytics.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }
}
