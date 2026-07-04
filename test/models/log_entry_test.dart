import 'package:cambridge_beer_festival/models/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogEntry', () {
    LogEntry sample() => LogEntry(
      id: 'entry-1',
      when: DateTime.fromMillisecondsSinceEpoch(1747526400000),
      drinkId: 'beer-1',
      note: 'Lovely hoppy finish',
      photoIds: const ['p1', 'p2'],
      rating: 4,
      wouldRecommend: true,
    );

    test('isTasting is true when drinkId is set, false otherwise', () {
      expect(sample().isTasting, isTrue);
      final other = LogEntry(
        id: 'e2',
        when: DateTime(2026, 6, 10),
        title: 'Scotch egg from the pie stall',
      );
      expect(other.isTasting, isFalse);
    });

    test('normalises when to millisecond precision', () {
      final micro = DateTime.fromMicrosecondsSinceEpoch(1747526400000456);
      final entry = LogEntry(id: 'e', when: micro);
      expect(entry.when, DateTime.fromMillisecondsSinceEpoch(1747526400000));
    });

    test('photoIds defaults to empty and is unmodifiable', () {
      final entry = LogEntry(id: 'e', when: DateTime(2026));
      expect(entry.photoIds, isEmpty);
      expect(() => entry.photoIds.add('x'), throwsUnsupportedError);
    });

    group('JSON round-trip', () {
      test('toJson then fromJson preserves all fields', () {
        final entry = sample();
        final restored = LogEntry.fromJson(entry.toJson());
        expect(restored, equals(entry));
      });

      test('stores when as millisecondsSinceEpoch', () {
        expect(sample().toJson()['when'], 1747526400000);
      });

      test('parses missing optional fields as null/empty', () {
        final entry = LogEntry.fromJson({'id': 'e', 'when': 1747526400000});
        expect(entry.drinkId, isNull);
        expect(entry.title, isNull);
        expect(entry.note, isNull);
        expect(entry.rating, isNull);
        expect(entry.wouldRecommend, isNull);
        expect(entry.photoIds, isEmpty);
      });

      test('parses a whole-number millis handed back as double (web)', () {
        final entry = LogEntry.fromJson({
          'id': 'e',
          'when': 1747526400000.0,
          'rating': 3.0,
        });
        expect(entry.when.millisecondsSinceEpoch, 1747526400000);
        expect(entry.rating, 3);
      });
    });

    group('copyWith', () {
      test('replaces only the given fields', () {
        final updated = sample().copyWith(rating: 5, note: 'Even better');
        expect(updated.rating, 5);
        expect(updated.note, 'Even better');
        expect(updated.id, 'entry-1');
        expect(updated.drinkId, 'beer-1');
      });

      test('can explicitly clear nullable fields with null', () {
        final cleared = sample().copyWith(
          rating: null,
          note: null,
          drinkId: null,
          wouldRecommend: null,
        );
        expect(cleared.rating, isNull);
        expect(cleared.note, isNull);
        expect(cleared.drinkId, isNull);
        expect(cleared.wouldRecommend, isNull);
        expect(cleared.isTasting, isFalse);
      });

      test('omitting an argument leaves the field unchanged', () {
        final same = sample().copyWith();
        expect(same, equals(sample()));
      });
    });

    test('== and hashCode are value-based', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, equals(sample().hashCode));
      expect(sample() == sample().copyWith(rating: 1), isFalse);
    });
  });
}
