import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/shell_scaffold.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/creator/presentation/screens/become_creator_screen.dart';
import '../../features/creator/presentation/screens/creator_dashboard_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/earnings/presentation/screens/payout_detail_screen.dart';
import '../../features/earnings/presentation/screens/payout_request_screen.dart';
import '../../features/profile/presentation/providers/current_user_provider.dart';
import '../../features/profile/presentation/screens/devices_screen.dart';
import '../../features/profile/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/publish/presentation/screens/publish_screen.dart';
import '../../features/videos/presentation/screens/video_detail_screen.dart';
import '../../features/videos/presentation/screens/video_stats_screen.dart';
import '../../features/videos/presentation/screens/videos_screen.dart';

/// Routes accessibles sans être connecté.
const _publicRoutes = {'/login', '/register', '/forgot-password'};

/// Routes réservées aux visiteurs : un utilisateur connecté en est renvoyé.
const _guestOnlyRoutes = {'/login', '/register'};

/// Routes ouvertes à un compte spectateur (pas encore créateur).
const _viewerRoutes = {
  '/become-creator',
  '/settings',
  '/devices',
  '/notifications',
  '/forgot-password',
};

/// Le routeur est créé UNE seule fois : le recréer à chaque changement de
/// session détruisait la pile de navigation (formulaire de connexion vidé,
/// redirections perdues). Il se réévalue via [refreshListenable] quand la
/// session ou le rôle du compte changent.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump() => refresh.value++;
  ref.listen(authControllerProvider, (_, _) => bump());
  ref.listen(currentUserProvider, (_, _) => bump());
  ref.listen(postAuthRedirectProvider, (_, _) => bump());

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = Uri.parse(state.location).path;
      final auth = ref.read(authControllerProvider);

      if (auth.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (auth.valueOrNull == null) {
        return _publicRoutes.contains(location) ? null : '/login';
      }

      // Connecté : on attend de connaître le rôle avant de quitter le
      // démarrage ou la connexion. Si /users/me échoue (hors-ligne), on
      // laisse passer : les écrans afficheront leur propre erreur.
      final user = ref.read(currentUserProvider);
      if (user.isLoading && !user.hasValue) {
        return location == '/splash' ? null : '/splash';
      }
      final isCreator = user.valueOrNull?.isCreator ?? true;

      if (_guestOnlyRoutes.contains(location) || location == '/splash') {
        final pending = ref.read(postAuthRedirectProvider);
        if (pending != null) {
          Future.microtask(
            () => ref.read(postAuthRedirectProvider.notifier).state = null,
          );
          return pending;
        }
        return isCreator ? '/home' : '/become-creator';
      }

      if (!isCreator && !_viewerRoutes.contains(location)) {
        return '/become-creator';
      }
      if (isCreator && location == '/become-creator') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/become-creator',
        builder: (context, state) => const BecomeCreatorScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/payout',
        builder: (context, state) => const PayoutRequestScreen(),
      ),
      GoRoute(
        path: '/payout/:payoutId',
        builder: (context, state) =>
            PayoutDetailScreen(payoutId: state.pathParameters['payoutId']!),
      ),
      GoRoute(
        path: '/videos/:videoId/stats',
        builder: (context, state) =>
            VideoStatsScreen(videoId: state.pathParameters['videoId']!),
      ),
      GoRoute(
        path: '/videos/:videoId',
        builder: (context, state) =>
            VideoDetailScreen(videoId: state.pathParameters['videoId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const CreatorDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/videos',
                builder: (context, state) => const VideosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/publish',
                builder: (context, state) => const PublishScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                builder: (context, state) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
