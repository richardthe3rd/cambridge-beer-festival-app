import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListTastingsResponse
void main() {
  final instance = ListTastingsResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListTastingsResponse, () {
    // The caller's tasting records for this page, one per tried drink.
    // BuiltList<Tasting> tastings
    test('to test the property `tastings`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks the caller has tried at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
