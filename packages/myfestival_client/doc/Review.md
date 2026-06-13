# myfestival_client.model.Review

## Load the model package
```dart
import 'package:myfestival_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**name** | **String** | Resource name: festivals/{festival}/drinks/{drink}/review. | [optional] 
**starRating** | **int** | Star rating, 1–5 inclusive. Absent if the caller has not set a star rating. | [optional] 
**wouldRecommend** | **bool** | Whether the caller would recommend this drink. Absent if not answered. | [optional] 
**updateTime** | [**DateTime**](DateTime.md) | When this review was last written. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


