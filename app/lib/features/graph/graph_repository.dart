import '../../core/api/api_client.dart';
import '../taste/taste_models.dart';
import 'graph_models.dart';

class GraphRepository {
  GraphRepository(this._client);

  final ApiClient _client;

  // --- Connections -------------------------------------------------------
  Future<List<ConnectionRequest>> incomingRequests() async {
    final json = await _client.get('/connections/requests');
    return (json['requests'] as List<dynamic>? ?? [])
        .map((e) => ConnectionRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> accept(String requestId) async {
    final json = await _client.post('/connections/requests/$requestId/accept');
    return json['matchId'] as String;
  }

  Future<void> decline(String requestId) async =>
      _client.post('/connections/requests/$requestId/decline').then((_) {});

  // --- Drops -------------------------------------------------------------
  Future<List<Drop>> feed() async {
    final json = await _client.get('/drops');
    return (json['drops'] as List<dynamic>? ?? [])
        .map((e) => Drop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Drop> createDrop({
    required TasteDomain domain,
    required TasteItem item,
    String? caption,
    String? communityId,
  }) async {
    final json = await _client.post('/drops', body: {
      'domain': domain.id,
      'itemKey': item.key,
      'itemLabel': item.label,
      'itemSubtitle': ?item.subtitle,
      'itemImage': ?item.imageUrl,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'communityId': ?communityId,
    });
    return Drop.fromJson(json);
  }

  Future<void> react(String dropId, String kind, bool on) async =>
      _client.post('/drops/$dropId/react', body: {'kind': kind, 'on': on}).then((_) {});

  // --- Communities -------------------------------------------------------
  Future<({List<Community> all, List<Community> suggested})> communities() async {
    final json = await _client.get('/communities');
    List<Community> parse(String key) => (json[key] as List<dynamic>? ?? [])
        .map((e) => Community.fromJson(e as Map<String, dynamic>))
        .toList();
    return (all: parse('communities'), suggested: parse('suggested'));
  }

  Future<CommunityDetail> community(String slug) async =>
      CommunityDetail.fromJson(await _client.get('/communities/$slug'));

  Future<void> join(String id) async => _client.post('/communities/$id/join').then((_) {});

  Future<void> leave(String id) async => _client.post('/communities/$id/leave').then((_) {});

  // --- Room chat ---------------------------------------------------------
  Future<List<RoomMessage>> roomMessages(String communityId) async {
    final json = await _client.get('/communities/$communityId/messages');
    return (json['messages'] as List<dynamic>? ?? [])
        .map((e) => RoomMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoomMessage> sendRoomMessage(String communityId, String content) async =>
      RoomMessage.fromJson(
        await _client.post('/communities/$communityId/messages', body: {'content': content}),
      );

  // --- Saved -------------------------------------------------------------
  Future<List<Drop>> saved() async {
    final json = await _client.get('/me/saved');
    return (json['drops'] as List<dynamic>? ?? [])
        .map((e) => Drop.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
