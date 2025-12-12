import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration test screenshots
/// 
/// This driver enables screenshot capture by writing screenshot files
/// to the screenshots directory.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final File image = File('screenshots/$screenshotName.png');
      await image.parent.create(recursive: true);
      await image.writeAsBytes(screenshotBytes);
      return true;
    },
  );
}
