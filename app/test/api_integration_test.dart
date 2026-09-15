@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wavelength_app/core/api/api_client.dart';
import 'package:wavelength_app/core/api/api_exception.dart';

/// Exercises the real Dart client against a running Wavelength server.
///
///   cd server && npm start
///   cd app && flutter test test/api_integration_test.dart
///
/// Skips itself (rather than failing) when the server isn't up, so the default
/// `flutter test` run stays green on a machine with no backend.
void main() {
  const baseUrl = 'http://localhost:4000';
  late bool serverUp;

  setUpAll(() async {
    try {
      await ApiClient(baseUrl: baseUrl).get('/health');
      serverUp = true;
    } on ApiException {
      serverUp = false;
    }
  });

  test('health reports the active database driver', () async {
    if (!serverUp) return markTestSkipped('server not running on $baseUrl');
    final res = await ApiClient(baseUrl: baseUrl).get('/health');
    expect(res['status'], 'ok');
    expect(res['driver'], anyOf('pglite', 'pg'));
  });

  test('full sign-in loop: request code, verify, read profile', () async {
    if (!serverUp) return markTestSkipped('server not running on $baseUrl');

    final anon = ApiClient(baseUrl: baseUrl);
    final identifier = 'dart-${DateTime.now().microsecondsSinceEpoch}@example.com';

    final otp = await anon.post('/auth/request-otp', body: {'identifier': identifier});
    final devCode = otp['devCode'] as String?;
    expect(devCode, isNotNull, reason: 'dev server should echo the OTP');
    expect(devCode, hasLength(6));

    final verified = await anon.post(
      '/auth/verify-otp',
      body: {'identifier': identifier, 'code': devCode},
    );
    final token = verified['token'] as String;
    expect(verified['isNewUser'], isTrue);

    // A client that carries the token must now reach a protected route.
    final authed = ApiClient(baseUrl: baseUrl, readToken: () async => token);
    final me = await authed.get('/me');
    expect(me['id'], verified['userId']);
    expect(me['email'], identifier);
    expect(me['tasteProfileCompleteness'], 0);
  });

  test('protected route rejects an unauthenticated client', () async {
    if (!serverUp) return markTestSkipped('server not running on $baseUrl');

    await expectLater(
      ApiClient(baseUrl: baseUrl).get('/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'missing_token')
          .having((e) => e.statusCode, 'status', 401)),
    );
  });

  test('translates a server error into a user-facing ApiException', () async {
    if (!serverUp) return markTestSkipped('server not running on $baseUrl');

    final anon = ApiClient(baseUrl: baseUrl);
    final identifier = 'dart-bad-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await anon.post('/auth/request-otp', body: {'identifier': identifier});

    await expectLater(
      anon.post('/auth/verify-otp', body: {'identifier': identifier, 'code': '000000'}),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'otp_invalid')
          .having((e) => e.message, 'message', contains('not valid'))),
    );
  });

  test('surfaces a friendly message when the API is unreachable', () async {
    await expectLater(
      ApiClient(baseUrl: 'http://localhost:1').get('/health'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'network_unreachable')
          .having((e) => e.message, 'message', contains("Can't reach Wavelength"))),
    );
  });
}
