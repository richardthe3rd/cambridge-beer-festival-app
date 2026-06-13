import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListReviewsResponse
void main() {
  final instance = ListReviewsResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListReviewsResponse, () {
    // The caller's reviews for this page, one per reviewed drink.
    // BuiltList<Review> reviews
    test('to test the property `reviews`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks the caller has reviewed at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
