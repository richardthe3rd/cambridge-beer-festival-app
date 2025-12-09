import 'package:flutter/foundation.dart';

/// Service for detecting the current environment (production, staging, or preview)
class EnvironmentService {
  /// Determine if the app is running in production environment
  /// 
  /// Production environments:
  /// - cambeerfestival.app (production custom domain)
  /// - localhost (development - treated as production for analytics)
  /// 
  /// Non-production (staging/preview) environments:
  /// - staging.cambeerfestival.app (staging custom domain)
  /// - *.cambeerfestival-staging.pages.dev (PR previews)
  /// - main.cambeerfestival-staging.pages.dev (main branch staging)
  static bool isProduction() {
    if (kIsWeb) {
      // On web, check the window location hostname using Uri.base
      final hostname = Uri.base.host;
      
      // Production domains
      if (hostname == 'cambeerfestival.app' || 
          hostname == 'localhost' || 
          hostname == '127.0.0.1') {
        return true;
      }
      
      // Staging and preview domains
      if (hostname == 'staging.cambeerfestival.app' ||
          hostname.endsWith('.cambeerfestival-staging.pages.dev')) {
        return false;
      }
      
      // Default to production for unknown domains (safety fallback)
      return true;
    }
    
    // On mobile platforms, always treat as production
    // (mobile apps don't have staging environments)
    return true;
  }
  
  /// Get a human-readable environment name for debugging
  static String getEnvironmentName() {
    if (!kIsWeb) {
      return 'mobile';
    }
    
    final hostname = Uri.base.host;
    
    if (hostname == 'cambeerfestival.app') {
      return 'production';
    } else if (hostname == 'staging.cambeerfestival.app') {
      return 'staging';
    } else if (hostname.endsWith('.cambeerfestival-staging.pages.dev')) {
      return 'preview';
    } else if (hostname == 'localhost' || hostname == '127.0.0.1') {
      return 'development';
    }
    
    return 'unknown';
  }
}
