import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Agent-facing markdown restates the toolchain versions that `pubspec.yaml`
/// and `mise.toml` own. It has to: a code-review agent reads the prose, not the
/// build files, and "check the pubspec" is a weaker prompt than a stated fact.
///
/// Restatement rots. `.github/copilot-instructions.md` once declared the Dart
/// SDK as `>=3.2.0` while `pubspec.yaml` required `>=3.10.0`, so Copilot code
/// review was primed to believe the project predated the language features it
/// was reading — and it rejected valid Dart 3.9 syntax as a compile error
/// twice on PR #540 and once on PR #519.
///
/// This test pins the copies to their sources, so a toolchain bump fails here
/// instead of silently misinforming the reviewer for months. A failure means
/// update the listed docs, not edit this test.
void main() {
  const docs = <String>[
    'AGENTS.md',
    '.github/copilot-instructions.md',
    '.github/skills/code-review-dart/SKILL.md',
  ];

  late String dartConstraint;
  late String dartFloor;
  late String dartMax;
  late String flutterVersion;

  setUpAll(() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final sdkMatch = RegExp(r"sdk:\s*'(>=[^']+)'").firstMatch(pubspec);
    expect(
      sdkMatch,
      isNotNull,
      reason: 'could not read the Dart SDK constraint from pubspec.yaml',
    );
    dartConstraint = sdkMatch!.group(1)!;

    final bounds = RegExp(r'\d+\.\d+\.\d+').allMatches(dartConstraint).toList();
    expect(
      bounds.length,
      2,
      reason: 'expected a floor and an upper bound in "$dartConstraint"',
    );
    dartFloor = bounds.first.group(0)!;
    dartMax = bounds.last.group(0)!;

    final miseToml = File('mise.toml').readAsStringSync();
    final flutterMatch = RegExp(
      r'^flutter\s*=\s*"([^"]+)"',
      multiLine: true,
    ).firstMatch(miseToml);
    expect(
      flutterMatch,
      isNotNull,
      reason: 'could not read the pinned Flutter version from mise.toml',
    );
    flutterVersion = flutterMatch!.group(1)!;
  });

  String majorMinor(String version) => version.split('.').take(2).join('.');

  group('agent docs toolchain pins', () {
    test('every version token matches pubspec.yaml or mise.toml', () {
      // CalVer release tags (e.g. 2026.5.4) are examples, not toolchain pins.
      final calVer = RegExp(r'^\d{4}\.');
      final allowed = <String>{dartFloor, dartMax, flutterVersion};

      for (final path in docs) {
        final text = File(path).readAsStringSync();
        final tokens = RegExp(r'\b\d+\.\d+\.\d+\b')
            .allMatches(text)
            .map((m) => m.group(0)!)
            .where((token) => !calVer.hasMatch(token))
            .toSet();

        for (final token in tokens) {
          expect(
            allowed,
            contains(token),
            reason:
                '$path mentions version $token, which is not the Dart '
                'constraint ($dartConstraint) or the Flutter pin '
                '($flutterVersion). Update the doc, or add the new source '
                'to this test.',
          );
        }
      }
    });

    test('shorthand Dart floors match the pubspec constraint', () {
      // Prose uses ">=3.10" as well as the full ">=3.10.0 <4.0.0". Language
      // history ("stable since Dart 3.9") is deliberately not matched here —
      // those are immutable facts, not restated pins.
      final expected = '>=${majorMinor(dartFloor)}';

      for (final path in docs) {
        final text = File(path).readAsStringSync();
        for (final match in RegExp(r'>=\d+\.\d+').allMatches(text)) {
          expect(
            match.group(0),
            expected,
            reason:
                '$path states a Dart floor of ${match.group(0)}, but '
                'pubspec.yaml requires $dartConstraint.',
          );
        }
      }
    });

    test('shorthand Flutter versions match the mise pin', () {
      final expected = 'Flutter ${majorMinor(flutterVersion)}';

      for (final path in docs) {
        final text = File(path).readAsStringSync();
        for (final match in RegExp(r'Flutter \d+\.\d+').allMatches(text)) {
          expect(
            match.group(0),
            expected,
            reason:
                '$path states ${match.group(0)}, but mise.toml pins '
                'Flutter $flutterVersion.',
          );
        }
      }
    });

    test('the Copilot review docs still state both versions', () {
      // The whole point of the restatement is that the reviewer sees it, so an
      // update that deletes the anchor should fail too.
      for (final path in docs) {
        final text = File(path).readAsStringSync();
        expect(
          text,
          contains(dartFloor),
          reason: '$path no longer states the Dart floor $dartFloor.',
        );
        expect(
          text,
          contains(flutterVersion),
          reason: '$path no longer states the Flutter pin $flutterVersion.',
        );
      }
    });
  });
}
