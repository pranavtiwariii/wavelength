import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../discovery/discovery_controller.dart';
import 'taste_models.dart';
import 'taste_repository.dart';

final tasteRepositoryProvider = Provider<TasteRepository>(
  (ref) => TasteRepository(ref.read(authRepositoryProvider).client),
);

class TasteController extends AsyncNotifier<TasteProfile> {
  TasteRepository get _repo => ref.read(tasteRepositoryProvider);

  @override
  Future<TasteProfile> build() => _repo.fetchProfile();

  Future<void> add(TasteDomain domain, TasteItem item) async {
    state = AsyncData(await _repo.add(domain, item));
    await _afterTasteChange();
  }

  Future<void> remove(TasteDomain domain, String key) async {
    state = AsyncData(await _repo.remove(domain, key));
    await _afterTasteChange();
  }

  /// Changing taste changes every compatibility score, so the cached discovery
  /// feed and the completeness meter on /me both have to be rebuilt - otherwise
  /// the stack keeps showing scores computed against the old profile.
  Future<void> _afterTasteChange() async {
    ref.invalidate(discoveryControllerProvider);
    await ref.read(authControllerProvider.notifier).refreshUser();
  }

  Future<void> refresh() async {
    state = AsyncData(await _repo.fetchProfile());
  }
}

final tasteControllerProvider =
    AsyncNotifierProvider<TasteController, TasteProfile>(TasteController.new);
