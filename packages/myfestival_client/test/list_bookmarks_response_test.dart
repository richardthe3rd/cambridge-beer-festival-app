import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListBookmarksResponse
void main() {
  final instance = ListBookmarksResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListBookmarksResponse, () {
    // The caller's bookmarks for this page, one per bookmarked drink.
    // BuiltList<Bookmark> bookmarks
    test('to test the property `bookmarks`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks the caller has bookmarked at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
