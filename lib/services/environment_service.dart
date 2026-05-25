import 'package:flutter/foundation.dart';

/// Service for detecting the current environment (production, staging, or preview)
class EnvironmentService {
  /// Determine if the app is running in production environment
  ///
  /// Production environments:
  /// - cambeerfestival.app (production custom domain)
  ///
  /// Non-production environments:
  /// - staging.cambeerfestival.app (staging custom domain)
  /// - *.staging-cambeerfestival.pages.dev (staging Cloudflare Pages)
  /// - *.cambeerfestival.pages.dev (PR preview Cloudflare Pages)
  /// - localhost / 127.0.0.1 (local development)
  static bool isProduction() {
    if (!kIsWeb) return true;
    return isProductionHost(Uri.base.host);
  }

  /// Get a human-readable environment name for debugging
  static String getEnvironmentName() {
    if (!kIsWeb) return 'mobile';
    return classifyHostname(Uri.base.host);
  }

  /// Pure hostname-to-production classification. Exposed for testing.
  @visibleForTesting
  static bool isProductionHost(String hostname) {
    if (hostname == 'cambeerfestival.app') return true;

    if (hostname == 'staging.cambeerfestival.app' ||
        hostname.endsWith('.staging-cambeerfestival.pages.dev') ||
        hostname.endsWith('.cambeerfestival.pages.dev') ||
        hostname == 'localhost' ||
        hostname == '127.0.0.1') {
      return false;
    }

    // Unknown hosts are not production — safer to under-count than pollute analytics.
    return false;
  }

  /// Pure hostname-to-environment-name classification. Exposed for testing.
  @visibleForTesting
  static String classifyHostname(String hostname) {
    if (hostname == 'cambeerfestival.app') return 'production';
    if (hostname == 'staging.cambeerfestival.app') return 'staging';
    if (hostname.endsWith('.staging-cambeerfestival.pages.dev') ||
        hostname.endsWith('.cambeerfestival.pages.dev')) {
      return 'preview';
    }
    if (hostname == 'localhost' || hostname == '127.0.0.1') {
      return 'development';
    }
    return 'unknown';
  }
}
