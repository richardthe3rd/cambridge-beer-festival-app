import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for Firebase Analytics and Crashlytics
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Log app launch event
  Future<void> logAppLaunch() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log festival selection
  Future<void> logFestivalSelected(Festival festival) async {
    try {
      await _analytics.logEvent(
        name: 'festival_selected',
        parameters: {
          'festival_id': festival.id,
          'festival_name': festival.name,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log search usage
  Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log category filter usage
  Future<void> logCategoryFilter(String? category) async {
    try {
      await _analytics.logEvent(
        name: 'filter_category',
        parameters: {
          'category': category ?? 'all',
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log style filter usage
  Future<void> logStyleFilter(Set<String> styles) async {
    try {
      await _analytics.logEvent(
        name: 'filter_style',
        parameters: {
          'style_count': styles.length,
          'styles': styles.join(','),
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log sort change
  Future<void> logSortChange(String sortType) async {
    try {
      await _analytics.logEvent(
        name: 'sort_changed',
        parameters: {
          'sort_type': sortType,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log favorite added
  Future<void> logFavoriteAdded(Drink drink) async {
    try {
      await _analytics.logEvent(
        name: 'favorite_added',
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'brewery': drink.breweryName,
          'category': drink.category,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log favorite removed
  Future<void> logFavoriteRemoved(Drink drink) async {
    try {
      await _analytics.logEvent(
        name: 'favorite_removed',
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log drink details viewed
  Future<void> logDrinkViewed(Drink drink) async {
    try {
      await _analytics.logEvent(
        name: 'drink_viewed',
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'brewery': drink.breweryName,
          'category': drink.category,
          'abv': drink.abv,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log brewery details viewed
  Future<void> logBreweryViewed(String breweryName) async {
    try {
      await _analytics.logEvent(
        name: 'brewery_viewed',
        parameters: {
          'brewery_name': breweryName,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log rating given
  Future<void> logRatingGiven(Drink drink, int rating) async {
    try {
      await _analytics.logEvent(
        name: 'rating_given',
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
          'rating': rating,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log drink shared
  Future<void> logDrinkShared(Drink drink) async {
    try {
      await _analytics.logEvent(
        name: 'drink_shared',
        parameters: {
          'drink_id': drink.id,
          'drink_name': drink.name,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log error to Crashlytics (non-fatal)
  Future<void> logError(Object error, StackTrace? stackTrace, {String? reason}) async {
    try {
      await _crashlytics.recordError(
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
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Set user ID for tracking across sessions
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      if (userId != null) {
        await _crashlytics.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
