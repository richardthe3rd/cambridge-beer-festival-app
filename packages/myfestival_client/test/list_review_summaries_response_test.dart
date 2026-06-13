import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListReviewSummariesResponse
void main() {
  final instance = ListReviewSummariesResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListReviewSummariesResponse, () {
    // Aggregate review signals for this page, one per reviewed drink.
    // BuiltList<ReviewSummary> reviewSummaries
    test('to test the property `reviewSummaries`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks with at least one review at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
