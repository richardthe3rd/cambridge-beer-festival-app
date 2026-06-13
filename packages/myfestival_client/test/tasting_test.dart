import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for Tasting
void main() {
  final instance = TastingBuilder();
  // TODO add properties to the builder and call build()

  group(Tasting, () {
    // Resource name: festivals/{festival}/drinks/{drink}/tasting.
    // String name
    test('to test the property `name`', () async {
      // TODO
    });

    // How many times the caller has had this drink. Absent means one pour.  Must be >= 1 when present.
    // int pours
    test('to test the property `pours`', () async {
      // TODO
    });

    // When the caller first tried this drink.
    // DateTime createTime
    test('to test the property `createTime`', () async {
      // TODO
    });

    // When this record was last updated.
    // DateTime updateTime
    test('to test the property `updateTime`', () async {
      // TODO
    });

  });
}
