import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/domain/user_read.dart';
import 'package:gnplay/features/creator/presentation/screens/creator_dashboard_screen.dart';
import 'package:gnplay/features/profile/presentation/providers/current_user_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/api_test_support.dart';

Map<String, Object?> userJson({
  String phone = '+224621458807',
  String role = 'creator',
  String name = 'Mariama Diallo',
  String? avatar,
}) => {
  'id': 'u1',
  'full_name': name,
  'phone_number': phone,
  'role': role,
  'is_active': true,
  'is_superuser': false,
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
  'avatar': ?avatar,
};

UserRead testUser({
  String phone = '+224621458807',
  String role = 'creator',
  String name = 'Mariama Diallo',
  String? avatar,
}) => UserRead.fromJson(
  userJson(phone: phone, role: role, name: name, avatar: avatar),
);

Map<String, Object?> videoJson(
  String id,
  String title, {
  int views = 90,
  int revenue = 4000,
  String? thumbnail,
}) => {
  'id': id,
  'title': title,
  'view_count': views,
  'likes_count': 5,
  'revenue': revenue,
  'price': 1000,
  'duration': 120,
  'status': 'ready',
  'is_published': true,
  'created_at': '2026-02-01T00:00:00Z',
  'updated_at': '2026-02-01T00:00:00Z',
  'thumbnail_url': ?thumbnail,
};

/// API simulée du tableau de bord ; les champs sont modifiables entre deux
/// chargements pour simuler une donnée qui change côté serveur.
class DashboardApi {
  DashboardApi();

  /// Requêtes reçues, au format « GET /api/v1/... ».
  final List<String> calls = [];

  Map<String, Object?> analytics = {
    'total_videos': 2,
    'total_views': 100,
    'total_followers': 10,
    'revenue_total': 5000,
    'revenue_this_month': 1000,
    'top_videos': [
      {
        'video_id': 'v1',
        'title': 'Marché Madina',
        'view_count': 90,
        'likes_count': 5,
      },
    ],
  };
  List<Object?> videos = [videoJson('v1', 'Marché Madina')];
  Map<String, Object?> balance = {
    'withdrawable_balance': 4000,
    'wallet_balance': 6000,
    'total_earnings': 5000,
    'total_withdrawn': 1000,
    'total_refunded': 0,
  };
  int unread = 3;

  /// Nombre des prochains appels à /creators/me/analytics qui échouent (503).
  int failAnalytics = 0;

  /// Les statistiques répondent 403 (compte non créateur).
  bool forbidAnalytics = false;

  /// Tant que cette porte est posée, /creators/me/analytics attend.
  Completer<void>? analyticsGate;

  int count(String call) => calls.where((c) => c == call).length;
  int get analyticsCalls => count('GET /api/v1/creators/me/analytics');

  late final http.Client client = MockClient((request) async {
    calls.add('${request.method} ${request.url.path}');
    switch (request.url.path) {
      case '/api/v1/creators/me/analytics':
        final gate = analyticsGate;
        if (gate != null) await gate.future;
        if (forbidAnalytics) {
          return jsonResponse({'detail': 'Réservé aux créateurs'}, 403);
        }
        if (failAnalytics > 0) {
          failAnalytics--;
          return jsonResponse({'detail': 'Service indisponible'}, 503);
        }
        return jsonResponse(analytics);
      case '/api/v1/payouts/balance':
        return jsonResponse(balance);
      case '/api/v1/videos/mine':
        return jsonResponse(videos);
      case '/api/v1/notifications/unread-count':
        return jsonResponse({'unread_count': unread});
    }
    return jsonResponse({'detail': 'Not Found'}, 404);
  });
}

/// Tableau de bord dans un routeur minimal : chaque destination affiche son
/// chemin, ce qui permet de vérifier où mène un toucher.
Widget dashboardApp(
  DashboardApi api, {
  UserRead? user,
  Duration minRefreshInterval = Duration.zero,
  Widget Function(Widget dashboard)? wrap,
  ValueNotifier<GoRouter?>? routerOut,
}) {
  Widget destination(String label) => Scaffold(body: Text(label));
  final dashboard = CreatorDashboardScreen(
    minRefreshInterval: minRefreshInterval,
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => wrap == null ? dashboard : wrap(dashboard),
      ),
      for (final path in const [
        '/notifications',
        '/payout',
        '/publish',
        '/videos',
        '/become-creator',
      ])
        GoRoute(path: path, builder: (_, _) => destination('page $path')),
      GoRoute(
        path: '/videos/:id',
        builder: (_, state) =>
            destination('page /videos/${state.pathParameters['id']}'),
      ),
    ],
  );
  routerOut?.value = router;
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(api.client),
      currentUserProvider.overrideWith((ref) async => user ?? testUser()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

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
