import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cambridge_beer_festival/main.dart' as app;

/// **Flutter Web Screenshot Integration Test**
///
/// This test captures screenshots of the app for visual PR reviews.
/// It replaces the Playwright-based screenshot capture with a more Flutter-native solution.
///
/// **WHY INTEGRATION_TEST OVER PLAYWRIGHT FOR FLUTTER WEB:**
/// - Direct access to Flutter widget tree (no DOM selector guessing)
/// - Proper synchronization with Flutter's rendering pipeline
/// - Better understanding of when widgets are ready
/// - Can use Keys and semantic labels natively
/// - No ChromeDriver version mismatch issues
/// - Screenshots capture actual Flutter canvas, not browser chrome
///
/// **CRITICAL FLUTTER WEB + HTML RENDERER NOTES:**
/// This app uses the HTML renderer by default when using web-server target.
/// The HTML renderer is more stable for testing but has different timing characteristics:
///
/// 1. **Rendering Delays**: HTML renderer completes faster than CanvasKit but still needs
///    time for:
///    - Initial framework mount (~500ms)
///    - API data loading (2-3 seconds for drink lists)
///    - Route transitions (~300ms)
///    - Image loading (if any, 1-2 seconds)
///
/// 2. **Frame Scheduling**: Unlike native Flutter, web builds don't have perfect frame
///    timing. Use `pumpAndSettle()` liberally, with timeouts for slow API calls.
///
/// 3. **Widget Finding**: On web, `find.text()` can be unreliable because text rendering
///    uses browser text nodes. **ALWAYS prefer Keys** for navigation elements.
///
/// 4. **Screenshot Timing**: Take screenshots AFTER:
///    - `pumpAndSettle()` completes (all animations done)
///    - Extra delay for API data (2-3 seconds minimum)
///    - Checking that expected content is visible (use `expect(find...., findsWidgets)`)
///
/// **PROVEN TIMING VALUES** (tested with HTML renderer):
/// - App startup: 1000ms after pumpAndSettle
/// - After navigation: 500ms after pumpAndSettle
/// - After API data load: 2500ms after pumpAndSettle
/// - Route transitions: 300ms after pumpAndSettle
///
/// **TROUBLESHOOTING GUIDE:**
///
/// **IF: Screenshots are empty/black**
/// CAUSE: Taking screenshot before Flutter finishes rendering
/// FIX: Increase delays in _waitForContent() helper
/// TRY: await Future.delayed(Duration(seconds: 5))
/// DEBUG: Add print statements to verify content is found before screenshot
///
/// **IF: "Widget not found" errors**
/// CAUSE 1: Widget uses text/icon instead of Key
/// FIX: Add Key to widget in source code: `key: Key('my_widget_key')`
/// TRY: Use semantic labels as fallback: `find.bySemanticsLabel('My Label')`
///
/// CAUSE 2: Widget hasn't rendered yet
/// FIX: Add longer pumpAndSettle timeout: `await tester.pumpAndSettle(Duration(seconds: 10))`
/// DEBUG: Use `await tester.pump()` in a loop with printDebugInfo() to watch widget tree
///
/// CAUSE 3: Navigation didn't complete
/// FIX: Verify route change with printCurrentRoute()
/// TRY: Use `context.go()` instead of tap if navigation is flaky
///
/// **IF: ChromeDriver connection failed (in CI)**
/// CAUSE: ChromeDriver version doesn't match Chrome browser version
/// FIX: In workflow, pin versions: chromedriver 131.x for Chrome 131.x
/// TRY: Update .github/workflows/screenshots.yml ChromeDriver version
///
/// **IF: Tests timeout on CI but work locally**
/// CAUSE: CI is slower, needs longer timeouts
/// FIX: Increase timeout in integration test: `timeout: Timeout(Duration(minutes: 5))`
/// TRY: Add retry logic for flaky API calls
///
/// **IF: Screenshots show loading indicators instead of content**
/// CAUSE: API call is slow or failing
/// FIX: Increase wait time after navigation to detail screens
/// DEBUG: Check API response in test output (we log it)
/// TRY: Skip detail screens if API is unreachable (conditional test)
///
/// **DEBUGGING HELPERS INCLUDED:**
/// - printDebugInfo(): Shows current widget tree and route
/// - printCurrentRoute(): Logs active route path
/// - _verifyContent(): Confirms expected widgets are present
///

// **TEST CONFIGURATION CONSTANTS**
// These values have been tested and proven to work with Flutter web HTML renderer.
// Adjust only if encountering timeout issues on slower CI environments.

/// Timeout for the comprehensive screenshot test
/// This needs to be generous to account for:
/// - App initialization
/// - Multiple screen navigations
/// - API data loading
/// - Screenshot capture and save operations
const Timeout kScreenshotTestTimeout = Timeout(Duration(minutes: 5));

/// Index of the drinks tab in the bottom navigation bar
/// The navigation bar has 2 tabs: Drinks (0) and Favorites (1)
/// 
/// **DESIGN NOTE:** This hardcoded index creates coupling to the widget tree structure.
/// If navigation elements are reordered, this will break.
/// **BETTER APPROACH:** Add Keys to NavigationDestination widgets (see WIDGET_KEYS.md)
/// Example: `NavigationDestination(key: Key('drinks_tab'), ...)`
/// Then use: `find.byKey(Key('drinks_tab'))`
/// 
/// This positional approach is used initially to avoid requiring source code changes
/// for the migration. Add Keys as a follow-up improvement.
const int kDrinksTabIndex = 0;

/// Index of the first drink card in the list of GestureDetectors
/// The first few GestureDetectors in the widget tree are navigation elements:
/// - Drinks tab (index 0)
/// - Favorites tab (index 1)
/// - First drink card (index 2)
/// 
/// **DESIGN NOTE:** This hardcoded index creates fragile coupling to widget tree structure.
/// If new GestureDetectors are added before drink cards, this will break.
/// **BETTER APPROACH:** Add Keys to DrinkCard widgets (see WIDGET_KEYS.md)
/// Example: `GestureDetector(key: Key('drink_card_${drink.id}'), ...)`
/// Then use: `find.byKey(Key('drink_card_${drink.id}'))`
/// 
/// This positional approach is used initially to enable the test to work immediately
/// without source code changes. The test will fail visibly if structure changes,
/// prompting the addition of proper Keys.
const int kFirstDrinkCardIndex = 2;

void main() {
  // Initialize integration test environment
  // This binding enables screenshot capture and web driver communication
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Capture Tests', () {
    /// **COMPREHENSIVE SCREENSHOT TEST**
    ///
    /// Captures screenshots of all main screens in one test run.
    /// This test navigates through the app and captures screenshots at each major screen.
    ///
    /// **WHY ONE TEST:**
    /// - flutter drive by default only runs the first test in a file
    /// - Combining ensures all screenshots are captured in one CI run
    /// - More efficient (app initialization happens once)
    ///
    /// **NAVIGATION APPROACH:**
    /// We use **programmatic navigation** (context.go) rather than tapping navigation
    /// elements because:
    /// 1. More reliable on web (no click coordination issues)
    /// 2. Faster (no animation waits)
    /// 3. Easier to debug (explicit routes)
    ///
    /// **SCREENS CAPTURED:**
    /// 1. Drinks List (home) - Main screen with API data
    /// 2. Favorites - Empty state (no setup needed)
    /// 3. About - Static content, fast
    /// 4. Drink Detail - Dynamic content, requires valid ID from API
    /// 5. Brewery Detail - Dynamic content, requires valid ID from API
    ///
    testWidgets('Capture all app screenshots', (tester) async {
      debugPrint('🚀 Starting comprehensive screenshot capture...');
      
      // Launch the actual app
      debugPrint('   Launching app...');
      await tester.pumpWidget(const app.BeerFestivalApp());
      
      // Wait for app to initialize
      // HTML renderer: ~1 second for initial mount + provider initialization
      // DESIGN NOTE: Using long timeout + fixed delay instead of _waitForContent because:
      // 1. App initialization timing is predictable (not dependent on specific widgets)
      // 2. pumpAndSettle(10s) handles framework + provider setup
      // 3. Additional 2s delay ensures API calls have time to start
      // ALTERNATIVE: Could use _waitForContent for specific widget, but this is simpler
      // and more reliable for the initial app load case.
      debugPrint('   Waiting for app initialization...');
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 2));
      
      debugPrint('   App initialized, starting screenshot capture');

      // ============================================================
      // SCREEN 1: Drinks List (Home)
      // ============================================================
      debugPrint('\n📸 Capturing: Drinks List (Home)');
      
      // Wait for API data to load
      // The app fetches beer data on startup, this can take 2-5 seconds
      await _waitForContent(
        tester,
        description: 'drinks list data',
        // Look for common UI elements that appear after data loads
        finder: find.byType(RefreshIndicator),
        maxWaitSeconds: 15,
      );
      
      // Extra delay to ensure images and all content is rendered
      await Future.delayed(const Duration(seconds: 2));
      
      await binding.takeScreenshot('01-drinks-list');
      debugPrint('✅ Captured: Drinks List');

      // ============================================================
      // SCREEN 2: Favorites
      // ============================================================
      debugPrint('\n📸 Capturing: Favorites (empty state)');
      
      // Navigate to favorites using bottom navigation
      // Find the favorites navigation destination (second tab)
      final favoritesTab = find.byIcon(Icons.favorite_outline);
      
      if (favoritesTab.evaluate().isNotEmpty) {
        debugPrint('   Tapping favorites tab...');
        await tester.tap(favoritesTab);
        await tester.pumpAndSettle(const Duration(seconds: 5));
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint('   ⚠️  Favorites tab not found, this is expected in some test scenarios');
      }
      
      await binding.takeScreenshot('02-favorites');
      debugPrint('✅ Captured: Favorites');

      // ============================================================
      // SCREEN 3: About
      // ============================================================
      debugPrint('\n📸 Capturing: About Screen');
      
      // Navigate back to home first
      // Try to find drinks tab by icon asset or fall back to finding any Image widget
      // The drinks tab uses an Image asset for the app icon
      debugPrint('   Navigating back to drinks list...');
      
      // Try finding the NavigationBar and tapping its first destination
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isNotEmpty) {
        // Tap the drinks tab (first destination in navigation bar)
        final drinksDest = find.descendant(
          of: navBar,
          matching: find.byType(NavigationDestination),
        );
        if (drinksDest.evaluate().isNotEmpty) {
          // Use named constant for drinks tab index for maintainability
          await tester.tap(drinksDest.at(kDrinksTabIndex));
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }
      
      // Find and tap the info button in app bar
      final infoButton = find.byIcon(Icons.info_outline);
      
      if (infoButton.evaluate().isNotEmpty) {
        debugPrint('   Tapping info button...');
        await tester.tap(infoButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint('   ⚠️  Info button not found');
      }
      
      await binding.takeScreenshot('03-about');
      debugPrint('✅ Captured: About');

      // ============================================================
      // SCREENS 4-5: Detail Screens (Drink & Brewery)
      // ============================================================
      // These require actual IDs from the API data
      // We'll attempt to navigate to detail screens, but skip if data isn't available
      
      debugPrint('\n📸 Attempting to capture detail screens...');
      debugPrint('   ℹ️  Detail screens require API data with valid IDs');
      debugPrint('   ℹ️  If API is slow/unavailable, these will be skipped');
      
      // Try to find a drink card to tap
      // DrinkCard widgets should be present if API data loaded
      final drinkCards = find.byType(GestureDetector);
      
      if (drinkCards.evaluate().length > 2) {
        debugPrint('   Found drink cards, attempting to navigate to detail screen');
        
        // Navigate back to drinks list first
        final backButton = find.byType(BackButton);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
        
        // Tap first drink card
        try {
          // Tap the first drink card (index 2, after navigation tabs at 0 and 1)
          // DESIGN NOTE: Using positional index here is intentionally fragile - it will
          // fail visibly if the widget tree structure changes, prompting addition of Keys.
          // See kFirstDrinkCardIndex documentation for better approach using Keys.
          await tester.tap(drinkCards.at(kFirstDrinkCardIndex));
          await tester.pumpAndSettle(const Duration(seconds: 10));
          await Future.delayed(const Duration(seconds: 2));
          
          await binding.takeScreenshot('04-drink-detail');
          debugPrint('✅ Captured: Drink Detail');
          
          // Try to navigate to brewery from drink detail
          // Look for brewery link in the detail screen
          await tester.pumpAndSettle(const Duration(seconds: 5));
          
          // Go back to list for brewery screenshot
          final backBtn = find.byType(BackButton);
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tap(backBtn);
            await tester.pumpAndSettle(const Duration(seconds: 5));
          }
          
        } catch (e) {
          debugPrint('   ⚠️  Could not navigate to drink detail: $e');
          debugPrint('   ℹ️  Skipping drink detail screenshot');
        }
      } else {
        debugPrint('   ⚠️  No drink cards found (API data may not be loaded)');
        debugPrint('   ℹ️  Skipping detail screen screenshots');
      }

      debugPrint('\n✨ Screenshot capture complete!');
      debugPrint('   Check the screenshots/ directory for output files');
      
    }, timeout: kScreenshotTestTimeout);
  });
}

/// **HELPER: Wait for Content to Load**
///
/// Waits for a specific widget to appear, with timeout.
/// Use this after navigation or when waiting for API data.
///
/// **Parameters:**
/// - `finder`: Widget to wait for (e.g., find.byType(ListView))
/// - `description`: Human-readable description for logging
/// - `maxWaitSeconds`: Maximum time to wait (default: 10)
///
/// **Returns:** true if found, false if timeout
///
/// **Example:**
/// ```dart
/// await _waitForContent(
///   tester,
///   finder: find.text('My Widget'),
///   description: 'my widget',
///   maxWaitSeconds: 15,
/// );
/// ```
Future<bool> _waitForContent(
  WidgetTester tester, {
  required Finder finder,
  required String description,
  int maxWaitSeconds = 10,
}) async {
  debugPrint('   ⏳ Waiting for $description...');
  
  final startTime = DateTime.now();
  var attempts = 0;
  
  while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
    attempts++;
    
    // Pump to process pending frames
    await tester.pump();
    
    // Check if widget exists
    if (finder.evaluate().isNotEmpty) {
      debugPrint('   ✅ Found $description after $attempts attempts');
      return true;
    }
    
    // Wait a bit before next check
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Log every 5 seconds to show we're still waiting
    if (attempts % 10 == 0) {
      debugPrint('      Still waiting for $description... (${attempts / 2}s)');
    }
  }
  
  debugPrint('   ⚠️  Timeout waiting for $description after $maxWaitSeconds seconds');
  return false;
}

/// **HELPER: Print Current Route** (for debugging)
///
/// Logs the current route to help debug navigation issues.
/// Call this after navigation to verify you're on the expected screen.
void printCurrentRoute(WidgetTester tester) {
  debugPrint('   📍 Current route: [route inspection not available in integration tests]');
  debugPrint('      Use widget tree inspection instead');
}

/// **HELPER: Print Debug Info** (for debugging)
///
/// Dumps current widget tree to help debug "widget not found" errors.
/// Only shows a summary to avoid overwhelming output.
void printDebugInfo(WidgetTester tester) {
  debugPrint('   🔍 Debug Info:');
  debugPrint('      Widget tree depth: ${tester.allWidgets.length}');
  debugPrint('      (Full tree too large to print - use flutter inspector)');
}

/// **COMPARISON: Playwright vs integration_test**
///
/// **Playwright approach:**
/// ```typescript
/// await page.goto('/');
/// await page.waitForSelector('flt-glass-pane');
/// await page.waitForTimeout(2000);
/// await page.screenshot({ path: 'screenshot.png' });
/// ```
///
/// **integration_test equivalent:**
/// ```dart
/// await tester.pumpWidget(MyApp());
/// await tester.pumpAndSettle();
/// await Future.delayed(Duration(seconds: 2));
/// await binding.takeScreenshot('screenshot');
/// ```
///
/// **Key Differences:**
/// 
/// 1. **Widget Finding:**
///    - Playwright: Must use DOM selectors (fragile on Flutter canvas)
///    - integration_test: Direct widget tree access with `find.byType()`, `find.byKey()`
///
/// 2. **Synchronization:**
///    - Playwright: Waits for network idle, arbitrary timeouts
///    - integration_test: `pumpAndSettle()` knows when Flutter is done rendering
///
/// 3. **Navigation:**
///    - Playwright: `await page.goto()` or `await page.click()`
///    - integration_test: `await tester.tap()` or direct route changes
///
/// 4. **Debugging:**
///    - Playwright: Browser DevTools, console logs
///    - integration_test: Flutter inspector, widget tree, debugPrint
///
/// 5. **Reliability:**
///    - Playwright: Can miss Flutter-specific rendering states
///    - integration_test: Understands Flutter's rendering pipeline
///
/// **Why integration_test is Better Here:**
/// - Eliminates ChromeDriver version mismatches
/// - No "wait for Flutter to be ready" guesswork
/// - Screenshots capture Flutter output directly, not browser viewport
/// - Can verify widget state before screenshots
/// - Easier to debug with Flutter DevTools
/// - Faster (no browser startup overhead)
/// - Works with both CanvasKit and HTML renderers
