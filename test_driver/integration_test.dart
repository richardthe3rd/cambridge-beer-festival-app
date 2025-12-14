// ignore_for_file: avoid_print

import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// **Integration Test Driver for Screenshot Capture**
///
/// This driver file is required to run integration tests and capture screenshots.
/// It uses the extended driver which adds screenshot capabilities.
///
/// **HOW IT WORKS:**
/// 1. The integration test runs in the Flutter app (screenshot_test.dart)
/// 2. When `binding.takeScreenshot('name')` is called, it sends data to this driver
/// 3. This driver receives the screenshot data and saves it to a file
///
/// **DIRECTORY STRUCTURE:**
/// Screenshots are saved to: `screenshots/<name>.png`
///
/// **ERROR HANDLING:**
/// - Creates the screenshots directory if it doesn't exist
/// - Logs errors to console if screenshot save fails
/// - Continues test execution even if screenshot fails (non-fatal)
///
/// **USAGE:**
/// Run with: flutter drive --driver=test_driver/integration_test.dart \
///                         --target=integration_test/screenshot_test.dart \
///                         -d web-server
///
/// **CI USAGE:**
/// In GitHub Actions, use `flutter drive` with explicit driver and target paths.
/// The ChromeDriver must be running before executing this command.
///

/// Minimum acceptable screenshot file size in KB.
/// Screenshots smaller than this are likely blank or mostly empty.
/// 
/// **THRESHOLD RATIONALE:**
/// This threshold is based on testing with the HTML renderer:
/// - A blank/black screen is typically 2-5 KB
/// - A simple screen with minimal content is ~8-12 KB
/// - A real app screen with full content is 15-50 KB
/// 
/// **DESIGN NOTE:** 5 KB is chosen as a practical threshold that:
/// - Catches most blank screenshots (≤ 5 KB)
/// - Reduces false positives for minimal but valid content (e.g., "HELLO" test at ~8 KB)
/// - Warns early if screenshots are unexpectedly small
/// 
/// **TRADEOFF:** Some extremely minimal screenshots may still trigger warnings, but
/// this threshold reduces false positives while still catching blank screenshots.
/// Warnings are non-fatal and serve as a helpful debugging signal.
/// 
/// **FUTURE IMPROVEMENT:** Make this configurable per screenshot type if needed,
/// but the current single threshold works well in practice.
const double kMinimumScreenshotSizeKb = 5.0;

Future<void> main() async {
  try {
    // Create screenshots directory if it doesn't exist
    final screenshotsDir = Directory('screenshots');
    if (!screenshotsDir.existsSync()) {
      print('📁 Creating screenshots directory...');
      screenshotsDir.createSync(recursive: true);
    }

    print('🚀 Starting integration test driver...');
    print('   Screenshots will be saved to: ${screenshotsDir.absolute.path}');

    // Run integration tests with screenshot support
    await integrationDriver(
      // Callback when screenshot is taken
      onScreenshot: (String screenshotName, List<int> screenshotBytes,
          [Map<String, Object?>? args]) async {
        print('📸 Saving screenshot: $screenshotName.png');
        
        try {
          final File image = File('screenshots/$screenshotName.png');
          image.writeAsBytesSync(screenshotBytes);
          
          // Verify file was created and has content
          if (image.existsSync()) {
            final fileSizeKb = image.lengthSync() / 1024;
            print('   ✅ Saved: ${image.path} (${fileSizeKb.toStringAsFixed(1)} KB)');
            
            // Warn if screenshot is suspiciously small (might be blank)
            if (fileSizeKb < kMinimumScreenshotSizeKb) {
              print('   ⚠️  WARNING: Screenshot file is very small (${fileSizeKb.toStringAsFixed(1)} KB)');
              print('      This might indicate a blank or mostly empty screenshot');
              print('      Minimum expected size: ${kMinimumScreenshotSizeKb.toStringAsFixed(1)} KB');
            }
          } else {
            print('   ❌ ERROR: Failed to create file: ${image.path}');
          }
          
          return true;
        } catch (e) {
          print('   ❌ ERROR saving screenshot $screenshotName: $e');
          // Return false to indicate failure, but don't throw (non-fatal)
          return false;
        }
      },
    );

    print('✅ Integration test driver completed successfully');
  } catch (e, stackTrace) {
    print('❌ Integration test driver failed:');
    print('   Error: $e');
    print('   Stack trace: $stackTrace');
    rethrow;
  }
}
