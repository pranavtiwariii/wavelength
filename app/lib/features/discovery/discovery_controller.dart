import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.read(authRepositoryProvider).client),
);

/// The swipe queue. Cards are removed locally the moment they're swiped so the
/// stack animates out without waiting on the network.
class DiscoveryController extends AsyncNotifier<List<CompatibilityCard>> {
  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);

  @override
  Future<List<CompatibilityCard>> build() => _repo.feed();

  /// Returns the match id when the like was mutual, so the UI can celebrate.
  Future<String?> swipe(CompatibilityCard card, {required bool like}) async {
    final remaining = <CompatibilityCard>[...?state.value]
      ..removeWhere((c) => c.user.id == card.user.id);
    state = AsyncData(remaining);

    final matchId = await _repo.swipe(card.user.id, like: like);
    if (matchId != null) ref.invalidate(matchesControllerProvider);

    // Top the queue back up when it runs low rather than showing an empty state.
    if (remaining.length <= 2) {
      final fresh = await _repo.feed();
      if (fresh.isNotEmpty) state = AsyncData(fresh);
    }
    return matchId;
  }

  Future<void> refresh() async => state = AsyncData(await _repo.feed());
}

final discoveryControllerProvider =
    AsyncNotifierProvider<DiscoveryController, List<CompatibilityCard>>(DiscoveryController.new);

class MatchesController extends AsyncNotifier<List<MatchSummary>> {
  @override
  Future<List<MatchSummary>> build() =>
      ref.read(discoveryRepositoryProvider).matches();

  Future<void> refresh() async =>
      state = AsyncData(await ref.read(discoveryRepositoryProvider).matches());
}

final matchesControllerProvider =
    AsyncNotifierProvider<MatchesController, List<MatchSummary>>(MatchesController.new);

/// Compatibility for one person, used by the breakdown screen.
final compatibilityProvider =
    FutureProvider.family<CompatibilityCard, String>((ref, userId) async =>
        ref.read(discoveryRepositoryProvider).compatibilityWith(userId));

/// The AI narrative is fetched separately so the breakdown renders immediately
/// and the prose fills in when it arrives.
final narrativeProvider = FutureProvider.family<String, String>((ref, userId) async =>
    ref.read(discoveryRepositoryProvider).narrativeFor(userId));

final chatProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, matchId) async =>
        ref.read(discoveryRepositoryProvider).messages(matchId));
