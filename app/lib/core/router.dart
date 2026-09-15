import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/verify_screen.dart';
import '../features/taste/taste_home_screen.dart';
import '../features/taste/taste_models.dart';
import '../features/taste/taste_search_screen.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilding the router on every auth change would drop navigation state, so
  // instead we hand GoRouter a listenable that fires when auth changes.
  final notifier = _AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;

      // Still restoring the session: hold on the splash.
      if (auth.isLoading || !auth.hasValue) return path == '/' ? null : '/';

      final signedIn = auth.value is SignedIn;
      final onAuthRoute = path == '/' || path == '/sign-in' || path == '/verify';

      if (!signedIn) return onAuthRoute && path != '/' ? null : '/sign-in';
      return onAuthRoute ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return VerifyScreen(
            identifier: (extra['identifier'] ?? '') as String,
            devCode: extra['devCode'] as String?,
          );
        },
      ),
      GoRoute(path: '/home', builder: (_, _) => const TasteHomeScreen()),
      GoRoute(
        path: '/taste/:domain',
        builder: (_, state) => TasteSearchScreen(
          domain: TasteDomain.fromId(state.pathParameters['domain'] ?? 'music'),
        ),
      ),
    ],
  );
});

class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    _sub = ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
        ),
      ),
    );
  }
}
