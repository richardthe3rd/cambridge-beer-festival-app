import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for Review
void main() {
  final instance = ReviewBuilder();
  // TODO add properties to the builder and call build()

  group(Review, () {
    // Resource name: festivals/{festival}/drinks/{drink}/review.
    // String name
    test('to test the property `name`', () async {
      // TODO
    });

    // Star rating, 1–5 inclusive. Absent if the caller has not set a star rating.
    // int starRating
    test('to test the property `starRating`', () async {
      // TODO
    });

    // Whether the caller would recommend this drink. Absent if not answered.
    // bool wouldRecommend
    test('to test the property `wouldRecommend`', () async {
      // TODO
    });

    // When this review was last written.
    // DateTime updateTime
    test('to test the property `updateTime`', () async {
      // TODO
    });

  });
}
