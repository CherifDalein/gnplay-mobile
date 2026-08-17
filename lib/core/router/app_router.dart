import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/shell_scaffold.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/creator/presentation/screens/become_creator_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/publish/presentation/screens/publish_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/series/presentation/screens/series_screen.dart';
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
      final isAuthRoute = location == '/login' || location == '/register';

      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState.valueOrNull != null;

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute || location == '/splash') {
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
        path: '/become-creator',
        builder: (context, state) => const BecomeCreatorScreen(),
      ),
      GoRoute(
        path: '/videos/series/:seriesId',
        builder: (context, state) =>
            SeriesScreen(seriesId: state.pathParameters['seriesId']!),
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
                builder: (context, state) => const HomeScreen(),
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
