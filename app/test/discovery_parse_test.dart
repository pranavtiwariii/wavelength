@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mates_app/core/api/api_client.dart';
import 'package:mates_app/core/api/api_exception.dart';
import 'package:mates_app/features/discovery/discovery_repository.dart';

/// Parses a real /discovery payload through the real repository. A parse error
/// here surfaces as a hung loading spinner in the app, which is otherwise very
/// hard to attribute.
void main() {
  const baseUrl = 'http://localhost:4000';

  test('the live discovery feed parses into cards', () async {
    late String token;
    try {
      final anon = ApiClient(baseUrl: baseUrl);
      final id = 'parse-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final otp = await anon.post('/auth/request-otp', body: {'identifier': id});
      final verified = await anon.post('/auth/verify-otp', body: {
        'identifier': id,
        'code': otp['devCode'],
      });
      token = verified['token'] as String;
    } on ApiException {
      return markTestSkipped('server not running on $baseUrl');
    }

    final client = ApiClient(baseUrl: baseUrl, readToken: () async => token);

    // Give the new account taste, then a pool, so the feed is non-empty.
    await client.patch('/me', body: {
      'name': 'Parse',
      'age': 25,
      'gender': 'man',
      'seeking': 'everyone',
      'intent': 'both',
      'onboardingStage': 'complete',
    });
    for (final domain in ['music', 'movie', 'book']) {
      final starters = await client.getWithQuery('/taste/starters', {'domain': domain});
      for (final item in (starters['items'] as List<dynamic>).take(2)) {
        await client.post('/me/taste/$domain/items', body: item as Map<String, dynamic>);
      }
    }
    await client.post('/me/bootstrap');

    final repo = DiscoveryRepository(client);
    final cards = await repo.feed({'minAge': 18, 'maxAge': 60});

    expect(cards, isNotEmpty);
    expect(cards.first.user.displayName, isNotEmpty);
    expect(cards.first.overallScore, greaterThan(0));
    expect(cards.first.tasteDna, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
