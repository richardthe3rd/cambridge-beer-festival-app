import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListTastingSummariesResponse
void main() {
  final instance = ListTastingSummariesResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListTastingSummariesResponse, () {
    // Tasting counts for this page, one per tried drink.
    // BuiltList<TastingSummary> tastingSummaries
    test('to test the property `tastingSummaries`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks tried by at least one caller at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
