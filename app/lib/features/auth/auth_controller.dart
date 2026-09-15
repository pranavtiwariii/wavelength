import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/discovery_controller.dart';
import '../graph/graph_controller.dart';
import '../taste/taste_controller.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Where the user sits relative to the app: still checking, signed out, or
/// signed in (with the profile we know about them).
sealed class AuthState {
  const AuthState();
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final CurrentUser user;
}

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    final token = await _repo.readToken();
    if (token == null) return const SignedOut();
    try {
      return SignedIn(await _repo.fetchMe());
    } on Exception {
      // Token present but rejected or unreachable - start clean.
      await _repo.signOut();
      return const SignedOut();
    }
  }

  Future<OtpRequestResult> requestOtp(String identifier) => _repo.requestOtp(identifier);

  Future<void> verifyOtp(String identifier, String code) async {
    final user = await _repo.verifyOtp(identifier, code);
    // Every user-scoped provider still holds the PREVIOUS session's data.
    // Without this, signing back in shows the last account's taste (empty, or
    // worse, somebody else's) and every compatibility score reads as 0.
    _clearUserScopedState();
    state = AsyncData(SignedIn(user));
  }

  Future<void> refreshUser() async {
    final current = state.value;
    if (current is! SignedIn) return;
    state = AsyncData(SignedIn(await _repo.fetchMe()));
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _clearUserScopedState();
    state = const AsyncData(SignedOut());
  }

  /// Drops everything cached about the previous account.
  void _clearUserScopedState() {
    ref.invalidate(tasteControllerProvider);
    ref.invalidate(discoveryControllerProvider);
    ref.invalidate(matchesControllerProvider);
    ref.invalidate(requestsControllerProvider);
    ref.invalidate(dropsControllerProvider);
    ref.invalidate(communitiesControllerProvider);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
