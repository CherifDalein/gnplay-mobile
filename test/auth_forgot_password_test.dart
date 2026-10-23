import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/api_test_support.dart';

class _Api {
  _Api(this.handler);

  final Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    return handler(request);
  });

  List<http.Request> to(String path) =>
      requests.where((r) => r.url.path == path).toList();
}

const _request = '/api/v1/auth/request-password-reset';
const _reset = '/api/v1/auth/reset-password';

http.Response _codeSent() => jsonResponse({
  'phone_number': '+224621458807',
  'otp_type': 'reset_password',
  'expires_at': '2026-01-01T00:05:00Z',
}, 202);

_Api _flowApi({
  http.Response Function()? request,
  http.Response Function()? reset,
}) {
  return _Api((r) async {
    switch (r.url.path) {
      case _request:
        return (request ?? _codeSent)();
      case _reset:
        return (reset ?? () => http.Response('', 204))();
    }
    return jsonResponse({}, 200);
  });
}

Future<void> _pumpForgot(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('PAGE CONNEXION')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('PAGE INSCRIPTION')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [httpClientProvider.overrideWithValue(api.client)],
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _sendCode(
  WidgetTester tester, {
  String phone = '621 45 88 07',
}) async {
  await tester.enterText(find.byType(TextFormField).first, phone);
  await _tap(tester, find.text('Envoyer le code'));
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('numéro invalide : erreur locale, aucun appel', (tester) async {
    final api = _flowApi();
    await _pumpForgot(tester, api);

    await _tap(tester, find.text('Envoyer le code'));
    expect(find.text('Le numéro de téléphone est requis.'), findsOneWidget);

    await _sendCode(tester, phone: '12');
    expect(find.textContaining('Numéro invalide'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('compte inconnu (404) : message clair et lien d’inscription', (
    tester,
  ) async {
    final api = _flowApi(
      request: () => jsonResponse({'detail': 'Utilisateur inexistant'}, 404),
    );
    await _pumpForgot(tester, api);
    await _sendCode(tester);

    expect(
      find.text('Aucun compte n’est associé à ce numéro.'),
      findsOneWidget,
    );
    // On reste sur l'étape du numéro.
    expect(find.text('Envoyer le code'), findsOneWidget);

    await _tap(tester, find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE INSCRIPTION'), findsOneWidget);
  });

  testWidgets('429 : on passe à la saisie du code avec le message du serveur', (
    tester,
  ) async {
    final api = _flowApi(
      request: () => jsonResponse({
        'detail': 'Un code vient d’être envoyé à ce numéro.',
      }, 429),
    );
    await _pumpForgot(tester, api);
    await _sendCode(tester);

    expect(find.text('Nouveau mot de passe'), findsWidgets);
    expect(
      find.text('Un code vient d’être envoyé à ce numéro.'),
      findsOneWidget,
    );
    expect(find.textContaining('01:00'), findsOneWidget);
  });

  testWidgets(
    'succès complet : payloads, renvoi par SMS, toast, retour /login',
    (tester) async {
      final api = _flowApi();
      await _pumpForgot(tester, api);
      await _sendCode(tester);

      expect(bodyOf(api.to(_request).single), {
        'phone_number': '+224621458807',
        'otp_type': 'reset_password',
      });
      expect(find.textContaining('+224 621 45 88 07'), findsOneWidget);
      expect(find.textContaining('01:00'), findsOneWidget);

      // Renvoi par SMS une fois le compte à rebours terminé.
      await tester.pump(const Duration(seconds: 61));
      await _tap(tester, find.text('Recevoir le code par SMS'));
      await _settle(tester);
      expect(bodyOf(api.to(_request).last), {
        'phone_number': '+224621458807',
        'otp_type': 'reset_password',
        'channel': 'sms',
      });

      // Validation locale : code incomplet, mot de passe court, confirmation.
      await tester.enterText(
        find.byKey(const ValueKey('otp-code-field')),
        '123',
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'abc');
      await tester.enterText(find.byType(TextFormField).at(1), 'abd');
      await _tap(tester, find.text('Modifier le mot de passe'));
      expect(find.text('Entrez le code à 6 chiffres.'), findsOneWidget);
      expect(
        find.text('Le mot de passe doit contenir au moins 4 caractères.'),
        findsOneWidget,
      );
      expect(
        find.text('Les mots de passe ne correspondent pas.'),
        findsOneWidget,
      );
      expect(api.to(_reset), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('otp-code-field')),
        '482913',
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'nouveau1');
      await tester.enterText(find.byType(TextFormField).at(1), 'nouveau1');
      await _tap(tester, find.text('Modifier le mot de passe'));
      await _settle(tester);

      expect(bodyOf(api.to(_reset).single), {
        'phone_number': '+224621458807',
        'otp_type': 'reset_password',
        'code': '482913',
        'new_password': 'nouveau1',
      });
      await tester.pumpAndSettle();
      expect(find.text('PAGE CONNEXION'), findsOneWidget);
      expect(find.text('Mot de passe modifié'), findsOneWidget);

      // Laisse le toast se refermer.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('mauvais code : le message du serveur est affiché tel quel', (
    tester,
  ) async {
    final api = _flowApi(
      reset: () => jsonResponse({
        'detail': 'Code incorrect — 4 tentative(s) restante(s).',
      }, 400),
    );
    await _pumpForgot(tester, api);
    await _sendCode(tester);

    await tester.enterText(
      find.byKey(const ValueKey('otp-code-field')),
      '000000',
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'nouveau1');
    await tester.enterText(find.byType(TextFormField).at(1), 'nouveau1');
    await _tap(tester, find.text('Modifier le mot de passe'));
    await _settle(tester);

    expect(
      find.text('Code incorrect — 4 tentative(s) restante(s).'),
      findsOneWidget,
    );
    expect(find.text('PAGE CONNEXION'), findsNothing);
  });

  testWidgets('le retour de l’étape du code ramène au numéro, puis à /login', (
    tester,
  ) async {
    await _pumpForgot(tester, _flowApi());
    await _sendCode(tester);

    await tester.tap(find.bySemanticsLabel('Retour'));
    await tester.pump();
    expect(find.text('Envoyer le code'), findsOneWidget);

    // Sans pile de navigation et déconnecté : retour à la connexion.
    await tester.tap(find.bySemanticsLabel('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE CONNEXION'), findsOneWidget);
  });
}
