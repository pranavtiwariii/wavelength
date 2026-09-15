import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../discovery/discovery_controller.dart';
import 'graph_models.dart';
import 'graph_repository.dart';

final graphRepositoryProvider = Provider<GraphRepository>(
  (ref) => GraphRepository(ref.read(authRepositoryProvider).client),
);

class RequestsController extends AsyncNotifier<List<ConnectionRequest>> {
  GraphRepository get _repo => ref.read(graphRepositoryProvider);

  @override
  Future<List<ConnectionRequest>> build() => _repo.incomingRequests();

  Future<String> accept(ConnectionRequest request) async {
    final matchId = await _repo.accept(request.id);
    _drop(request.id);
    // Accepting creates a match, so the matches list is now stale.
    ref.invalidate(matchesControllerProvider);
    return matchId;
  }

  Future<void> decline(ConnectionRequest request) async {
    await _repo.decline(request.id);
    _drop(request.id);
  }

  void _drop(String id) {
    state = AsyncData([...?state.value?.where((r) => r.id != id)]);
  }

  Future<void> refresh() async => state = AsyncData(await _repo.incomingRequests());
}

final requestsControllerProvider =
    AsyncNotifierProvider<RequestsController, List<ConnectionRequest>>(
        RequestsController.new);

class DropsController extends AsyncNotifier<List<Drop>> {
  GraphRepository get _repo => ref.read(graphRepositoryProvider);

  @override
  Future<List<Drop>> build() => _repo.feed();

  /// Optimistic: the count moves immediately, then reconciles with the server.
  Future<void> toggle(Drop drop, String kind) async {
    final on = kind == 'like' ? !drop.likedByMe : !drop.savedByMe;

    state = AsyncData([
      for (final d in state.value ?? <Drop>[])
        if (d.id != drop.id)
          d
        else if (kind == 'like')
          d.copyWith(likedByMe: on, likeCount: d.likeCount + (on ? 1 : -1))
        else
          d.copyWith(savedByMe: on, saveCount: d.saveCount + (on ? 1 : -1)),
    ]);

    try {
      await _repo.react(drop.id, kind, on);
    } on Exception {
      await refresh();
    }
  }

  Future<void> refresh() async => state = AsyncData(await _repo.feed());
}

final dropsControllerProvider =
    AsyncNotifierProvider<DropsController, List<Drop>>(DropsController.new);

class CommunitiesController
    extends AsyncNotifier<({List<Community> all, List<Community> suggested})> {
  GraphRepository get _repo => ref.read(graphRepositoryProvider);

  @override
  Future<({List<Community> all, List<Community> suggested})> build() => _repo.communities();

  Future<void> join(Community community) async {
    await _repo.join(community.id);
    await refresh();
  }

  Future<void> leave(Community community) async {
    await _repo.leave(community.id);
    await refresh();
  }

  Future<void> refresh() async => state = AsyncData(await _repo.communities());
}

final communitiesControllerProvider = AsyncNotifierProvider<CommunitiesController,
    ({List<Community> all, List<Community> suggested})>(CommunitiesController.new);

final communityDetailProvider =
    FutureProvider.family<CommunityDetail, String>((ref, slug) async {
  // Rebuild when membership changes so the member list stays accurate.
  ref.watch(communitiesControllerProvider);
  return ref.read(graphRepositoryProvider).community(slug);
});


final roomMessagesProvider =
    FutureProvider.family<List<RoomMessage>, String>((ref, communityId) async =>
        ref.read(graphRepositoryProvider).roomMessages(communityId));

final savedDropsProvider = FutureProvider<List<Drop>>(
    (ref) => ref.read(graphRepositoryProvider).saved());
