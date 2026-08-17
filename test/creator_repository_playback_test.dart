import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test(
    'playback access resolves relative URLs and keeps auth headers',
    () async {
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/videos/video-1/access');
          expect(request.headers['Authorization'], 'Bearer access-token');

          return http.Response(
            jsonEncode({
              'url': '/api/v1/stream/video-1/master.m3u8',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      );

      final access = await repository.loadVideoPlaybackAccess('video-1');

      expect(
        access.url,
        'https://gnplay-api.nextgenz.tech/api/v1/stream/video-1/master.m3u8',
      );
      expect(access.httpHeaders['Authorization'], 'Bearer access-token');
    },
  );

  test(
    'playback access leaves external presigned URLs without auth headers',
    () async {
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'url': 'https://cdn.example.com/signed/master.m3u8?token=abc',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      );

      final access = await repository.loadVideoPlaybackAccess('video-1');

      expect(
        access.url,
        'https://cdn.example.com/signed/master.m3u8?token=abc',
      );
      expect(access.httpHeaders, isEmpty);
    },
  );

  test('playback session is used when access URL is unavailable', () async {
    String? capturedDeviceId;
    var requestIndex = 0;
    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        requestIndex++;
        if (requestIndex == 1) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/videos/video-1/access');
          return http.Response(jsonEncode({'detail': 'Not found'}), 404);
        }

        capturedDeviceId = request.url.queryParameters['device_id'];

        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/videos/video-1/playback-session');
        expect(capturedDeviceId, startsWith('gnplay_flutter_'));
        expect(request.headers['Authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode({
            'token': 'session-token',
            'watermark': 'Mariama Diallo',
            'expires_in': 3600,
          }),
          200,
        );
      }),
    );

    final access = await repository.loadVideoPlaybackAccess('video-1');

    expect(
      access.url,
      'https://gnplay-api.nextgenz.tech/api/v1/stream/video-1/master.m3u8?token=session-token',
    );
    expect(access.sessionToken, 'session-token');
    expect(access.watermark, 'Mariama Diallo');
    expect(access.httpHeaders, isEmpty);
    expect(capturedDeviceId, isNotEmpty);
  });

  test('fallback playback session reuses the persisted device id', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'gnplay_device_id': 'existing-device',
    });

    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'detail': 'Not found'}), 404);
        }

        expect(request.url.queryParameters['device_id'], 'existing-device');

        return http.Response(jsonEncode({'token': 'session-token'}), 200);
      }),
    );

    final access = await repository.loadVideoPlaybackAccess('video-1');

    expect(
      access.url,
      'https://gnplay-api.nextgenz.tech/api/v1/stream/video-1/master.m3u8?token=session-token',
    );
  });
}
