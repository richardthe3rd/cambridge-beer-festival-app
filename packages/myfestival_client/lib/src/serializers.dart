//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:myfestival_client/src/date_serializer.dart';
import 'package:myfestival_client/src/model/date.dart';

import 'package:myfestival_client/src/model/bookmark.dart';
import 'package:myfestival_client/src/model/list_bookmarks_response.dart';
import 'package:myfestival_client/src/model/list_notes_response.dart';
import 'package:myfestival_client/src/model/list_review_summaries_response.dart';
import 'package:myfestival_client/src/model/list_reviews_response.dart';
import 'package:myfestival_client/src/model/list_tasting_summaries_response.dart';
import 'package:myfestival_client/src/model/list_tastings_response.dart';
import 'package:myfestival_client/src/model/note.dart';
import 'package:myfestival_client/src/model/review.dart';
import 'package:myfestival_client/src/model/review_summary.dart';
import 'package:myfestival_client/src/model/tasting.dart';
import 'package:myfestival_client/src/model/tasting_summary.dart';

part 'serializers.g.dart';

@SerializersFor([
  Bookmark,
  ListBookmarksResponse,
  ListNotesResponse,
  ListReviewSummariesResponse,
  ListReviewsResponse,
  ListTastingSummariesResponse,
  ListTastingsResponse,
  Note,
  Review,
  ReviewSummary,
  Tasting,
  TastingSummary,
])
Serializers serializers = (_$serializers.toBuilder()
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
