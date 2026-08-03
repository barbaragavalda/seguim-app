import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:seguim/core/network/api_response_parser.dart';

void main() {
  tearDown(() => onAuthExpired = null);

  test('calls onAuthExpired when the response is a 401', () {
    var called = false;
    onAuthExpired = () => called = true;

    decodeApiResponse(http.Response('{"error":401}', 401));

    expect(called, isTrue);
  });

  test('does not call onAuthExpired on a normal response', () {
    var called = false;
    onAuthExpired = () => called = true;

    decodeApiResponse(http.Response('{"error":false}', 200));

    expect(called, isFalse);
  });

  test('still parses the body of a 401 response', () {
    final data = decodeApiResponse(http.Response('{"error":401}', 401));

    expect(data['error'], 401);
  });
}
