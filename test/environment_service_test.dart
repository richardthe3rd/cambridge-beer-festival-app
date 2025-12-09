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
}
