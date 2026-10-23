import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/publish/data/upload_repository.dart';
import 'package:http/http.dart' as http;

import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(seedSession);

  test(
    'init lit la réponse RÉELLE du backend (URL des parties sous `url`)',
    () async {
      final repository = UploadRepository(
        testApi((request) async {
          expect(request.url.path, '/api/v1/videos/upload/init');
          expect(bodyOf(request), {
            'filename': 'clip.mp4',
            'file_size': 20971520,
            'mime_type': 'video/mp4',
            'title': 'Clip',
            'price': 0,
          });
          // Copie de la réponse de app/api/v1/routes/videos.py (upload_init) :
          // les parties viennent de r2_service.generate_batch_part_urls.
          return jsonResponse({
            'video_id': 'video-1',
            'upload_id': 'upload-1',
            'object_key': 'videos/video-1/source.mp4',
            'chunk_size': 10485760,
            'total_parts': 2,
            'max_parallel_uploads': 3,
            'expires_in': 3600,
            'part_size': 10485760,
            'parts': [
              {'part_number': 1, 'url': 'https://r2.test/part1'},
              {'part_number': 2, 'url': 'https://r2.test/part2'},
            ],
          });
        }),
      );

      final init = await repository.init(
        filename: 'clip.mp4',
        fileSize: 20971520,
        mimeType: 'video/mp4',
        title: 'Clip',
        price: 0,
      );

      expect(init.videoId, 'video-1');
      expect(init.totalParts, 2);
      expect(init.parts.map((p) => p.uploadUrl), [
        'https://r2.test/part1',
        'https://r2.test/part2',
      ]);
    },
  );

  test('presignParts lit `upload_url` (format de parts/presign)', () async {
    final repository = UploadRepository(
      testApi((request) async {
        expect(request.url.path, '/api/v1/videos/upload/video-1/parts/presign');
        expect(bodyOf(request), {
          'upload_id': 'upload-1',
          'parts': [2],
        });
        return jsonResponse({
          'parts': [
            {'part_number': 2, 'upload_url': 'https://r2.test/fresh2'},
          ],
        });
      }),
    );
    final parts = await repository.presignParts(
      'video-1',
      uploadId: 'upload-1',
      partNumbers: const [2],
    );
    expect(parts.single.uploadUrl, 'https://r2.test/fresh2');
  });

  test(
    'uploadPart envoie les octets bruts sans jeton et renvoie l’ETag nettoyé',
    () async {
      final repository = UploadRepository(
        testApi((request) async {
          expect(request.method, 'PUT');
          expect(request.url.toString(), 'https://r2.test/part1');
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.bodyBytes, [1, 2, 3]);
          return http.Response('', 200, headers: {'etag': '"abc123"'});
        }),
      );
      expect(
        await repository.uploadPart('https://r2.test/part1', [1, 2, 3]),
        'abc123',
      );
    },
  );

  test('confirmPart, complete (format S3) et listConfirmedParts', () async {
    final calls = <String>[];
    final repository = UploadRepository(
      testApi((request) async {
        calls.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/api/v1/videos/upload/video-1/parts/confirm':
            expect(bodyOf(request), {
              'part_number': 1,
              'etag': 'abc',
              'size': 3,
            });
            return jsonResponse({'status': 'ok'});
          case '/api/v1/videos/upload/video-1/complete':
            expect(bodyOf(request), {
              'upload_id': 'upload-1',
              'parts': [
                {'PartNumber': 1, 'ETag': 'abc'},
                {'PartNumber': 2, 'ETag': 'def'},
              ],
            });
            return jsonResponse({'status': 'queued'}, 202);
          case '/api/v1/videos/upload/video-1/parts':
            return jsonResponse({
              'parts': [
                {'part_number': 1, 'etag': 'abc'},
              ],
            });
        }
        return jsonResponse({'detail': 'Not Found'}, 404);
      }),
    );

    await repository.confirmPart(
      'video-1',
      partNumber: 1,
      etag: 'abc',
      size: 3,
    );
    await repository.complete(
      'video-1',
      uploadId: 'upload-1',
      parts: const [(partNumber: 1, etag: 'abc'), (partNumber: 2, etag: 'def')],
    );
    final confirmed = await repository.listConfirmedParts('video-1');

    expect(confirmed.single.partNumber, 1);
    expect(confirmed.single.etag, 'abc');
    expect(calls, hasLength(3));
  });
}
