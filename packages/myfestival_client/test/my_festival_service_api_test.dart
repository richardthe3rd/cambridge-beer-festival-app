import 'package:test/test.dart';
import 'package:myfestival_client/myfestival_client.dart';


/// tests for MyFestivalServiceApi
void main() {
  final instance = MyfestivalClient().getMyFestivalServiceApi();

  group(MyFestivalServiceApi, () {
    // Remove the caller's bookmark for a drink.
    //
    //Future myFestivalServiceDeleteBookmark(String festival, String drink) async
    test('test myFestivalServiceDeleteBookmark', () async {
      // TODO
    });

    // Remove the caller's tasting note for a drink.
    //
    //Future myFestivalServiceDeleteNote(String festival, String drink) async
    test('test myFestivalServiceDeleteNote', () async {
      // TODO
    });

    // Remove the caller's review for a drink.
    //
    //Future myFestivalServiceDeleteReview(String festival, String drink) async
    test('test myFestivalServiceDeleteReview', () async {
      // TODO
    });

    // Remove the caller's tasting record for a drink.
    //
    //Future myFestivalServiceDeleteTasting(String festival, String drink) async
    test('test myFestivalServiceDeleteTasting', () async {
      // TODO
    });

    // --- Bookmarks (caller-scoped singletons) ---------------------------------  Get the caller's bookmark for a drink.
    //
    //Future<Bookmark> myFestivalServiceGetBookmark(String festival, String drink) async
    test('test myFestivalServiceGetBookmark', () async {
      // TODO
    });

    // --- Tasting notes (caller-scoped singletons) -----------------------------  Get the caller's tasting note for a drink.
    //
    //Future<Note> myFestivalServiceGetNote(String festival, String drink) async
    test('test myFestivalServiceGetNote', () async {
      // TODO
    });

    // --- Personal reviews (caller-scoped singletons) --------------------------  Get the caller's review for a drink.
    //
    //Future<Review> myFestivalServiceGetReview(String festival, String drink) async
    test('test myFestivalServiceGetReview', () async {
      // TODO
    });

    // --- Aggregates (public, not caller-scoped) --------------------------------  Get the aggregate review signals for a single drink.
    //
    //Future<ReviewSummary> myFestivalServiceGetReviewSummary(String festival, String reviewSummary) async
    test('test myFestivalServiceGetReviewSummary', () async {
      // TODO
    });

    // --- Tasting log (caller-scoped singletons) -------------------------------  Get the caller's tasting record for a drink.
    //
    //Future<Tasting> myFestivalServiceGetTasting(String festival, String drink) async
    test('test myFestivalServiceGetTasting', () async {
      // TODO
    });

    // Get tasting counts for a single drink.
    //
    //Future<TastingSummary> myFestivalServiceGetTastingSummary(String festival, String tastingSummary) async
    test('test myFestivalServiceGetTastingSummary', () async {
      // TODO
    });

    // List all drinks the caller has bookmarked at a festival.   Intended for pre-loading \"my festival\" state on app open.
    //
    //Future<ListBookmarksResponse> myFestivalServiceListBookmarks(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListBookmarks', () async {
      // TODO
    });

    // List all tasting notes the caller has written at a festival.
    //
    //Future<ListNotesResponse> myFestivalServiceListNotes(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListNotes', () async {
      // TODO
    });

    // List aggregate review signals for every reviewed drink at a festival.
    //
    //Future<ListReviewSummariesResponse> myFestivalServiceListReviewSummaries(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListReviewSummaries', () async {
      // TODO
    });

    // List all reviews the caller has left for drinks at a festival.   Only the caller's own reviews are returned; caller identity is implicit in  the auth context. Intended for pre-loading \"my festival\" state on app open.
    //
    //Future<ListReviewsResponse> myFestivalServiceListReviews(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListReviews', () async {
      // TODO
    });

    // List tasting counts for every tried drink at a festival.
    //
    //Future<ListTastingSummariesResponse> myFestivalServiceListTastingSummaries(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListTastingSummaries', () async {
      // TODO
    });

    // List all tasting records the caller has logged at a festival.
    //
    //Future<ListTastingsResponse> myFestivalServiceListTastings(String festival, { int pageSize, String pageToken }) async
    test('test myFestivalServiceListTastings', () async {
      // TODO
    });

    // Create or update the caller's bookmark for a drink (upsert).
    //
    //Future<Bookmark> myFestivalServiceUpdateBookmark(String festival, String drink, Bookmark bookmark, { String updateMask }) async
    test('test myFestivalServiceUpdateBookmark', () async {
      // TODO
    });

    // Create or update the caller's tasting note for a drink (upsert).
    //
    //Future<Note> myFestivalServiceUpdateNote(String festival, String drink, Note note, { String updateMask }) async
    test('test myFestivalServiceUpdateNote', () async {
      // TODO
    });

    // Create or update the caller's review for a drink (upsert).   Use `update_mask` to update a single signal (e.g. only `star_rating`)  without clearing the other.
    //
    //Future<Review> myFestivalServiceUpdateReview(String festival, String drink, Review review, { String updateMask }) async
    test('test myFestivalServiceUpdateReview', () async {
      // TODO
    });

    // Create or update the caller's tasting record for a drink (upsert).   Use `update_mask` with `pours` to increment the pour count without  affecting other fields.
    //
    //Future<Tasting> myFestivalServiceUpdateTasting(String festival, String drink, Tasting tasting, { String updateMask }) async
    test('test myFestivalServiceUpdateTasting', () async {
      // TODO
    });

  });
}
