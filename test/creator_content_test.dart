import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/features/publish/presentation/screens/publish_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/video_detail_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/video_stats_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/videos_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _sampleVideoId = 'video-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });
  });

  testWidgets('creator content screens mount with real API responses', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const VideosScreen()));
    await tester.pump();
    expect(find.text('Mon contenu'), findsOneWidget);
    await tester.pump();
    expect(find.text('Nuits de Conakry — épisode 3'), findsOneWidget);

    await tester.pumpWidget(_wrap(const PublishScreen()));
    await tester.pump();
    expect(find.text('Nouvelle vidéo'), findsOneWidget);
    expect(find.text('Choisir une vidéo'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const VideoDetailScreen(videoId: _sampleVideoId)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Nuits de Conakry — épisode 3'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const VideoStatsScreen(videoId: _sampleVideoId)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('taux de complétion moyen'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [httpClientProvider.overrideWithValue(_fakeClient())],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}

http.Client _fakeClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/v1/videos/mine') {
      return http.Response(
        jsonEncode([_videoJson]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path == '/api/v1/videos/$_sampleVideoId/analytics') {
      return http.Response(
        jsonEncode({
          'video_id': _sampleVideoId,
          'views': 14208,
          'unique_viewers': 11840,
          'completed_views': 10230,
          'average_completion_rate': 0.72,
          'likes_count': 842,
          'purchases_count': 123,
          'revenue': 1842000,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response(jsonEncode({'detail': 'not found'}), 404);
  });
}

final _videoJson = {
  'id': _sampleVideoId,
  'user_id': 'user-1',
  'title': 'Nuits de Conakry — épisode 3',
  'description': 'Une traversée nocturne entre Kaloum, Matam et les studios.',
  'thumbnail_url': null,
  'preview_url': null,
  'price': 15000,
  'duration': 1448,
  'status': 'published',
  'is_published': true,
  'view_count': 14208,
  'likes_count': 842,
  'revenue': 1842000,
  'created_at': '2026-06-12T09:41:00.000Z',
  'updated_at': '2026-08-12T09:41:00.000Z',
};
