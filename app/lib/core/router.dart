import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/verify_screen.dart';
import '../features/discovery/compatibility_screen.dart';
import '../features/discovery/discovery_models.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/graph/communities_screen.dart';
import '../features/graph/drops_screen.dart';
import '../features/graph/requests_screen.dart';
import '../features/graph/room_chat_screen.dart';
import '../features/graph/saved_screen.dart';
import '../features/notifications/notifications.dart';
import '../features/matches/chat_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/taste_step_screen.dart';
import '../features/taste/taste_home_screen.dart';
import '../features/taste/taste_models.dart';
import '../features/taste/taste_search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../widgets/mates_mark.dart';
import '../widgets/tab_shell.dart';

final _shellKey = GlobalKey<NavigatorState>();

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

      // Onboarding runs in two steps: who you are, then what you're into.
      // Taste is not optional - without it every compatibility score is 0.
      final user = (auth.value as SignedIn).user;

      // An account with no taste can only ever see 0% against everyone, so
      // treat that as unfinished onboarding even if the stage says otherwise
      // (older accounts predate the taste step).
      final needsTaste =
          user.onboardingStage == 'taste' || user.tasteProfileCompleteness == 0;

      if (!user.hasFinishedOnboarding || needsTaste) {
        final next = needsTaste ? '/onboarding/taste' : '/onboarding';
        return path == next ? null : next;
      }
      if (path.startsWith('/onboarding') || onAuthRoute) return '/discover';
      return null;
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
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/taste', builder: (_, _) => const TasteStepScreen()),

      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) =>
            TabShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/discover', builder: (_, _) => const DiscoveryScreen()),
          GoRoute(path: '/drops', builder: (_, _) => const DropsScreen()),
          GoRoute(path: '/communities', builder: (_, _) => const CommunitiesScreen()),
          GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
          GoRoute(path: '/taste', builder: (_, _) => const TasteHomeScreen()),
        ],
      ),

      GoRoute(
        path: '/taste/:domain',
        builder: (_, state) => TasteSearchScreen(
          domain: TasteDomain.fromId(state.pathParameters['domain'] ?? 'music'),
        ),
      ),
      GoRoute(
        path: '/compatibility/:userId',
        builder: (_, state) =>
            CompatibilityScreen(userId: state.pathParameters['userId'] ?? ''),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/requests', builder: (_, _) => const RequestsScreen()),
      GoRoute(path: '/saved', builder: (_, _) => const SavedScreen()),
      GoRoute(path: '/activity', builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/rooms/:id/chat',
        builder: (_, state) => RoomChatScreen(
          communityId: state.pathParameters['id'] ?? '',
          communityName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/communities/:slug',
        builder: (_, state) =>
            CommunityDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (_, state) => ChatScreen(
          matchId: state.pathParameters['matchId'] ?? '',
          match: state.extra as MatchSummary?,
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
      body: Center(child: AnimatedMatesMark(size: 96)),
    );
  }
}
