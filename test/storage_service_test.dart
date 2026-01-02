import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FavoritesService', () {
    late FavoritesService favoritesService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getFavorites returns empty map for new festival', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      final favorites = favoritesService.getFavorites('cbf2025');

      expect(favorites, isEmpty);
      expect(favorites, isA<Map<String, dynamic>>());
    });

    test('addFavorite adds drink to favorites with want_to_try status', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');

      final favorites = favoritesService.getFavorites('cbf2025');
      expect(favorites.containsKey('drink-123'), isTrue);
      expect(favorites['drink-123']!.status, 'want_to_try');
      expect(favorites['drink-123']!.tries, isEmpty);
    });

    test('addFavorite adds multiple drinks', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-1');
      await favoritesService.addFavorite('cbf2025', 'drink-2');
      await favoritesService.addFavorite('cbf2025', 'drink-3');

      final favorites = favoritesService.getFavorites('cbf2025');
      expect(favorites.length, 3);
      expect(favorites.keys, containsAll(['drink-1', 'drink-2', 'drink-3']));
    });

    test('removeFavorite removes drink from favorites', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      await favoritesService.removeFavorite('cbf2025', 'drink-123');

      final favorites = favoritesService.getFavorites('cbf2025');
      expect(favorites, isEmpty);
    });

    test('removeFavorite handles non-existent drink gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.removeFavorite('cbf2025', 'non-existent');

      // Should not throw and favorites should remain empty
      final favorites = favoritesService.getFavorites('cbf2025');
      expect(favorites, isEmpty);
    });

    test('toggleFavorite adds drink when not favorite', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      final result = await favoritesService.toggleFavorite('cbf2025', 'drink-123');

      expect(result, isTrue);
      expect(favoritesService.isFavorite('cbf2025', 'drink-123'), isTrue);

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item, isNotNull);
      expect(item!.status, 'want_to_try');
    });

    test('toggleFavorite removes drink when already favorite', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      final result = await favoritesService.toggleFavorite('cbf2025', 'drink-123');

      expect(result, isFalse);
      expect(favoritesService.isFavorite('cbf2025', 'drink-123'), isFalse);
    });

    test('isFavorite returns true for favorited drink', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');

      expect(favoritesService.isFavorite('cbf2025', 'drink-123'), isTrue);
    });

    test('isFavorite returns false for non-favorited drink', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      expect(favoritesService.isFavorite('cbf2025', 'non-existent'), isFalse);
    });

    test('favorites are scoped by festival ID', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      await favoritesService.addFavorite('cbf2024', 'drink-456');

      expect(favoritesService.isFavorite('cbf2025', 'drink-123'), isTrue);
      expect(favoritesService.isFavorite('cbf2025', 'drink-456'), isFalse);
      expect(favoritesService.isFavorite('cbf2024', 'drink-456'), isTrue);
      expect(favoritesService.isFavorite('cbf2024', 'drink-123'), isFalse);
    });

    test('getFavorites returns separate maps for different festivals', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-a');
      await favoritesService.addFavorite('cbf2025', 'drink-b');
      await favoritesService.addFavorite('cbf2024', 'drink-c');

      final favorites2025 = favoritesService.getFavorites('cbf2025');
      final favorites2024 = favoritesService.getFavorites('cbf2024');

      expect(favorites2025.length, 2);
      expect(favorites2024.length, 1);
      expect(favorites2025.keys, containsAll(['drink-a', 'drink-b']));
      expect(favorites2024.keys, contains('drink-c'));
    });

    test('markAsTasted creates tasted item with timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.markAsTasted('cbf2025', 'drink-123');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item, isNotNull);
      expect(item!.status, 'tasted');
      expect(item.tries.length, 1);
    });

    test('markAsTasted adds timestamp to existing want_to_try item', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      await favoritesService.markAsTasted('cbf2025', 'drink-123');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item, isNotNull);
      expect(item!.status, 'tasted');
      expect(item.tries.length, 1);
    });

    test('markAsTasted can be called multiple times', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.markAsTasted('cbf2025', 'drink-123');
      await favoritesService.markAsTasted('cbf2025', 'drink-123');
      await favoritesService.markAsTasted('cbf2025', 'drink-123');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item, isNotNull);
      expect(item!.tries.length, 3);
    });

    test('deleteTry removes specific timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.markAsTasted('cbf2025', 'drink-123');
      await favoritesService.markAsTasted('cbf2025', 'drink-123');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      final firstTry = item!.tries.first;

      await favoritesService.deleteTry('cbf2025', 'drink-123', firstTry);

      final updated = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(updated!.tries.length, 1);
      expect(updated.tries.contains(firstTry), isFalse);
    });

    test('deleteTry reverts to want_to_try when last timestamp removed', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.markAsTasted('cbf2025', 'drink-123');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      final timestamp = item!.tries.first;

      await favoritesService.deleteTry('cbf2025', 'drink-123', timestamp);

      final updated = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(updated!.status, 'want_to_try');
      expect(updated.tries, isEmpty);
    });

    test('deleteTry handles non-existent item gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      // Should not throw
      await favoritesService.deleteTry(
        'cbf2025',
        'non-existent',
        DateTime.now(),
      );
    });

    test('updateNotes sets notes on favorite item', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      await favoritesService.updateNotes('cbf2025', 'drink-123', 'Great beer!');

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item!.notes, 'Great beer!');
    });

    test('updateNotes can clear notes', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');
      await favoritesService.updateNotes('cbf2025', 'drink-123', 'Great beer!');
      await favoritesService.updateNotes('cbf2025', 'drink-123', null);

      final item = favoritesService.getFavoriteItem('cbf2025', 'drink-123');
      expect(item!.notes, isNull);
    });

    test('updateNotes handles non-existent item gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      // Should not throw
      await favoritesService.updateNotes('cbf2025', 'non-existent', 'Test');
    });

    test('saveFavorites persists data correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      favoritesService = FavoritesService(prefs);

      await favoritesService.addFavorite('cbf2025', 'drink-123');

      // Create new service instance with same prefs
      final service2 = FavoritesService(prefs);
      final favorites = service2.getFavorites('cbf2025');

      expect(favorites.containsKey('drink-123'), isTrue);
    });

    test('getFavorites handles corrupted data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();

      // Manually set corrupted data
      await prefs.setString('favorites_cbf2025', 'invalid json');

      favoritesService = FavoritesService(prefs);
      final favorites = favoritesService.getFavorites('cbf2025');

      // Should return empty map instead of throwing
      expect(favorites, isEmpty);
    });
  });

  group('RatingsService', () {
    late RatingsService ratingsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getRating returns null for unrated drink', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      final rating = ratingsService.getRating('cbf2025', 'drink-123');

      expect(rating, isNull);
    });

    test('setRating saves rating', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 4);

      final rating = ratingsService.getRating('cbf2025', 'drink-123');
      expect(rating, 4);
    });

    test('setRating rejects rating below 1', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      expect(
        () async => await ratingsService.setRating('cbf2025', 'drink-123', 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('setRating rejects rating above 5', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      expect(
        () async => await ratingsService.setRating('cbf2025', 'drink-123', 10),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('setRating accepts minimum valid rating of 1', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 1);

      final rating = ratingsService.getRating('cbf2025', 'drink-123');
      expect(rating, 1);
    });

    test('setRating accepts maximum valid rating of 5', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 5);

      final rating = ratingsService.getRating('cbf2025', 'drink-123');
      expect(rating, 5);
    });

    test('setRating overwrites previous rating', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 3);
      await ratingsService.setRating('cbf2025', 'drink-123', 5);

      final rating = ratingsService.getRating('cbf2025', 'drink-123');
      expect(rating, 5);
    });

    test('removeRating clears rating', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 4);
      await ratingsService.removeRating('cbf2025', 'drink-123');

      final rating = ratingsService.getRating('cbf2025', 'drink-123');
      expect(rating, isNull);
    });

    test('removeRating handles non-existent rating gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      // Should not throw
      await ratingsService.removeRating('cbf2025', 'non-existent');

      final rating = ratingsService.getRating('cbf2025', 'non-existent');
      expect(rating, isNull);
    });

    test('ratings are scoped by festival ID', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-123', 5);
      await ratingsService.setRating('cbf2024', 'drink-123', 3);

      expect(ratingsService.getRating('cbf2025', 'drink-123'), 5);
      expect(ratingsService.getRating('cbf2024', 'drink-123'), 3);
    });

    test('ratings are scoped by drink ID', () async {
      final prefs = await SharedPreferences.getInstance();
      ratingsService = RatingsService(prefs);

      await ratingsService.setRating('cbf2025', 'drink-a', 5);
      await ratingsService.setRating('cbf2025', 'drink-b', 2);

      expect(ratingsService.getRating('cbf2025', 'drink-a'), 5);
      expect(ratingsService.getRating('cbf2025', 'drink-b'), 2);
      expect(ratingsService.getRating('cbf2025', 'drink-c'), isNull);
    });
  });

  group('FestivalStorageService', () {
    late FestivalStorageService festivalStorageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getSelectedFestivalId returns null when no festival is selected', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      final festivalId = festivalStorageService.getSelectedFestivalId();

      expect(festivalId, isNull);
    });

    test('setSelectedFestivalId saves festival ID', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2025');

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, 'cbf2025');
    });

    test('setSelectedFestivalId overwrites previous selection', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2024');
      await festivalStorageService.setSelectedFestivalId('cbf2025');

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, 'cbf2025');
    });

    test('clearSelectedFestival removes saved festival', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      await festivalStorageService.setSelectedFestivalId('cbf2025');
      await festivalStorageService.clearSelectedFestival();

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, isNull);
    });

    test('clearSelectedFestival handles no saved festival gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      festivalStorageService = FestivalStorageService(prefs);

      // Should not throw
      await festivalStorageService.clearSelectedFestival();

      final festivalId = festivalStorageService.getSelectedFestivalId();
      expect(festivalId, isNull);
    });

    test('festival selection persists across service instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final service1 = FestivalStorageService(prefs);

      await service1.setSelectedFestivalId('cbf2025');

      // Create new instance with same prefs
      final service2 = FestivalStorageService(prefs);
      final festivalId = service2.getSelectedFestivalId();

      expect(festivalId, 'cbf2025');
    });
  });
}
