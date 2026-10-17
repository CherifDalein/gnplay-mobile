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
    'initVideoUpload parses the real multipart-init response shape',
    () async {
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/videos/upload/init');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['filename'], 'clip.mp4');
          expect(body['file_size'], 20971520);
          expect(body['mime_type'], 'video/mp4');

          return http.Response(
            jsonEncode({
              'video_id': 'video-1',
              'upload_id': 'upload-1',
              'object_key': 'videos/video-1/source.mp4',
              'chunk_size': 10485760,
              'total_parts': 2,
              'max_parallel_uploads': 3,
              'expires_in': 3600,
              'parts': [
                {
                  'part_number': 1,
                  'upload_url': 'https://r2.example.com/part1',
                },
                {
                  'part_number': 2,
                  'upload_url': 'https://r2.example.com/part2',
                },
              ],
            }),
            200,
          );
        }),
      );

      final response = await repository.initVideoUpload(
        filename: 'clip.mp4',
        fileSize: 20971520,
        mimeType: 'video/mp4',
        title: 'Clip',
        price: 0,
      );

      expect(response.videoId, 'video-1');
      expect(response.uploadId, 'upload-1');
      expect(response.chunkSize, 10485760);
      expect(response.totalParts, 2);
      expect(response.parts, hasLength(2));
      expect(response.parts.first.partNumber, 1);
      expect(response.parts.first.uploadUrl, 'https://r2.example.com/part1');
    },
  );

  test('uploadChunk PUTs raw bytes and strips quotes from the ETag', () async {
    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), 'https://r2.example.com/part1');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('', 200, headers: {'etag': '"abc123"'});
      }),
    );

    final etag = await repository.uploadChunk('https://r2.example.com/part1', [
      1,
      2,
      3,
    ]);

    expect(etag, 'abc123');
  });

  test('confirmUploadPart posts part_number, etag and size', () async {
    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/videos/upload/video-1/parts/confirm');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['part_number'], 1);
        expect(body['etag'], 'abc123');
        expect(body['size'], 3);
        return http.Response('', 200);
      }),
    );

    await repository.confirmUploadPart(
      'video-1',
      partNumber: 1,
      etag: 'abc123',
      size: 3,
    );
  });

  test(
    'completeUpload sends PartNumber/ETag pairs as expected by the API',
    () async {
      final repository = CreatorRepository(
        const TokenStorage(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/videos/upload/video-1/complete');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['upload_id'], 'upload-1');
          expect(body['parts'], [
            {'PartNumber': 1, 'ETag': 'abc123'},
            {'PartNumber': 2, 'ETag': 'def456'},
          ]);
          return http.Response('', 202);
        }),
      );

      await repository.completeUpload(
        'video-1',
        uploadId: 'upload-1',
        parts: const [
          (partNumber: 1, etag: 'abc123'),
          (partNumber: 2, etag: 'def456'),
        ],
      );
    },
  );

  test('getProcessingStatus parses status and progress', () async {
    final repository = CreatorRepository(
      const TokenStorage(),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/videos/video-1/processing-status');
        return http.Response(
          jsonEncode({
            'video_id': 'video-1',
            'status': 'processing',
            'progress': 42,
            'attempts': 1,
          }),
          200,
        );
      }),
    );

    final status = await repository.getProcessingStatus('video-1');

    expect(status.status, 'processing');
    expect(status.progress, 42);
    expect(status.isDone, isFalse);
    expect(status.isFailed, isFalse);
  });
}
