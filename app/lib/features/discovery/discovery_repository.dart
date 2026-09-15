import '../../core/api/api_client.dart';
import 'discovery_models.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._client);

  final ApiClient _client;

  Future<List<CompatibilityCard>> feed() async {
    final json = await _client.get('/discovery');
    return (json['cards'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompatibilityCard> compatibilityWith(String userId) async =>
      CompatibilityCard.fromJson(await _client.get('/compatibility/$userId'));

  Future<String> narrativeFor(String userId) async {
    final json = await _client.get('/discovery/$userId/narrative');
    return json['narrative'] as String? ?? '';
  }

  /// Returns the new match id when the like was mutual.
  Future<String?> swipe(String targetId, {required bool like}) async {
    final json = await _client.post('/swipe', body: {
      'targetId': targetId,
      'direction': like ? 'like' : 'pass',
    });
    return json['matchId'] as String?;
  }

  Future<List<MatchSummary>> matches() async {
    final json = await _client.get('/matches');
    return (json['matches'] as List<dynamic>? ?? [])
        .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessage>> messages(String matchId) async {
    final json = await _client.get('/matches/$matchId/messages');
    return (json['messages'] as List<dynamic>? ?? [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send(String matchId, String content) async => ChatMessage.fromJson(
        await _client.post('/matches/$matchId/messages', body: {'content': content}),
      );

  Future<void> unmatch(String matchId) async =>
      _client.post('/matches/$matchId/unmatch').then((_) {});

  Future<void> block(String userId) async => _client.post('/users/$userId/block').then((_) {});

  Future<void> report(String userId, String reason) async =>
      _client.post('/users/$userId/report', body: {'reason': reason}).then((_) {});
}
