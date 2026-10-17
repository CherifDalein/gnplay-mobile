import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/authenticated_client.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:gnplay/features/auth/domain/token_response.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

void main() {
  late TokenStorage storage;
  var expiredCalls = 0;

  setUp(() async {
    storage = TokenStorage(secureStorage: _MemoryStorage());
    await storage.save(
      const TokenResponse(accessToken: 'old', refreshToken: 'r1'),
    );
    expiredCalls = 0;
  });

  AuthenticatedClient build(MockClient inner) => AuthenticatedClient(
    tokenStorage: storage,
    inner: inner,
    onSessionExpired: () => expiredCalls++,
  );

  test('refreshes on 401, retries once and persists rotated tokens', () async {
    var refreshes = 0;
    final seen = <String>[];
    final client = build(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh-token')) {
          refreshes++;
          expect(jsonDecode(request.body)['refresh_token'], 'r1');
          return http.Response(
            jsonEncode({'access_token': 'new', 'refresh_token': 'r2'}),
            200,
          );
        }
        seen.add(request.headers['Authorization']!);
        return request.headers['Authorization'] == 'Bearer new'
            ? http.Response('{"ok":true}', 200)
            : http.Response('{"detail":"expired"}', 401);
      }),
    );

    final response = await client.get(
      Uri.parse('https://x.test/api/v1/ping'),
      headers: {'Authorization': 'Bearer old'},
    );

    expect(response.statusCode, 200);
    expect(seen, ['Bearer old', 'Bearer new']);
    expect((await storage.read())!.refreshToken, 'r2');
    expect(refreshes, 1);
  });

  test('concurrent 401s share a single refresh (rotating tokens)', () async {
    var refreshes = 0;
    final client = build(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh-token')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({'access_token': 'new', 'refresh_token': 'r2'}),
            200,
          );
        }
        return request.headers['Authorization'] == 'Bearer new'
            ? http.Response('ok', 200)
            : http.Response('no', 401);
      }),
    );

    final results = await Future.wait([
      for (var i = 0; i < 4; i++)
        client.get(
          Uri.parse('https://x.test/api/v1/r$i'),
          headers: {'Authorization': 'Bearer old'},
        ),
    ]);

    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(refreshes, 1);
  });

  test(
    'uses the freshest stored token even if caller passes a stale one',
    () async {
      await storage.save(
        const TokenResponse(accessToken: 'fresh', refreshToken: 'r9'),
      );
      String? sent;
      final client = build(
        MockClient((request) async {
          sent = request.headers['Authorization'];
          return http.Response('ok', 200);
        }),
      );

      await client.get(
        Uri.parse('https://x.test/api/v1/ping'),
        headers: {'Authorization': 'Bearer stale'},
      );
      expect(sent, 'Bearer fresh');
    },
  );

  test('rejected refresh clears the session and signals expiry', () async {
    final client = build(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh-token')) {
          return http.Response('{"detail":"Invalid refresh token"}', 401);
        }
        return http.Response('{"detail":"expired"}', 401);
      }),
    );

    final response = await client.get(
      Uri.parse('https://x.test/api/v1/ping'),
      headers: {'Authorization': 'Bearer old'},
    );

    expect(response.statusCode, 401);
    expect(await storage.read(), isNull);
    expect(expiredCalls, 1);
  });

  test('network failure during refresh does not log the user out', () async {
    final client = build(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh-token')) {
          throw http.ClientException('offline');
        }
        return http.Response('no', 401);
      }),
    );

    final response = await client.get(
      Uri.parse('https://x.test/api/v1/ping'),
      headers: {'Authorization': 'Bearer old'},
    );

    expect(response.statusCode, 401);
    expect(await storage.read(), isNotNull);
    expect(expiredCalls, 0);
  });

  test(
    'requests without bearer (presigned PUT, login) pass through untouched',
    () async {
      var calls = 0;
      final client = build(
        MockClient((request) async {
          calls++;
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('', 401);
        }),
      );

      final response = await client.put(
        Uri.parse('https://r2.test/part'),
        body: 'x',
      );
      expect(response.statusCode, 401);
      expect(calls, 1);
    },
  );
}
