# myfestival_client.model.Tasting

## Load the model package
```dart
import 'package:myfestival_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**name** | **String** | Resource name: festivals/{festival}/drinks/{drink}/tasting. | [optional] 
**pours** | **int** | How many times the caller has had this drink. Absent means one pour.  Must be >= 1 when present. | [optional] 
**createTime** | [**DateTime**](DateTime.md) | When the caller first tried this drink. | [optional] 
**updateTime** | [**DateTime**](DateTime.md) | When this record was last updated. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


