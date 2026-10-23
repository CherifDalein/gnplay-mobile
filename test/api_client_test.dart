import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/api_exception.dart';
import 'package:http/http.dart' as http;

import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(seedSession);

  Future<ApiException> errorOf(Future<Object?> call) async {
    try {
      await call;
    } on ApiException catch (error) {
      return error;
    }
    fail('Une ApiException était attendue.');
  }

  test('envoie le jeton, le JSON et décode une réponse UTF-8', () async {
    final api = testApi((request) async {
      expect(request.url.toString(), 'https://api.test/api/v1/x?limit=5');
      expect(request.headers['Authorization'], 'Bearer access-token');
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(bodyOf(request), {'a': 1});
      return jsonResponse({'title': 'Nuits de Conakry — épisode 3'});
    });

    final json = await api.post(
      '/api/v1/x',
      json: {'a': 1},
      query: {'limit': 5, 'skip': null},
    );
    expect(json, {'title': 'Nuits de Conakry — épisode 3'});
  });

  test(
    'formulaire OAuth2 et appels anonymes sans en-tête Authorization',
    () async {
      final api = testApi((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.bodyFields, {'username': '+224'});
        return jsonResponse({'ok': true});
      });
      await api.post(
        '/login',
        form: {'username': '+224'},
        authenticated: false,
      );
    },
  );

  test('sans session, échoue sans appel réseau avec une erreur 401', () async {
    FlutterSecureStorage.setMockInitialValues({});
    var called = false;
    final api = testApi((_) async {
      called = true;
      return jsonResponse({});
    });
    final error = await errorOf(api.get('/api/v1/users/me'));
    expect(error.kind, ApiErrorKind.unauthorized);
    expect(called, isFalse);
  });

  test('un message serveur en français est affiché tel quel', () async {
    final api = testApi(
      (_) async =>
          jsonResponse({'detail': 'Solde insuffisant pour ce retrait'}, 400),
    );
    final error = await errorOf(api.get('/x'));
    expect(error.message, 'Solde insuffisant pour ce retrait');
    expect(error.kind, ApiErrorKind.invalid);
  });

  test(
    'les messages français courts du serveur sont affichés tels quels',
    () async {
      for (final detail in [
        'Utilisateur inexistant',
        'Trop de tentatives, ressayez dans 1min',
        "Ce pays n'existe pas",
      ]) {
        final api = testApi((_) async => jsonResponse({'detail': detail}, 400));
        expect((await errorOf(api.get('/x'))).message, detail);
      }
    },
  );

  test(
    'un message anglais inconnu est remplacé par un texte générique',
    () async {
      final api = testApi(
        (_) async =>
            jsonResponse({'detail': 'Offline download is restricted'}, 403),
      );
      expect(
        (await errorOf(api.get('/x'))).message,
        'Cette action n’est pas autorisée.',
      );
    },
  );

  test(
    'un message anglais connu est traduit, le texte brut reste accessible',
    () async {
      final api = testApi(
        (_) async => jsonResponse({'detail': 'Video not found'}, 404),
      );
      final error = await errorOf(api.get('/x'));
      expect(error.message, 'Cette vidéo est introuvable.');
      expect(error.serverDetail, 'Video not found');
      expect(error.serverSays('not found'), isTrue);
      expect(error.kind, ApiErrorKind.notFound);
    },
  );

  test('une exception technique du serveur n’est jamais affichée', () async {
    final api = testApi(
      (_) async => jsonResponse({
        'detail':
            'Upload init failed: (psycopg2.errors.NumericValueOutOfRange)',
      }, 500),
    );
    final error = await errorOf(api.get('/x'));
    expect(error.message, isNot(contains('psycopg2')));
    expect(error.kind, ApiErrorKind.server);
  });

  test('erreur de validation 422 (liste) et limite 429 (clé error)', () async {
    final validation = testApi(
      (_) async => jsonResponse({
        'detail': [
          {
            'loc': ['body', 'amount'],
            'msg': 'Input should be greater than 0',
          },
        ],
      }, 422),
    );
    final invalid = await errorOf(validation.get('/x'));
    expect(invalid.kind, ApiErrorKind.invalid);
    expect(invalid.message, 'Certaines informations sont invalides.');

    final limited = testApi(
      (_) async =>
          jsonResponse({'error': 'Rate limit exceeded: 5 per 1 minute'}, 429),
    );
    final tooMany = await errorOf(limited.get('/x'));
    expect(tooMany.kind, ApiErrorKind.rateLimited);
    expect(tooMany.message, contains('Trop de tentatives'));
  });

  test('réseau coupé et délai dépassé donnent des messages clairs', () async {
    final offline = testApi((_) async => throw const SocketException('down'));
    final network = await errorOf(offline.get('/x'));
    expect(network.kind, ApiErrorKind.network);
    expect(network.isNetwork, isTrue);
    expect(network.message, contains('Internet'));

    final slow = testApi(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 50),
    );
    final timeout = await errorOf(slow.get('/x'));
    expect(timeout.kind, ApiErrorKind.timeout);
  });

  test(
    'putExternal : pas de jeton vers le stockage, erreur si refus',
    () async {
      final api = testApi((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('', 403);
      });
      final error = await errorOf(api.putExternal('https://r2.test/p1', [1]));
      expect(error.statusCode, 403);
    },
  );
}
