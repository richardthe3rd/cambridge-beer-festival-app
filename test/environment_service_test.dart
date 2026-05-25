import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/environment_service.dart';

void main() {
  group('EnvironmentService', () {
    test('isProduction returns true on mobile platforms', () {
      // On non-web platforms, should always return true
      // This test runs on VM, not web
      expect(EnvironmentService.isProduction(), isTrue);
    });

    test('getEnvironmentName returns mobile on mobile platforms', () {
      // On non-web platforms, should return 'mobile'
      expect(EnvironmentService.getEnvironmentName(), equals('mobile'));
    });
  });

  group('isProductionHost()', () {
    test('production custom domain → true', () {
      expect(
          EnvironmentService.isProductionHost('cambeerfestival.app'), isTrue);
    });

    test('staging custom domain → false', () {
      expect(EnvironmentService.isProductionHost('staging.cambeerfestival.app'),
          isFalse);
    });

    test('staging Cloudflare Pages subdomain → false', () {
      expect(
        EnvironmentService.isProductionHost(
            'abc123.staging-cambeerfestival.pages.dev'),
        isFalse,
      );
    });

    test('Cloudflare Pages PR preview host → false', () {
      expect(
        EnvironmentService.isProductionHost('pr-42.cambeerfestival.pages.dev'),
        isFalse,
      );
    });

    test('main Cloudflare Pages deployment → false', () {
      expect(
        EnvironmentService.isProductionHost('main.cambeerfestival.pages.dev'),
        isFalse,
      );
    });

    test('localhost → false', () {
      expect(EnvironmentService.isProductionHost('localhost'), isFalse);
    });

    test('loopback IP → false', () {
      expect(EnvironmentService.isProductionHost('127.0.0.1'), isFalse);
    });

    test('unknown host → false', () {
      // Safe default: unknown hosts should not be treated as production
      // to avoid accidentally logging staging/test traffic.
      expect(
          EnvironmentService.isProductionHost('mystery.example.com'), isFalse);
    });
  });

  group('classifyHostname()', () {
    test('production custom domain → "production"', () {
      expect(EnvironmentService.classifyHostname('cambeerfestival.app'),
          equals('production'));
    });

    test('staging custom domain → "staging"', () {
      expect(
        EnvironmentService.classifyHostname('staging.cambeerfestival.app'),
        equals('staging'),
      );
    });

    test('staging Cloudflare Pages subdomain → "preview"', () {
      expect(
        EnvironmentService.classifyHostname(
            'abc123.staging-cambeerfestival.pages.dev'),
        equals('preview'),
      );
    });

    test('Cloudflare Pages PR preview host → "preview"', () {
      expect(
        EnvironmentService.classifyHostname('pr-42.cambeerfestival.pages.dev'),
        equals('preview'),
      );
    });

    test('localhost → "development"', () {
      expect(EnvironmentService.classifyHostname('localhost'),
          equals('development'));
    });

    test('loopback IP → "development"', () {
      expect(EnvironmentService.classifyHostname('127.0.0.1'),
          equals('development'));
    });

    test('unknown host → "unknown"', () {
      expect(EnvironmentService.classifyHostname('mystery.example.com'),
          equals('unknown'));
    });
  });
}
