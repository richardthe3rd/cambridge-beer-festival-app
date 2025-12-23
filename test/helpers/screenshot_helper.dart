import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:provider/provider.dart';

/// Helper utilities for screenshot tests

/// Standard screen sizes for screenshots
class ScreenSizes {
  static const Size phone = Size(428, 926); // iPhone 14 Pro Max size
  static const Size tablet = Size(820, 1180); // iPad 11" size
}

/// Creates a MaterialApp wrapper for testing screens
/// 
/// [child] - The widget to wrap
/// [brightness] - Light or dark theme
/// [provider] - BeerProvider instance for state management
Widget createTestApp({
  required Widget child,
  required Brightness brightness,
  required BeerProvider provider,
}) {
  return ChangeNotifierProvider<BeerProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD97706),
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

/// Takes a screenshot of a widget and compares it to a golden file
/// 
/// [tester] - WidgetTester from test
/// [finder] - Widget finder to screenshot
/// [goldenFileName] - Name of the golden file (e.g., 'my_screen_light.png')
Future<void> takeScreenshot(
  WidgetTester tester,
  Finder finder,
  String goldenFileName,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    finder,
    matchesGoldenFile('goldens/$goldenFileName'),
  );
}

/// Sets up a standard screenshot test with both light and dark themes
/// 
/// [tester] - WidgetTester from test
/// [screenWidget] - The screen widget to test
/// [provider] - BeerProvider instance
/// [screenName] - Base name for the screenshot files (e.g., 'drinks_screen')
/// [size] - Screen size to use (defaults to phone size)
Future<void> screenshotLightAndDark({
  required WidgetTester tester,
  required Widget screenWidget,
  required BeerProvider provider,
  required String screenName,
  Size size = ScreenSizes.phone,
}) async {
  // Set screen size
  await tester.binding.setSurfaceSize(size);

  // Light theme screenshot
  await tester.pumpWidget(
    createTestApp(
      child: screenWidget,
      brightness: Brightness.light,
      provider: provider,
    ),
  );
  await tester.pumpAndSettle();
  await takeScreenshot(
    tester,
    find.byWidget(screenWidget),
    '${screenName}_light.png',
  );

  // Dark theme screenshot
  await tester.pumpWidget(
    createTestApp(
      child: screenWidget,
      brightness: Brightness.dark,
      provider: provider,
    ),
  );
  await tester.pumpAndSettle();
  await takeScreenshot(
    tester,
    find.byWidget(screenWidget),
    '${screenName}_dark.png',
  );
}
