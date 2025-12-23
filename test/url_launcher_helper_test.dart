import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/utils/url_launcher_helper.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

// Mock for UrlLauncherPlatform
class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool canLaunchResult = true;
  bool shouldThrowOnCanLaunch = false;
  bool shouldThrowOnLaunch = false;
  String? lastLaunchedUrl;

  @override
  Future<bool> canLaunch(String url) async {
    if (shouldThrowOnCanLaunch) {
      throw Exception('Network error');
    }
    return canLaunchResult;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    lastLaunchedUrl = url;
    if (shouldThrowOnLaunch) {
      throw Exception('Launch failed');
    }
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    if (shouldThrowOnLaunch) {
      throw Exception('Launch failed');
    }
    return true;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async {
    return true;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async {
    return false;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  group('UrlLauncherHelper', () {
    late MockUrlLauncherPlatform mockUrlLauncher;

    setUp(() {
      mockUrlLauncher = MockUrlLauncherPlatform();
      mockUrlLauncher.canLaunchResult = true;
      mockUrlLauncher.shouldThrowOnCanLaunch = false;
      mockUrlLauncher.shouldThrowOnLaunch = false;
      UrlLauncherPlatform.instance = mockUrlLauncher;
    });

    testWidgets('launchURL successfully launches valid URL', (tester) async {
      mockUrlLauncher.canLaunchResult = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await UrlLauncherHelper.launchURL(
                      context,
                      'https://example.com',
                    );
                    expect(result, true);
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.lastLaunchedUrl, 'https://example.com');
    });

    testWidgets('launchURL shows error snackbar when URL cannot be launched',
        (tester) async {
      mockUrlLauncher.canLaunchResult = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await UrlLauncherHelper.launchURL(
                      context,
                      'https://invalid.com',
                    );
                    expect(result, false);
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('Could not open URL'), findsOneWidget);
    });

    testWidgets('launchURL shows custom error message when provided',
        (tester) async {
      mockUrlLauncher.canLaunchResult = false;

      const customErrorMessage = 'Failed to open website';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await UrlLauncherHelper.launchURL(
                      context,
                      'https://invalid.com',
                      errorMessage: customErrorMessage,
                    );
                    expect(result, false);
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Verify custom error message is shown
      expect(find.text(customErrorMessage), findsOneWidget);
    });

    testWidgets('launchURL handles exception gracefully', (tester) async {
      mockUrlLauncher.shouldThrowOnCanLaunch = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await UrlLauncherHelper.launchURL(
                      context,
                      'https://example.com',
                    );
                    expect(result, false);
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      // Verify error snackbar is shown
      expect(find.text('Could not open URL'), findsOneWidget);
    });

    testWidgets('launchURL returns true on successful launch', (tester) async {
      mockUrlLauncher.canLaunchResult = true;

      bool? launchResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    launchResult = await UrlLauncherHelper.launchURL(
                      context,
                      'https://example.com',
                    );
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(launchResult, true);
    });

    testWidgets('launchURL returns false when launch fails', (tester) async {
      mockUrlLauncher.canLaunchResult = false;

      bool? launchResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    launchResult = await UrlLauncherHelper.launchURL(
                      context,
                      'https://invalid.com',
                    );
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(launchResult, false);
    });

    testWidgets('launchURL parses URL correctly', (tester) async {
      mockUrlLauncher.canLaunchResult = true;

      const testUrl = 'https://cambeerfestival.com/2025';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await UrlLauncherHelper.launchURL(context, testUrl);
                  },
                  child: const Text('Launch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.lastLaunchedUrl, testUrl);
    });
  });
}
