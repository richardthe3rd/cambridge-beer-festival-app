// Mocks generated manually for services_test.dart
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

/// A class which mocks [http.Client].
class MockClient extends Mock implements http.Client {
  @override
  Future<http.Response> get(Uri? url, {Map<String, String>? headers}) =>
      super.noSuchMethod(
        Invocation.method(#get, [url], {#headers: headers}),
        returnValue: Future.value(http.Response('', 200)),
        returnValueForMissingStub: Future.value(http.Response('', 200)),
      ) as Future<http.Response>;
}
