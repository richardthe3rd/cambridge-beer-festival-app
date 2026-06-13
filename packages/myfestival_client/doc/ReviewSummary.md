# myfestival_client.model.ReviewSummary

## Load the model package
```dart
import 'package:myfestival_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**name** | **String** | Resource name: festivals/{festival}/reviewSummaries/{drink}. | [optional] 
**ratingCount** | **int** | Number of callers who have submitted a star rating. | [optional] 
**averageRating** | **double** | Mean star rating across all callers (1.0–5.0); 0 when rating_count is 0. | [optional] 
**responseCount** | **int** | Number of callers who have answered the \"would recommend\" question. | [optional] 
**recommendCount** | **int** | Number of callers who answered \"yes\" to the recommendation question. | [optional] 
**recommendRate** | **double** | Fraction of responses (0.0–1.0) that would recommend; 0 when  response_count is 0. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


