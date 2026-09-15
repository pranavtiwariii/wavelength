import '../../core/api/api_client.dart';
import 'taste_models.dart';

class TasteRepository {
  TasteRepository(this._client);

  final ApiClient _client;

  Future<TasteProfile> fetchProfile() async =>
      TasteProfile.fromJson(await _client.get('/me/taste'));

  Future<List<TasteItem>> search(TasteDomain domain, String query) async {
    final json = await _client.getWithQuery('/taste/search', {
      'domain': domain.id,
      'q': query,
    });
    return (json['results'] as List<dynamic>? ?? [])
        .map((e) => TasteItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TasteProfile> add(TasteDomain domain, TasteItem item) async => TasteProfile.fromJson(
        await _client.post('/me/taste/${domain.id}/items', body: item.toJson()),
      );

  Future<TasteProfile> remove(TasteDomain domain, String key) async => TasteProfile.fromJson(
        await _client.delete('/me/taste/${domain.id}/items', query: {'key': key}),
      );
}
