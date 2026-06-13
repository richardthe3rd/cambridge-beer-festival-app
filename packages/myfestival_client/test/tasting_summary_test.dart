import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for TastingSummary
void main() {
  final instance = TastingSummaryBuilder();
  // TODO add properties to the builder and call build()

  group(TastingSummary, () {
    // Resource name: festivals/{festival}/tastingSummaries/{drink}.
    // String name
    test('to test the property `name`', () async {
      // TODO
    });

    // Number of distinct callers who have logged a tasting for this drink.
    // int tasterCount
    test('to test the property `tasterCount`', () async {
      // TODO
    });

    // Total pours logged across all callers.
    // int totalPours
    test('to test the property `totalPours`', () async {
      // TODO
    });

  });
}
