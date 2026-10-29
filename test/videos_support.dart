import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/domain/user_read.dart';
import 'package:gnplay/features/profile/presentation/providers/current_user_provider.dart';
import 'package:gnplay/features/videos/presentation/providers/video_player_factory_provider.dart';
import 'package:gnplay/features/videos/presentation/screens/video_detail_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/video_stats_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/videos_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player/video_player.dart';

import 'support/api_test_support.dart';

/// Compte créateur de test ; l'indicatif du téléphone fixe la devise.
UserRead testUser({String phone = '+224621458807'}) => UserRead.fromJson({
  'id': 'u1',
  'full_name': 'Mariama Diallo',
  'phone_number': phone,
  'role': 'creator',
  'is_active': true,
  'is_superuser': false,
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
});

/// Fenêtre de téléphone (360 px de large par défaut).
void usePhoneScreen(
  WidgetTester tester, {
  double width = 360,
  double height = 900,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Une vidéo telle que la renvoie `GET /videos/mine`.
Map<String, Object?> videoJson(
  String id,
  String title, {
  String status = 'ready',
  bool published = true,
  int price = 1000,
  int duration = 120,
  int views = 90,
  int likes = 5,
  int revenue = 4000,
  String? description,
  String? thumbnail,
  String? preview,
}) => {
  'id': id,
  'user_id': 'u1',
  'title': title,
  'description': description,
  'thumbnail_url': thumbnail,
  'preview_url': preview,
  'price': price,
  'duration': duration,
  'status': status,
  'is_published': published,
  'view_count': views,
  'likes_count': likes,
  'revenue': revenue,
  'created_at': '2026-06-12T09:41:00.000000Z',
  'updated_at': '2026-06-13T09:41:00.000000Z',
};

Map<String, Object?> analyticsJson(
  String id, {
  int views = 1200,
  int unique = 800,
  int completed = 500,
  double rate = 0.68,
  int likes = 42,
  int purchases = 12,
  int revenue = 150000,
}) => {
  'video_id': id,
  'views': views,
  'unique_viewers': unique,
  'completed_views': completed,
  'average_completion_rate': rate,
  'likes_count': likes,
  'purchases_count': purchases,
  'revenue': revenue,
};

typedef ApiHandler = FutureOr<http.Response> Function(http.Request request);

/// API simulée des écrans vidéo ; les données sont modifiables entre deux
/// chargements pour simuler ce qui change côté serveur.
class VideosApi {
  VideosApi({List<Map<String, Object?>>? videos})
    : videos = videos ?? [videoJson('v1', 'Marché Madina')];

  List<Map<String, Object?>> videos;
  final Map<String, Map<String, Object?>> analytics = {};

  /// Requêtes reçues, au format « GET /api/v1/... ».
  final List<String> calls = [];
  final List<Map<String, dynamic>> patchBodies = [];

  /// Tant que cette porte est posée, `GET /videos/mine` attend.
  Completer<void>? listGate;

  /// Nombre des prochains `GET /videos/mine` qui échouent (503).
  int failList = 0;

  /// Réponses personnalisées par route (« METHOD /path »).
  final Map<String, ApiHandler> overrides = {};

  int count(String call) => calls.where((c) => c == call).length;
  int get listCalls => count('GET /api/v1/videos/mine');

  Map<String, Object?> video(String id) =>
      videos.firstWhere((video) => video['id'] == id);

  late final http.Client client = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    final custom = overrides[key];
    if (custom != null) return custom(request);

    final path = request.url.path;
    final segments = path.split('/');

    if (key == 'GET /api/v1/videos/mine') {
      final gate = listGate;
      if (gate != null) await gate.future;
      if (failList > 0) {
        failList--;
        return jsonResponse({'detail': 'Service indisponible'}, 503);
      }
      return jsonResponse(videos);
    }

    // /api/v1/videos/{id}[/analytics]
    if (segments.length >= 5 && segments[3] == 'videos') {
      final id = segments[4];
      if (request.method == 'GET' && path.endsWith('/analytics')) {
        return jsonResponse(analytics[id] ?? analyticsJson(id));
      }
      if (request.method == 'PATCH' && segments.length == 5) {
        final body = bodyOf(request);
        patchBodies.add(body);
        final video = this.video(id);
        for (final entry in body.entries) {
          video[entry.key] = entry.value;
        }
        return jsonResponse(video);
      }
      if (request.method == 'DELETE' && segments.length == 5) {
        videos.removeWhere((video) => video['id'] == id);
        return http.Response('', 204);
      }
    }

    if (key.startsWith('POST /api/v1/internal/videos/') &&
        path.endsWith('/retry-transcode')) {
      return jsonResponse({
        'message': 'Transcode job retried',
        'status': 'queued',
      });
    }
    return jsonResponse({'detail': 'Not Found'}, 404);
  });
}

/// Lecteur factice : aucune plateforme native n'est nécessaire.
class FakeVideoController extends VideoPlayerController {
  FakeVideoController({
    this.failInitialize = false,
    Duration length = const Duration(seconds: 15),
  }) : _length = length,
       super.networkUrl(Uri.parse('https://cdn.test/video.mp4'));

  final bool failInitialize;
  final Duration _length;
  bool initialized = false;
  bool disposed = false;
  bool looping = false;
  double volumeValue = 1;
  final List<Duration> seeks = [];
  Gate? initializeGate;

  @override
  Future<void> initialize() async {
    final gate = initializeGate;
    if (gate != null) await gate.future;
    if (failInitialize) throw Exception('échec');
    initialized = true;
    value = value.copyWith(
      isInitialized: true,
      duration: _length,
      size: const Size(1280, 720),
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setLooping(bool looping) async {
    this.looping = looping;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeValue = volume;
  }

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  /// Simule une mise à jour de position / de mise en mémoire tampon.
  void emit({Duration? position, bool? isBuffering, String? error}) {
    value = error != null
        ? value.copyWith(errorDescription: error)
        : value.copyWith(position: position, isBuffering: isBuffering);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

typedef Gate = Completer<void>;

/// Fabrique qui mémorise les contrôleurs factices créés.
class FakePlayers {
  final List<FakeVideoController> created = [];
  final List<Uri> urls = [];
  FakeVideoController Function()? build;

  FakeVideoController? get last => created.isEmpty ? null : created.last;

  VideoControllerFactory get factory => (url, {formatHint}) {
    urls.add(url);
    final controller = build?.call() ?? FakeVideoController();
    created.add(controller);
    return controller;
  };
}

/// Écrans vidéo dans un routeur : `/videos` (liste), `/videos/:id` (détail),
/// `/videos/:id/stats`, `/publish`.
Widget videosApp(
  VideosApi api, {
  UserRead? user,
  FakePlayers? players,
  String initialLocation = '/videos',
  Duration pollInterval = const Duration(seconds: 6),
  Duration detailPollInterval = const Duration(seconds: 5),
  Duration previewTimeout = const Duration(minutes: 2),
  Duration minRefreshInterval = Duration.zero,
  Widget Function(Widget list)? wrapList,
  Widget Function(String id)? detailBuilder,
  ValueNotifier<GoRouter?>? routerOut,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/videos',
        builder: (context, state) {
          final list = VideosScreen(
            pollInterval: pollInterval,
            minRefreshInterval: minRefreshInterval,
          );
          return wrapList == null ? list : wrapList(list);
        },
        routes: [
          GoRoute(
            path: ':videoId',
            builder: (context, state) {
              final id = state.pathParameters['videoId']!;
              return detailBuilder?.call(id) ??
                  VideoDetailScreen(
                    videoId: id,
                    pollInterval: detailPollInterval,
                    previewTimeout: previewTimeout,
                  );
            },
            routes: [
              GoRoute(
                path: 'stats',
                builder: (context, state) =>
                    VideoStatsScreen(videoId: state.pathParameters['videoId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/publish',
        builder: (_, _) => const Scaffold(body: Text('page /publish')),
      ),
    ],
  );
  routerOut?.value = router;
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(api.client),
      currentUserProvider.overrideWith((ref) async => user ?? testUser()),
      if (players != null)
        videoControllerFactoryProvider.overrideWithValue(players.factory),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

/// Laisse s'écouler les minuteries d'un toast (affichage + sortie).
Future<void> settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 400));
}
