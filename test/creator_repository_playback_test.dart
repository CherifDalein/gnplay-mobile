import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/api_exception.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:gnplay/features/creator/data/creator_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });
  });

  // Contrat réel confirmé dans app/api/v1/routes/streaming.py :
  // POST /videos/{id}/playback-session -> { token, expires_at, watermark }
  // puis GET /stream/{id}/master.m3u8?token=... (le seul chemin qui
  // fonctionne pour du HLS chiffré multi-fichiers — voir la doc du repository).

  test(
    'loadVideoPlaybackAccess crée une session puis construit l’URL /stream avec le token',
    () async {
      String? capturedDeviceId;
      var requestIndex = 0;
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          requestIndex++;
          if (requestIndex == 1) {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/videos/video-1/playback-session');
            capturedDeviceId = request.url.queryParameters['device_id'];
            expect(capturedDeviceId, startsWith('gnplay_flutter_'));
            expect(request.headers['Authorization'], 'Bearer access-token');

            return http.Response(
              jsonEncode({
                'token': 'session-token',
                'expires_at': '2026-09-03T12:00:00.000Z',
                'watermark': 'Mariama Diallo - 4407',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          fail('Un seul appel réseau est attendu (pas de fallback /access).');
        }),
      );

      final access = await repository.loadVideoPlaybackAccess('video-1');

      expect(
        access.url,
        'https://gnplay-api.nextgenz.tech/api/v1/stream/video-1/master.m3u8?token=session-token',
      );
      expect(access.watermark, 'Mariama Diallo - 4407');
      expect(access.expiresAt, DateTime.parse('2026-09-03T12:00:00.000Z'));
      expect(capturedDeviceId, isNotEmpty);
    },
  );

  test('réutilise le device id déjà persisté', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'gnplay_device_id': 'existing-device',
    });

    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        expect(request.url.queryParameters['device_id'], 'existing-device');
        return http.Response(jsonEncode({'token': 'session-token'}), 200);
      }),
    );

    await repository.loadVideoPlaybackAccess('video-1');
  });

  test(
    'propage une erreur explicite si le backend refuse la session (ex: appareil non enregistré)',
    () async {
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'detail': 'Playback is restricted to registered active devices',
            }),
            403,
          );
        }),
      );

      expect(
        () => repository.loadVideoPlaybackAccess('video-1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Playback is restricted to registered active devices',
          ),
        ),
      );
    },
  );

  test('propage une erreur si la session ne contient pas de token', () async {
    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        return http.Response(jsonEncode({'watermark': 'x'}), 200);
      }),
    );

    expect(
      () => repository.loadVideoPlaybackAccess('video-1'),
      throwsA(isA<ApiException>()),
    );
  });
}
