import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/api_exception.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:gnplay/features/videos/data/video_repository.dart';

import 'support/api_test_support.dart';

Map<String, dynamic> _video(int i) => {
  'id': 'v$i',
  'user_id': 'u1',
  'title': 'Vidéo $i',
  'price': 0,
  'status': 'ready',
  'is_published': true,
  'created_at': '2026-06-12T09:41:00Z',
  'updated_at': '2026-06-12T09:41:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(seedSession);

  test('listMyVideos enchaîne les pages de 100', () async {
    final offsets = <String>[];
    final repository = VideoRepository(
      testApi((request) async {
        expect(request.url.queryParameters['limit'], '100');
        final offset = request.url.queryParameters['offset']!;
        offsets.add(offset);
        return jsonResponse([
          for (var i = 0; i < (offset == '0' ? 100 : 37); i++) _video(i),
        ]);
      }),
      const TokenStorage(),
    );

    expect(await repository.listMyVideos(), hasLength(137));
    expect(offsets, ['0', '100']);
  });

  test(
    'session de lecture : device_id en query puis URL /stream avec le token',
    () async {
      seedSession(extra: {'gnplay_device_id': 'device-42'});
      final repository = VideoRepository(
        testApi((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/videos/video-1/playback-session');
          expect(request.url.queryParameters['device_id'], 'device-42');
          return jsonResponse({
            'token': 'session-token',
            'expires_at': '2026-09-03T12:00:00.000Z',
            'watermark': 'Mariama Diallo - 4407',
          });
        }),
        const TokenStorage(),
      );

      final access = await repository.createPlaybackSession('video-1');
      expect(
        access.url,
        'https://api.test/api/v1/stream/video-1/master.m3u8?token=session-token',
      );
      expect(access.watermark, 'Mariama Diallo - 4407');
    },
  );

  test(
    'appareil non enregistré : message traduit, texte brut reconnaissable',
    () async {
      final repository = VideoRepository(
        testApi(
          (_) async => jsonResponse({
            'detail': 'Playback is restricted to registered active devices',
          }, 403),
        ),
        const TokenStorage(),
      );

      expect(
        repository.createPlaybackSession('video-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.serverSays('device'),
                'serverSays(device)',
                isTrue,
              )
              .having((e) => e.message, 'message', contains('appareil')),
        ),
      );
    },
  );

  test('session sans token : erreur explicite', () async {
    final repository = VideoRepository(
      testApi((_) async => jsonResponse({'watermark': 'x'})),
      const TokenStorage(),
    );
    expect(
      repository.createPlaybackSession('video-1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('relance du transcodage et statut de traitement', () async {
    final repository = VideoRepository(
      testApi((request) async {
        if (request.url.path == '/api/v1/internal/videos/abc/retry-transcode') {
          expect(request.method, 'POST');
          return jsonResponse({'status': 'queued'});
        }
        expect(request.url.path, '/api/v1/videos/abc/processing-status');
        return jsonResponse({
          'video_id': 'abc',
          'status': 'not_started',
          'progress': 0,
          'attempts': 0,
        });
      }),
      const TokenStorage(),
    );

    await repository.retryTranscode('abc');
    final status = await repository.getProcessingStatus('abc');
    expect(status.isNotStarted, isTrue);
    expect(status.isDone, isFalse);
  });
}
