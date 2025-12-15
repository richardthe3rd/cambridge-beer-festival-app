import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper class for launching URLs with consistent error handling
///
/// Provides a standard pattern for opening external URLs with user-friendly
/// error messages displayed via SnackBars.
class UrlLauncherHelper {
  UrlLauncherHelper._();

  /// Launch a URL in an external application
  ///
  /// Shows error snackbars if the URL cannot be opened.
  /// Returns true if the URL was successfully launched, false otherwise.
  ///
  /// Parameters:
  /// - [context]: BuildContext for showing snackbars
  /// - [url]: URL to launch as a String
  /// - [errorMessage]: Error message to display if launch fails (default: 'Could not open URL')
  static Future<bool> launchURL(
    BuildContext context,
    String url, {
    String errorMessage = 'Could not open URL',
  }) async {
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return false;
    }
  }
}
