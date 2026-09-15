import '../../core/api/api_client.dart';
import 'discovery_models.dart';

/// What a like produced: an immediate connection, or a pending request.
class SwipeOutcome {
  const SwipeOutcome({this.matchId, this.requested = false});

  final String? matchId;
  final bool requested;
}

class DiscoveryRepository {
  DiscoveryRepository(this._client);

  final ApiClient _client;

  Future<List<CompatibilityCard>> feed([Map<String, dynamic>? query]) async {
    final json = query == null || query.isEmpty
        ? await _client.get('/discovery')
        : await _client.getWithQuery('/discovery', query);
    return (json['cards'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Clears passes server-side and returns how many came back.
  Future<int> recycle() async {
    final json = await _client.post('/discovery/recycle');
    return json['restored'] as int? ?? 0;
  }

  Future<CompatibilityCard> compatibilityWith(String userId) async =>
      CompatibilityCard.fromJson(await _client.get('/compatibility/$userId'));

  Future<String> narrativeFor(String userId) async {
    final json = await _client.get('/discovery/$userId/narrative');
    return json['narrative'] as String? ?? '';
  }

  Future<SwipeOutcome> swipe(String targetId, {required bool like}) async {
    final json = await _client.post('/swipe', body: {
      'targetId': targetId,
      'direction': like ? 'like' : 'pass',
    });
    return SwipeOutcome(
      matchId: json['matchId'] as String?,
      requested: json['requested'] as bool? ?? false,
    );
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
