import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';

// tests for Note
void main() {
  final instance = NoteBuilder();
  // TODO add properties to the builder and call build()

  group(Note, () {
    // Resource name: festivals/{festival}/drinks/{drink}/note.
    // String name
    test('to test the property `name`', () async {
      // TODO
    });

    // The caller's note text. Max 2000 Unicode characters.
    // String content
    test('to test the property `content`', () async {
      // TODO
    });

    // When this note was last written.
    // DateTime updateTime
    test('to test the property `updateTime`', () async {
      // TODO
    });

  });
}
