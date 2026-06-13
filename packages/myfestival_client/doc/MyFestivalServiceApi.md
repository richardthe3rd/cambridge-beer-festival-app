# myfestival_client.api.MyFestivalServiceApi

## Load the API package
```dart
import 'package:myfestival_client/api.dart';
```

All URIs are relative to *https://api.cambeerfestival.app*

Method | HTTP request | Description
------------- | ------------- | -------------
[**myFestivalServiceDeleteBookmark**](MyFestivalServiceApi.md#myfestivalservicedeletebookmark) | **DELETE** /v1alpha/festivals/{festival}/drinks/{drink}/bookmark | 
[**myFestivalServiceDeleteNote**](MyFestivalServiceApi.md#myfestivalservicedeletenote) | **DELETE** /v1alpha/festivals/{festival}/drinks/{drink}/note | 
[**myFestivalServiceDeleteReview**](MyFestivalServiceApi.md#myfestivalservicedeletereview) | **DELETE** /v1alpha/festivals/{festival}/drinks/{drink}/review | 
[**myFestivalServiceDeleteTasting**](MyFestivalServiceApi.md#myfestivalservicedeletetasting) | **DELETE** /v1alpha/festivals/{festival}/drinks/{drink}/tasting | 
[**myFestivalServiceGetBookmark**](MyFestivalServiceApi.md#myfestivalservicegetbookmark) | **GET** /v1alpha/festivals/{festival}/drinks/{drink}/bookmark | 
[**myFestivalServiceGetNote**](MyFestivalServiceApi.md#myfestivalservicegetnote) | **GET** /v1alpha/festivals/{festival}/drinks/{drink}/note | 
[**myFestivalServiceGetReview**](MyFestivalServiceApi.md#myfestivalservicegetreview) | **GET** /v1alpha/festivals/{festival}/drinks/{drink}/review | 
[**myFestivalServiceGetReviewSummary**](MyFestivalServiceApi.md#myfestivalservicegetreviewsummary) | **GET** /v1alpha/festivals/{festival}/reviewSummaries/{reviewSummary} | 
[**myFestivalServiceGetTasting**](MyFestivalServiceApi.md#myfestivalservicegettasting) | **GET** /v1alpha/festivals/{festival}/drinks/{drink}/tasting | 
[**myFestivalServiceGetTastingSummary**](MyFestivalServiceApi.md#myfestivalservicegettastingsummary) | **GET** /v1alpha/festivals/{festival}/tastingSummaries/{tastingSummary} | 
[**myFestivalServiceListBookmarks**](MyFestivalServiceApi.md#myfestivalservicelistbookmarks) | **GET** /v1alpha/festivals/{festival}/bookmarks | 
[**myFestivalServiceListNotes**](MyFestivalServiceApi.md#myfestivalservicelistnotes) | **GET** /v1alpha/festivals/{festival}/notes | 
[**myFestivalServiceListReviewSummaries**](MyFestivalServiceApi.md#myfestivalservicelistreviewsummaries) | **GET** /v1alpha/festivals/{festival}/reviewSummaries | 
[**myFestivalServiceListReviews**](MyFestivalServiceApi.md#myfestivalservicelistreviews) | **GET** /v1alpha/festivals/{festival}/reviews | 
[**myFestivalServiceListTastingSummaries**](MyFestivalServiceApi.md#myfestivalservicelisttastingsummaries) | **GET** /v1alpha/festivals/{festival}/tastingSummaries | 
[**myFestivalServiceListTastings**](MyFestivalServiceApi.md#myfestivalservicelisttastings) | **GET** /v1alpha/festivals/{festival}/tastings | 
[**myFestivalServiceUpdateBookmark**](MyFestivalServiceApi.md#myfestivalserviceupdatebookmark) | **PATCH** /v1alpha/festivals/{festival}/drinks/{drink}/bookmark | 
[**myFestivalServiceUpdateNote**](MyFestivalServiceApi.md#myfestivalserviceupdatenote) | **PATCH** /v1alpha/festivals/{festival}/drinks/{drink}/note | 
[**myFestivalServiceUpdateReview**](MyFestivalServiceApi.md#myfestivalserviceupdatereview) | **PATCH** /v1alpha/festivals/{festival}/drinks/{drink}/review | 
[**myFestivalServiceUpdateTasting**](MyFestivalServiceApi.md#myfestivalserviceupdatetasting) | **PATCH** /v1alpha/festivals/{festival}/drinks/{drink}/tasting | 


# **myFestivalServiceDeleteBookmark**
> myFestivalServiceDeleteBookmark(festival, drink)



Remove the caller's bookmark for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    api.myFestivalServiceDeleteBookmark(festival, drink);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceDeleteBookmark: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceDeleteNote**
> myFestivalServiceDeleteNote(festival, drink)



Remove the caller's tasting note for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    api.myFestivalServiceDeleteNote(festival, drink);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceDeleteNote: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceDeleteReview**
> myFestivalServiceDeleteReview(festival, drink)



Remove the caller's review for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    api.myFestivalServiceDeleteReview(festival, drink);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceDeleteReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceDeleteTasting**
> myFestivalServiceDeleteTasting(festival, drink)



Remove the caller's tasting record for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    api.myFestivalServiceDeleteTasting(festival, drink);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceDeleteTasting: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetBookmark**
> Bookmark myFestivalServiceGetBookmark(festival, drink)



--- Bookmarks (caller-scoped singletons) ---------------------------------  Get the caller's bookmark for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    final response = api.myFestivalServiceGetBookmark(festival, drink);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetBookmark: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

[**Bookmark**](Bookmark.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetNote**
> Note myFestivalServiceGetNote(festival, drink)



--- Tasting notes (caller-scoped singletons) -----------------------------  Get the caller's tasting note for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    final response = api.myFestivalServiceGetNote(festival, drink);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetNote: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

[**Note**](Note.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetReview**
> Review myFestivalServiceGetReview(festival, drink)



--- Personal reviews (caller-scoped singletons) --------------------------  Get the caller's review for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    final response = api.myFestivalServiceGetReview(festival, drink);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

[**Review**](Review.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetReviewSummary**
> ReviewSummary myFestivalServiceGetReviewSummary(festival, reviewSummary)



--- Aggregates (public, not caller-scoped) --------------------------------  Get the aggregate review signals for a single drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String reviewSummary = reviewSummary_example; // String | The reviewSummary id.

try {
    final response = api.myFestivalServiceGetReviewSummary(festival, reviewSummary);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetReviewSummary: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **reviewSummary** | **String**| The reviewSummary id. | 

### Return type

[**ReviewSummary**](ReviewSummary.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetTasting**
> Tasting myFestivalServiceGetTasting(festival, drink)



--- Tasting log (caller-scoped singletons) -------------------------------  Get the caller's tasting record for a drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.

try {
    final response = api.myFestivalServiceGetTasting(festival, drink);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetTasting: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 

### Return type

[**Tasting**](Tasting.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceGetTastingSummary**
> TastingSummary myFestivalServiceGetTastingSummary(festival, tastingSummary)



Get tasting counts for a single drink.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String tastingSummary = tastingSummary_example; // String | The tastingSummary id.

try {
    final response = api.myFestivalServiceGetTastingSummary(festival, tastingSummary);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceGetTastingSummary: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **tastingSummary** | **String**| The tastingSummary id. | 

### Return type

[**TastingSummary**](TastingSummary.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListBookmarks**
> ListBookmarksResponse myFestivalServiceListBookmarks(festival, pageSize, pageToken)



List all drinks the caller has bookmarked at a festival.   Intended for pre-loading \"my festival\" state on app open.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of bookmarks to return. The server default returns all of  the caller's bookmarks for the festival in a single page (festival drink  counts are bounded). Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListBookmarks response.

try {
    final response = api.myFestivalServiceListBookmarks(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListBookmarks: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of bookmarks to return. The server default returns all of  the caller's bookmarks for the festival in a single page (festival drink  counts are bounded). Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListBookmarks response. | [optional] 

### Return type

[**ListBookmarksResponse**](ListBookmarksResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListNotes**
> ListNotesResponse myFestivalServiceListNotes(festival, pageSize, pageToken)



List all tasting notes the caller has written at a festival.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of notes to return. The server default returns all of the  caller's notes for the festival in a single page (festival drink counts  are bounded). Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListNotes response.

try {
    final response = api.myFestivalServiceListNotes(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListNotes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of notes to return. The server default returns all of the  caller's notes for the festival in a single page (festival drink counts  are bounded). Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListNotes response. | [optional] 

### Return type

[**ListNotesResponse**](ListNotesResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListReviewSummaries**
> ListReviewSummariesResponse myFestivalServiceListReviewSummaries(festival, pageSize, pageToken)



List aggregate review signals for every reviewed drink at a festival.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of summaries to return. The server default returns all  summaries for the festival in a single page (drink counts are bounded).  Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListReviewSummaries response.

try {
    final response = api.myFestivalServiceListReviewSummaries(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListReviewSummaries: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of summaries to return. The server default returns all  summaries for the festival in a single page (drink counts are bounded).  Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListReviewSummaries response. | [optional] 

### Return type

[**ListReviewSummariesResponse**](ListReviewSummariesResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListReviews**
> ListReviewsResponse myFestivalServiceListReviews(festival, pageSize, pageToken)



List all reviews the caller has left for drinks at a festival.   Only the caller's own reviews are returned; caller identity is implicit in  the auth context. Intended for pre-loading \"my festival\" state on app open.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of reviews to return. The server default returns all of the  caller's reviews for the festival in a single page (festival drink counts  are bounded). Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListReviews response.

try {
    final response = api.myFestivalServiceListReviews(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListReviews: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of reviews to return. The server default returns all of the  caller's reviews for the festival in a single page (festival drink counts  are bounded). Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListReviews response. | [optional] 

### Return type

[**ListReviewsResponse**](ListReviewsResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListTastingSummaries**
> ListTastingSummariesResponse myFestivalServiceListTastingSummaries(festival, pageSize, pageToken)



List tasting counts for every tried drink at a festival.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of summaries to return. The server default returns all  summaries for the festival in a single page (drink counts are bounded).  Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListTastingSummaries response.

try {
    final response = api.myFestivalServiceListTastingSummaries(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListTastingSummaries: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of summaries to return. The server default returns all  summaries for the festival in a single page (drink counts are bounded).  Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListTastingSummaries response. | [optional] 

### Return type

[**ListTastingSummariesResponse**](ListTastingSummariesResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceListTastings**
> ListTastingsResponse myFestivalServiceListTastings(festival, pageSize, pageToken)



List all tasting records the caller has logged at a festival.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final int pageSize = 56; // int | Maximum number of tastings to return. The server default returns all of  the caller's tastings for the festival in a single page (festival drink  counts are bounded). Set explicitly to paginate.
final String pageToken = pageToken_example; // String | Page token from a previous ListTastings response.

try {
    final response = api.myFestivalServiceListTastings(festival, pageSize, pageToken);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceListTastings: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **pageSize** | **int**| Maximum number of tastings to return. The server default returns all of  the caller's tastings for the festival in a single page (festival drink  counts are bounded). Set explicitly to paginate. | [optional] 
 **pageToken** | **String**| Page token from a previous ListTastings response. | [optional] 

### Return type

[**ListTastingsResponse**](ListTastingsResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceUpdateBookmark**
> Bookmark myFestivalServiceUpdateBookmark(festival, drink, bookmark, updateMask)



Create or update the caller's bookmark for a drink (upsert).

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.
final Bookmark bookmark = ; // Bookmark | 
final String updateMask = updateMask_example; // String | Fields to update. Omit to replace all writable fields.

try {
    final response = api.myFestivalServiceUpdateBookmark(festival, drink, bookmark, updateMask);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceUpdateBookmark: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 
 **bookmark** | [**Bookmark**](Bookmark.md)|  | 
 **updateMask** | **String**| Fields to update. Omit to replace all writable fields. | [optional] 

### Return type

[**Bookmark**](Bookmark.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceUpdateNote**
> Note myFestivalServiceUpdateNote(festival, drink, note, updateMask)



Create or update the caller's tasting note for a drink (upsert).

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.
final Note note = ; // Note | 
final String updateMask = updateMask_example; // String | Fields to update. Omit to replace all writable fields.

try {
    final response = api.myFestivalServiceUpdateNote(festival, drink, note, updateMask);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceUpdateNote: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 
 **note** | [**Note**](Note.md)|  | 
 **updateMask** | **String**| Fields to update. Omit to replace all writable fields. | [optional] 

### Return type

[**Note**](Note.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceUpdateReview**
> Review myFestivalServiceUpdateReview(festival, drink, review, updateMask)



Create or update the caller's review for a drink (upsert).   Use `update_mask` to update a single signal (e.g. only `star_rating`)  without clearing the other.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.
final Review review = ; // Review | 
final String updateMask = updateMask_example; // String | Fields to update. Omit to replace all writable fields. Specify  `star_rating` or `would_recommend` individually to update one signal  without affecting the other.

try {
    final response = api.myFestivalServiceUpdateReview(festival, drink, review, updateMask);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceUpdateReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 
 **review** | [**Review**](Review.md)|  | 
 **updateMask** | **String**| Fields to update. Omit to replace all writable fields. Specify  `star_rating` or `would_recommend` individually to update one signal  without affecting the other. | [optional] 

### Return type

[**Review**](Review.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **myFestivalServiceUpdateTasting**
> Tasting myFestivalServiceUpdateTasting(festival, drink, tasting, updateMask)



Create or update the caller's tasting record for a drink (upsert).   Use `update_mask` with `pours` to increment the pour count without  affecting other fields.

### Example
```dart
import 'package:myfestival_client/api.dart';

final api = MyfestivalClient().getMyFestivalServiceApi();
final String festival = festival_example; // String | The festival id.
final String drink = drink_example; // String | The drink id.
final Tasting tasting = ; // Tasting | 
final String updateMask = updateMask_example; // String | Fields to update. Omit to replace all writable fields. Specify `pours`  to update the pour count without affecting other fields.

try {
    final response = api.myFestivalServiceUpdateTasting(festival, drink, tasting, updateMask);
    print(response);
} catch on DioException (e) {
    print('Exception when calling MyFestivalServiceApi->myFestivalServiceUpdateTasting: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **festival** | **String**| The festival id. | 
 **drink** | **String**| The drink id. | 
 **tasting** | [**Tasting**](Tasting.md)|  | 
 **updateMask** | **String**| Fields to update. Omit to replace all writable fields. Specify `pours`  to update the pour count without affecting other fields. | [optional] 

### Return type

[**Tasting**](Tasting.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

