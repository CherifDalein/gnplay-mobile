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
import '../../features/profile/presentation/screens/devices_screen.dart';
import '../../features/profile/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/publish/presentation/screens/publish_screen.dart';
import '../../features/videos/presentation/screens/video_detail_screen.dart';
import '../../features/videos/presentation/screens/video_stats_screen.dart';
import '../../features/videos/presentation/screens/videos_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final postAuthRedirect = ref.watch(postAuthRedirectProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = Uri.parse(state.location).path;
      // Routes réservées aux visiteurs non connectés (redirigent vers /home
      // si déjà authentifié).
      final isAuthOnlyRoute = location == '/login' || location == '/register';
      // Accessible sans être connecté, mais aussi depuis l'app (Réglages) une
      // fois connecté — ne doit jamais rebondir vers /home.
      final isPublicRoute = isAuthOnlyRoute || location == '/forgot-password';

      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState.valueOrNull != null;

      if (!isAuthenticated) {
        return isPublicRoute ? null : '/login';
      }

      if (isAuthOnlyRoute || location == '/splash') {
        if (postAuthRedirect != null) {
          Future.microtask(() {
            ref.read(postAuthRedirectProvider.notifier).state = null;
          });
          return postAuthRedirect;
        }
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
});
