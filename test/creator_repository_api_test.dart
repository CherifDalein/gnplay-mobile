import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:gnplay/features/creator/data/creator_repository.dart';
import 'package:gnplay/features/creator/domain/topup.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

CreatorRepository _repo(MockClient client) =>
    CreatorRepository(const TokenStorage(), client: client);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
    });
  });

  test('listMyVideos fetches every page of 100', () async {
    final offsets = <String>[];
    final repo = _repo(
      MockClient((request) async {
        expect(request.url.queryParameters['limit'], '100');
        final offset = request.url.queryParameters['offset']!;
        offsets.add(offset);
        final count = offset == '0' ? 100 : 37;
        return http.Response(
          jsonEncode([for (var i = 0; i < count; i++) _video(i)]),
          200,
        );
      }),
    );

    final videos = await repo.listMyVideos();

    expect(videos, hasLength(137));
    expect(offsets, ['0', '100']);
  });

  test('retryTranscode posts to the internal retry endpoint', () async {
    late http.Request seen;
    final repo = _repo(
      MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'status': 'queued'}), 200);
      }),
    );

    await repo.retryTranscode('abc');

    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/internal/videos/abc/retry-transcode');
    expect(seen.headers['Authorization'], 'Bearer a');
  });

  test(
    'initiateTopup returns the DexPay checkout and status maps enum',
    () async {
      final repo = _repo(
        MockClient((request) async {
          if (request.url.path == '/api/v1/payments/topup/initiate') {
            expect(jsonDecode(request.body), {'amount': 25000});
            return http.Response(
              jsonEncode({
                'payment_url': 'https://pay.test/checkout/1',
                'reference': 'topup_abc',
              }),
              200,
            );
          }
          expect(request.url.path, '/api/v1/payments/topup/status/topup_abc');
          return http.Response(
            jsonEncode({'status': 'completed', 'amount': 25000}),
            200,
          );
        }),
      );

      final checkout = await repo.initiateTopup(25000);
      expect(checkout.paymentUrl, 'https://pay.test/checkout/1');
      expect(checkout.reference, 'topup_abc');
      expect(await repo.getTopupStatus('topup_abc'), TopupStatus.completed);
    },
  );

  test('initiateTopup surfaces the backend error message', () async {
    final repo = _repo(
      MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'Montant invalide'}), 400),
      ),
    );

    expect(
      repo.initiateTopup(10),
      throwsA(predicate((e) => e.toString() == 'Montant invalide')),
    );
  });
}
