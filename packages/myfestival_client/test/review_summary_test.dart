import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ReviewSummary
void main() {
  final instance = ReviewSummaryBuilder();
  // TODO add properties to the builder and call build()

  group(ReviewSummary, () {
    // Resource name: festivals/{festival}/reviewSummaries/{drink}.
    // String name
    test('to test the property `name`', () async {
      // TODO
    });

    // Number of callers who have submitted a star rating.
    // int ratingCount
    test('to test the property `ratingCount`', () async {
      // TODO
    });

    // Mean star rating across all callers (1.0–5.0); 0 when rating_count is 0.
    // double averageRating
    test('to test the property `averageRating`', () async {
      // TODO
    });

    // Number of callers who have answered the \"would recommend\" question.
    // int responseCount
    test('to test the property `responseCount`', () async {
      // TODO
    });

    // Number of callers who answered \"yes\" to the recommendation question.
    // int recommendCount
    test('to test the property `recommendCount`', () async {
      // TODO
    });

    // Fraction of responses (0.0–1.0) that would recommend; 0 when  response_count is 0.
    // double recommendRate
    test('to test the property `recommendRate`', () async {
      // TODO
    });

  });
}
