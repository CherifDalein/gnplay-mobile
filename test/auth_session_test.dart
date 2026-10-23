import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/router/app_router.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:gnplay/features/auth/presentation/providers/auth_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/api_test_support.dart';

Map<String, Object?> _user(String role) => {
  'id': 'u1',
  'full_name': 'Mariama Diallo',
  'phone_number': '+224621458807',
  'role': role,
  'is_active': true,
  'is_superuser': false,
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

/// API simulée : [refresh] décide de la réponse au renouvellement de session,
/// [role] du rôle renvoyé par /users/me ; le reste répond 404.
MockClient _api({
  required Future<http.Response> Function() refresh,
  String role = 'creator',
  Future<http.Response> Function(http.Request)? login,
}) {
  return MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/auth/refresh-token':
        return refresh();
      case '/api/v1/auth/login':
        return login!(request);
      case '/api/v1/users/me':
        return jsonResponse(_user(role));
    }
    return jsonResponse({'detail': 'Not Found'}, 404);
  });
}

Future<ProviderContainer> _boot(MockClient client) async {
  final container = ProviderContainer(
    overrides: [httpClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  container.read(authControllerProvider);
  // Laisse bootstrap() se terminer.
  for (
    var i = 0;
    i < 20 && container.read(authControllerProvider).isLoading;
    i++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('restauration de session', () {
    test('refresh refusé (401) : déconnecté et stockage vidé', () async {
      seedSession();
      final container = await _boot(
        _api(
          refresh: () async =>
              jsonResponse({'detail': 'Refresh token invalide'}, 401),
        ),
      );
      expect(container.read(authControllerProvider).valueOrNull, isNull);
      expect(await const TokenStorage().read(), isNull);
    });

    test('hors-ligne : la session locale est conservée', () async {
      seedSession();
      final container = await _boot(
        _api(refresh: () async => throw const SocketException('offline')),
      );
      expect(
        container.read(authControllerProvider).valueOrNull?.accessToken,
        'access-token',
      );
      expect(await const TokenStorage().read(), isNotNull);
    });

    test('refresh accepté : nouveaux jetons enregistrés', () async {
      seedSession();
      final container = await _boot(
        _api(
          refresh: () async => jsonResponse({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'token_type': 'bearer',
          }),
        ),
      );
      expect(
        container.read(authControllerProvider).valueOrNull?.accessToken,
        'new-access',
      );
      expect((await const TokenStorage().read())!.refreshToken, 'new-refresh');
    });
  });

  test(
    'échec de connexion : erreur sur le formulaire, session intacte',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = await _boot(
        _api(
          refresh: () async => jsonResponse({}, 401),
          login: (_) async => jsonResponse({
            'detail': 'Numéro de téléphone ou Mot de passe incorrect',
          }, 401),
        ),
      );

      final ok = await container
          .read(loginControllerProvider.notifier)
          .login(phoneNumber: '+224', password: 'x');

      expect(ok, isFalse);
      expect(
        container.read(loginControllerProvider).error.toString(),
        'Numéro de téléphone ou Mot de passe incorrect',
      );
      final auth = container.read(authControllerProvider);
      expect(auth.isLoading, isFalse);
      expect(auth.valueOrNull, isNull);
    },
  );

  group('routeur', () {
    Future<String> landing(WidgetTester tester, {required String role}) async {
      seedSession();
      final client = _api(
        refresh: () async => jsonResponse({
          'access_token': 'a2',
          'refresh_token': 'r2',
          'token_type': 'bearer',
        }),
        role: role,
      );
      final container = ProviderContainer(
        overrides: [httpClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: ref.watch(routerProvider),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return container.read(routerProvider).location;
    }

    testWidgets('un créateur arrive sur le tableau de bord', (tester) async {
      expect(await landing(tester, role: 'creator'), '/home');
    });

    testWidgets('un spectateur est envoyé vers « Devenir créateur »', (
      tester,
    ) async {
      expect(await landing(tester, role: 'viewer'), '/become-creator');
    });

    testWidgets('sans session : écran de connexion', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(
            _api(refresh: () async => jsonResponse({}, 401)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: ref.watch(routerProvider),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(container.read(routerProvider).location, '/login');
    });
  });
}
