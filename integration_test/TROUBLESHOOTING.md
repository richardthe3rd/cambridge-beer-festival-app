# Troubleshooting Guide: Screenshot Integration Tests

## 🎯 Decision Tree for Human Developer

```
START: Run minimal test first
│
├─ Run: flutter drive --driver=test_driver/integration_test.dart \
│              --target=integration_test/screenshot_test.dart \
│              -d web-server
│
├─ Check: screenshots/00-hello-test.png exists and shows "HELLO"
│
├─ ✅ SUCCESS: Screenshot is visible
│  │
│  └─ NEXT: Run full app test (same command, it includes both tests)
│     │
│     ├─ ✅ SUCCESS: All screenshots created
│     │  └─ NEXT: Set up GitHub Actions workflow
│     │     └─ See "GitHub Actions Setup" section below
│     │
│     └─ ❌ FAIL: Some screenshots missing or navigation failed
│        └─ See "Navigation Issues" section below
│
└─ ❌ FAIL: Screenshot is empty, black, or doesn't exist
   │
   └─ TRY THESE IN ORDER:
      │
      ├─ 1. Increase delay to 5 seconds
      │  │  Edit screenshot_test.dart, line with:
      │  │  await Future.delayed(Duration(seconds: 2));
      │  │  Change to: await Future.delayed(Duration(seconds: 5));
      │  │  Re-run test
      │  └─ If still fails → Try #2
      │
      ├─ 2. Check ChromeDriver is running
      │  │  In separate terminal: chromedriver --port=4444
      │  │  Look for "ChromeDriver was started successfully"
      │  │  Re-run test
      │  └─ If still fails → Try #3
      │
      ├─ 3. Verify Flutter web build works
      │  │  flutter build web --web-renderer html
      │  │  Check build/web exists
      │  └─ If build fails → Fix build errors first
      │
      └─ 4. Enable debug logging
         │  Add to test: debugPrint('Screenshot bytes: ${screenshotBytes.length}');
         │  Check if bytes are actually captured
         └─ If 0 bytes → See "Screenshot Capture Failures" below
```

## 🐛 Symptom-Based Troubleshooting

### SYMPTOM: Empty/Black Screenshots

#### Cause A: Taking screenshot too early (before rendering completes)

**How to verify:**
```bash
# Check screenshot file size
ls -lh screenshots/
# If files are < 5KB, likely empty/black
```

**Solutions (try in order):**

1. **Increase delays in screenshot_test.dart:**
   ```dart
   // Find this line in the test (appears multiple times)
   await Future.delayed(Duration(seconds: 2));
   
   // Change to:
   await Future.delayed(Duration(seconds: 5));
   ```

2. **Increase pumpAndSettle timeout:**
   ```dart
   // Find this line
   await tester.pumpAndSettle(Duration(seconds: 10));
   
   // Change to:
   await tester.pumpAndSettle(Duration(seconds: 15));
   ```

3. **Add content verification before screenshot:**
   ```dart
   // Before taking screenshot, verify content exists
   expect(find.byType(Scaffold), findsOneWidget);
   await Future.delayed(Duration(seconds: 2));
   await binding.takeScreenshot('my-screenshot');
   ```

#### Cause B: HTML renderer needs more time

**How to verify:**
```bash
# Check test output for "pumpAndSettle completed" messages
# If they appear immediately, rendering might not be done
```

**Solution:**
Add explicit frame pumps:
```dart
await tester.pumpAndSettle();
// Add these manual pumps
await tester.pump(Duration(milliseconds: 100));
await tester.pump(Duration(milliseconds: 100));
await tester.pump(Duration(milliseconds: 100));
await Future.delayed(Duration(seconds: 3));
await binding.takeScreenshot('my-screenshot');
```

#### Cause C: Screenshot driver not saving files

**How to verify:**
```bash
# Check test output for "Saving screenshot:" messages
# If missing, driver isn't receiving screenshot data
```

**Solution:**
Check test_driver/integration_test.dart is correct:
```dart
// Verify this callback exists
onScreenshot: (String screenshotName, List<int> screenshotBytes,
    [Map<String, Object?>? args]) async {
  print('📸 Saving screenshot: $screenshotName.png');
  // ... rest of callback
}
```

---

### SYMPTOM: "Widget Not Found" Errors

#### Cause A: Widget doesn't have a Key

**Error message:**
```
Expected: exactly one matching node
Actual: _WidgetIterable:<empty>
```

**Solution - Add Key to widget:**

Find the widget in source code and add a Key:

```dart
// Example: Info button in drinks_screen.dart
// BEFORE:
IconButton(
  icon: Icon(Icons.info_outline),
  onPressed: () => context.go('/about'),
)

// AFTER:
IconButton(
  key: Key('info_button'),  // Add this line
  icon: Icon(Icons.info_outline),
  onPressed: () => context.go('/about'),
)
```

Then update test to use the Key:
```dart
// BEFORE:
await tester.tap(find.byIcon(Icons.info_outline));

// AFTER:
await tester.tap(find.byKey(Key('info_button')));
```

**Common widgets that need Keys:**
- Navigation buttons
- Tab bar items
- Action buttons in app bars
- List items (use `Key('item_${id}')`)

#### Cause B: Widget hasn't rendered yet

**Error message:**
```
Expected: exactly one matching node
Actual: _WidgetIterable:<empty>
```
(Same error as Cause A, but different root cause)

**How to verify:**
```dart
// Add debugging before the failing line
debugPrint('Looking for widget...');
await tester.pump();
await tester.pump();
await tester.pump();
debugPrint('Widget count: ${find.byType(MyWidget).evaluate().length}');
```

**Solution:**
Wait longer before looking for widget:
```dart
await tester.pumpAndSettle(Duration(seconds: 10));
await Future.delayed(Duration(seconds: 2));

// Now try to find widget
final widget = find.byType(MyWidget);
expect(widget, findsOneWidget);
```

#### Cause C: Navigation didn't complete

**Error message:**
```
Expected: exactly one matching node (on new screen)
Actual: _WidgetIterable:<empty>
```

**How to verify:**
```dart
// After navigation, verify you're on the right screen
await tester.tap(find.byKey(Key('my_button')));
await tester.pumpAndSettle(Duration(seconds: 5));

// Check for widget that should be on new screen
if (find.text('New Screen Title').evaluate().isEmpty) {
  debugPrint('ERROR: Navigation did not complete!');
  // You're still on the old screen
}
```

**Solution:**
Ensure tap is working:
```dart
// Make sure widget is tappable
await tester.ensureVisible(find.byKey(Key('my_button')));
await tester.pumpAndSettle();

// Tap in the center of the widget
await tester.tap(find.byKey(Key('my_button')));
await tester.pumpAndSettle(Duration(seconds: 5));

// Verify navigation
expect(find.text('New Screen Title'), findsOneWidget);
```

---

### SYMPTOM: ChromeDriver Connection Failed

#### Error message:
```
DriverError: Failed to connect to ChromeDriver
Could not connect to http://localhost:4444
```

#### Cause A: ChromeDriver not running

**How to verify:**
```bash
curl http://localhost:4444/status
# Should return JSON with "ready": true
```

**Solution:**
Start ChromeDriver:
```bash
# In a separate terminal
chromedriver --port=4444

# Should see:
# ChromeDriver was started successfully on port 4444.
```

#### Cause B: ChromeDriver version mismatch

**How to verify:**
```bash
google-chrome --version
chromedriver --version

# Major versions should match:
# Chrome: 131.0.6778.139
# ChromeDriver: 131.0.6778.204
# ✅ Both start with 131
```

**Solution:**
Install matching ChromeDriver version:

For Chrome 131.x:
```bash
# Get latest ChromeDriver for Chrome 131
LATEST_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_131")
wget "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$LATEST_VERSION/linux64/chromedriver-linux64.zip"
unzip chromedriver-linux64.zip
sudo mv chromedriver-linux64/chromedriver /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
chromedriver --version
```

For Chrome 115-130:
```bash
CHROME_MAJOR=130  # Replace with your major version
LATEST_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$CHROME_MAJOR")
wget "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$LATEST_VERSION/linux64/chromedriver-linux64.zip"
unzip chromedriver-linux64.zip
sudo mv chromedriver-linux64/chromedriver /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
```

#### Cause C: Port already in use

**How to verify:**
```bash
lsof -i :4444
# If shows a process, port is in use
```

**Solution:**
Kill the existing process:
```bash
# Find the PID
lsof -i :4444

# Kill it
kill <PID>

# Or use fuser
fuser -k 4444/tcp

# Then start ChromeDriver
chromedriver --port=4444
```

---

### SYMPTOM: Tests Timeout

#### Error message:
```
Test timed out after 2 minutes
```

#### Cause A: CI is slower than local

**Solution:**
Increase timeout in test:
```dart
testWidgets('My test', (tester) async {
  // Test code...
}, timeout: Timeout(Duration(minutes: 5)));  // Increase this
```

#### Cause B: API is very slow

**How to verify:**
```bash
# Check test output for "Waiting for drinks list data..."
# If this message repeats many times, API is slow
```

**Solution:**
Increase maxWaitSeconds for API content:
```dart
await _waitForContent(
  tester,
  description: 'drinks list data',
  finder: find.byType(RefreshIndicator),
  maxWaitSeconds: 30,  // Increase from 15 to 30
);
```

#### Cause C: Deadlock waiting for widget

**How to verify:**
```bash
# Test output shows "Still waiting..." messages that never end
```

**Solution:**
The widget will never appear - check that:
1. You're looking for the right widget type
2. Navigation completed successfully
3. Widget is actually on the screen you think you're on

```dart
// Debug by listing all widgets on screen
debugPrint('Widgets on screen:');
for (var widget in tester.allWidgets.take(20)) {
  debugPrint('  - ${widget.runtimeType}');
}
```

---

### SYMPTOM: Screenshots Show Loading Indicators

#### Cause: API data hasn't loaded yet

**How to verify:**
Screenshot shows spinning CircularProgressIndicator or "Loading..." text.

**Solution:**
Increase wait time after app startup:
```dart
// In screenshot_test.dart, after app launch
await tester.pumpWidget(const app.BeerFestivalApp());
await tester.pumpAndSettle(Duration(seconds: 10));
await Future.delayed(Duration(seconds: 5));  // Increase this to 10
```

For detail screens, increase wait after navigation:
```dart
await tester.tap(drinkCards.at(2));
await tester.pumpAndSettle(Duration(seconds: 10));
await Future.delayed(Duration(seconds: 5));  // Increase this to 10
```

---

### SYMPTOM: GitHub Actions Workflow Fails

#### Cause A: ChromeDriver setup failed

**How to verify:**
Check workflow logs for:
```
Error: Failed to download ChromeDriver
404 Not Found
```

**Solution:**
Update `.github/workflows/screenshots.yml`:

The ChromeDriver download URL may have changed. Check the "Setup ChromeDriver" step and update the version:

```yaml
- name: Setup ChromeDriver
  run: |
    # Update this version to match Chrome on ubuntu-latest
    LATEST_VERSION=131.0.6778.204  # Check current ubuntu Chrome version
    wget "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$LATEST_VERSION/linux64/chromedriver-linux64.zip"
    # ... rest of step
```

#### Cause B: Flutter version mismatch

**How to verify:**
Check workflow logs for:
```
Error: The Flutter SDK is not available
```

**Solution:**
Update Flutter version in workflow:
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.38.3'  # Update to latest stable
```

#### Cause C: Screenshots not created

**How to verify:**
Check workflow logs for:
```
Error: No screenshots found to upload
```

**Solution:**
1. Check "Run screenshot integration test" step logs
2. Look for errors in test execution
3. Download "chromedriver-logs" artifact to see ChromeDriver errors
4. Download "screenshots-artifacts" artifact to see what was created

Common fixes:
- Increase test timeout in workflow
- Add retry logic for flaky API calls
- Skip detail screens if API is down

---

## 🔧 GitHub Actions Setup Guide

Once local testing works, set up CI:

### Step 1: Verify Local Test Works

```bash
# This should complete successfully and create screenshots
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d web-server
```

### Step 2: Commit and Push

```bash
git add integration_test/ test_driver/ .github/workflows/screenshots.yml pubspec.yaml
git commit -m "Add integration_test screenshot capture"
git push
```

### Step 3: Create PR

Create a pull request to `main`. The workflow should trigger automatically.

### Step 4: Monitor Workflow

1. Go to GitHub Actions tab
2. Find "Screenshot Capture (integration_test)" workflow
3. Click on the running workflow
4. Monitor each step

**Expected timeline:**
- Setup: ~1 min
- ChromeDriver setup: ~30 sec
- Run tests: ~2-5 min
- Upload screenshots: ~30 sec

### Step 5: Troubleshoot Failures

If workflow fails:

1. **Check the failing step** in workflow logs
2. **Download artifacts** (chromedriver-logs, screenshots-artifacts)
3. **Read error message** carefully
4. **Find matching symptom** in this guide
5. **Apply fix** and push again

### Step 6: Verify Success

When workflow succeeds:

1. Check PR has a comment with screenshots
2. Screenshots should be visible in the comment
3. Navigate to `pr-screenshots` branch to see uploaded files

---

## 🎓 Learning from Test Output

### Good Test Output (Success):

```
🧪 Running minimal screenshot test...
   Waiting for web rendering...
   Taking screenshot...
✅ Minimal screenshot test complete

🚀 Starting full app screenshot capture...
   Launching app...
   Waiting for app initialization...
   App initialized, starting screenshot capture

📸 Capturing: Drinks List (Home)
   ⏳ Waiting for drinks list data...
   ✅ Found drinks list data after 8 attempts
✅ Captured: Drinks List

📸 Capturing: Favorites (empty state)
   Tapping favorites tab...
✅ Captured: Favorites

...

✨ Screenshot capture complete!
   Check the screenshots/ directory for output files
```

### Bad Test Output (Failure):

```
🧪 Running minimal screenshot test...
   Waiting for web rendering...
   Taking screenshot...
Error: Screenshot file is very small (2.1 KB)
   This might indicate a blank or mostly empty screenshot

❌ Widget not found: find.byType(RefreshIndicator)
Expected: exactly one matching node
Actual: _WidgetIterable:<empty>
```

**What to look for:**
- Warning emoji (⚠️) and error emoji (❌)
- "Timeout waiting for..." messages
- "Widget not found" errors
- Small screenshot file sizes
- Missing "Found X after Y attempts" messages

---

## 📞 Getting Help

If you're still stuck after trying this guide:

### 1. Gather Information

Run test with verbose logging:
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d web-server \
  --verbose
```

Save output:
```bash
flutter drive ... > test-output.log 2>&1
```

### 2. Check These Files

- Test output: `test-output.log`
- ChromeDriver log: `chromedriver.log`
- Screenshots: `ls -lh screenshots/`
- CI logs: Download from GitHub Actions artifacts

### 3. Create Issue

Open issue with:
- **Symptom**: What's failing (empty screenshots, widget not found, etc.)
- **Output**: Paste relevant error messages
- **Environment**: Local or CI? OS? Flutter version?
- **What you tried**: List solutions from this guide you've attempted

### 4. Debugging Checklist

Before asking for help, verify:

- [ ] ChromeDriver is running (`curl http://localhost:4444/status`)
- [ ] ChromeDriver version matches Chrome
- [ ] Flutter version is 3.38.3 or later
- [ ] `flutter pub get` completed successfully
- [ ] Minimal test passes (00-hello-test.png exists)
- [ ] You've tried increasing delays
- [ ] You've checked test output for error messages

---

## 🚀 Success Criteria

You'll know the migration is complete when:

- ✅ Local test creates all screenshots
- ✅ Screenshots are not empty/black
- ✅ Navigation works (favorites, about, detail screens)
- ✅ GitHub Actions workflow succeeds
- ✅ PR comment shows all screenshots
- ✅ Screenshots show actual app content (not loading states)
- ✅ Workflow completes in < 5 minutes
- ✅ No ChromeDriver errors in logs

**Next step after success:** Remove Playwright screenshot code and update documentation.
