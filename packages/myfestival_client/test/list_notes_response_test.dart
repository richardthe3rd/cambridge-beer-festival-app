import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for ListNotesResponse
void main() {
  final instance = ListNotesResponseBuilder();
  // TODO add properties to the builder and call build()

  group(ListNotesResponse, () {
    // The caller's notes for this page, one per noted drink.
    // BuiltList<Note> notes
    test('to test the property `notes`', () async {
      // TODO
    });

    // Token for the next page; empty when there are no more results.
    // String nextPageToken
    test('to test the property `nextPageToken`', () async {
      // TODO
    });

    // Total number of drinks the caller has notes for at this festival.
    // int totalSize
    test('to test the property `totalSize`', () async {
      // TODO
    });

  });
}
