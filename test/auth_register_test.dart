import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/presentation/screens/register_screen.dart';
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

const _otp = '/api/v1/auth/request-otp';
const _verify = '/api/v1/auth/verify-otp';
const _register = '/api/v1/auth/register';
const _login = '/api/v1/auth/login';

const _user = {
  'id': 'u1',
  'full_name': 'Mariama Diallo',
  'phone_number': '+224621458807',
  'role': 'viewer',
  'is_active': true,
  'is_superuser': false,
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

const _token = {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'token_type': 'bearer',
};

http.Response _otpSent() => jsonResponse({
  'phone_number': '+224621458807',
  'otp_type': 'register',
  'expires_at': '2026-01-01T00:05:00Z',
}, 201);

Future<void> _pumpRegister(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('PAGE CONNEXION')),
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

/// Laisse les appels simulés se terminer et les animations s'achever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fillAccount(
  WidgetTester tester, {
  String name = 'Mariama Diallo',
  String phone = '621 45 88 07',
  String password = 'secret1',
  String? confirm,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), phone);
  await tester.enterText(fields.at(2), password);
  await tester.enterText(fields.at(3), confirm ?? password);
}

Future<void> _toCodeStep(WidgetTester tester) async {
  await _fillAccount(tester);
  await _tap(tester, find.text('Continuer'));
  await _settle(tester);
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const ValueKey('otp-code-field')), code);
  await tester.pump();
}

/// API d'inscription configurable ; [verify] et [register] renvoient les
/// réponses voulues pour chaque test.
_Api _flowApi({
  http.Response Function()? otp,
  http.Response Function()? verify,
  http.Response Function()? register,
  http.Response Function()? login,
}) {
  return _Api((request) async {
    switch (request.url.path) {
      case _otp:
        return (otp ?? _otpSent)();
      case _verify:
        return (verify ?? () => http.Response('', 204))();
      case _register:
        return (register ?? () => jsonResponse(_user, 201))();
      case _login:
        return (login ?? () => jsonResponse(_token))();
    }
    return jsonResponse({}, 200);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('validation locale : nom trop court, mots de passe différents', (
    tester,
  ) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);

    await _fillAccount(
      tester,
      name: 'Ali',
      phone: '12',
      password: 'abc',
      confirm: 'abd',
    );
    await _tap(tester, find.text('Continuer'));

    expect(
      find.textContaining('Le nom doit contenir au moins 6 caractères'),
      findsOneWidget,
    );
    expect(find.textContaining('Numéro invalide'), findsOneWidget);
    expect(
      find.text('Le mot de passe doit contenir au moins 4 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(api.requests, isEmpty);
  });

  testWidgets('le pays est sélectionnable et change l’indicatif envoyé', (
    tester,
  ) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);

    await _tap(tester, find.text('Guinée (GNF)'));
    await tester.pumpAndSettle();
    expect(find.text('Sénégal'), findsOneWidget);
    await tester.tap(find.text('Sénégal'));
    await tester.pumpAndSettle();
    expect(find.text('Sénégal (XOF)'), findsOneWidget);

    await _fillAccount(tester, phone: '77 123 45 67');
    await _tap(tester, find.text('Continuer'));
    await _settle(tester);

    expect(bodyOf(api.to(_otp).single)['phone_number'], '+221771234567');
  });

  testWidgets('envoie le code avec le bon payload et affiche le numéro', (
    tester,
  ) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    final request = api.to(_otp).single;
    expect(bodyOf(request), {
      'phone_number': '+224621458807',
      'otp_type': 'register',
    });
    expect(find.text('Vérification'), findsOneWidget);
    expect(find.textContaining('+224 621 45 88 07'), findsOneWidget);
    expect(find.text('Renvoyer le code dans '), findsNothing);
    expect(find.textContaining('01:00'), findsOneWidget);
  });

  testWidgets(
    'modifier le numéro revient à l’étape précédente sans rien perdre',
    (tester) async {
      final api = _flowApi();
      await _pumpRegister(tester, api);
      await _toCodeStep(tester);

      await _tap(tester, find.text('Modifier'));
      expect(find.text('Créer votre compte'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '621 45 88 07',
      );

      // Même numéro, code envoyé il y a moins d'une minute : pas de renvoi.
      await _tap(tester, find.text('Continuer'));
      await _settle(tester);
      expect(find.text('Vérification'), findsOneWidget);
      expect(api.to(_otp), hasLength(1));

      // Autre numéro : nouvel envoi.
      await _tap(tester, find.text('Modifier'));
      await tester.enterText(find.byType(TextFormField).at(1), '622 00 00 00');
      await _tap(tester, find.text('Continuer'));
      await _settle(tester);
      expect(api.to(_otp), hasLength(2));
      expect(bodyOf(api.to(_otp).last)['phone_number'], '+224622000000');
    },
  );

  testWidgets('compte à rebours réel puis renvoi du code (et par SMS)', (
    tester,
  ) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('00:45'), findsOneWidget);
    expect(find.text('Renvoyer le code'), findsNothing);

    // Le renvoi est bloqué tant que le compte à rebours tourne.
    await tester.tap(find.text('Recevoir le code par SMS'));
    await tester.pump();
    expect(api.to(_otp), hasLength(1));

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Renvoyer le code'), findsOneWidget);

    await _tap(tester, find.text('Renvoyer le code'));
    await _settle(tester);
    expect(api.to(_otp), hasLength(2));
    expect(bodyOf(api.to(_otp).last).containsKey('channel'), isFalse);
    expect(find.textContaining('01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    await _tap(tester, find.text('Recevoir le code par SMS'));
    await _settle(tester);
    expect(api.to(_otp), hasLength(3));
    expect(bodyOf(api.to(_otp).last)['channel'], 'sms');
  });

  testWidgets('429 au renvoi : message affiché et compte à rebours relancé', (
    tester,
  ) async {
    var limited = false;
    final api = _flowApi(
      otp: () => limited
          ? jsonResponse({
              'detail': 'Trop de tentatives, ressayez dans 1min',
            }, 429)
          : _otpSent(),
    );
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await tester.pump(const Duration(seconds: 61));
    limited = true;
    await _tap(tester, find.text('Renvoyer le code'));
    await _settle(tester);

    expect(find.text('Trop de tentatives, ressayez dans 1min'), findsOneWidget);
    expect(find.textContaining('01:00'), findsOneWidget);
    expect(find.text('Renvoyer le code'), findsNothing);

    // À la fin du nouveau décompte, on peut renvoyer à nouveau.
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Renvoyer le code'), findsOneWidget);
  });

  testWidgets('429 dès la demande : on passe quand même à la saisie du code', (
    tester,
  ) async {
    final api = _flowApi(
      otp: () => jsonResponse({
        'detail': 'Un code vient d’être envoyé à ce numéro.',
      }, 429),
    );
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    expect(find.text('Vérification'), findsOneWidget);
    expect(
      find.text('Un code vient d’être envoyé à ce numéro.'),
      findsOneWidget,
    );
    expect(find.textContaining('01:00'), findsOneWidget);
  });

  testWidgets('numéro hors zone : le message du serveur est affiché tel quel', (
    tester,
  ) async {
    const message = 'L’envoi de codes n’est pas disponible pour ce pays.';
    final api = _flowApi(otp: () => jsonResponse({'detail': message}, 400));
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    expect(find.text(message), findsOneWidget);
    expect(find.text('Créer votre compte'), findsOneWidget);
  });

  testWidgets('code trop court : erreur locale, aucun appel', (tester) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '123');
    await _tap(tester, find.text('Vérifier'));
    expect(find.text('Entrez le code à 6 chiffres.'), findsOneWidget);
    expect(api.to(_verify), isEmpty);
  });

  testWidgets('mauvais code : le message du fournisseur est affiché tel quel', (
    tester,
  ) async {
    final api = _flowApi(
      verify: () => jsonResponse({
        'detail': 'Code incorrect — 4 tentative(s) restante(s).',
      }, 400),
    );
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '123456');
    await _tap(tester, find.text('Vérifier'));
    await _settle(tester);

    expect(
      find.text('Code incorrect — 4 tentative(s) restante(s).'),
      findsOneWidget,
    );
    expect(api.to(_register), isEmpty);
    // Le code saisi reste pour être corrigé.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('otp-code-field')))
          .controller!
          .text,
      '123456',
    );
  });

  testWidgets('code expiré : invite à renvoyer un code', (tester) async {
    final api = _flowApi(
      verify: () =>
          jsonResponse({'detail': 'OTP Invalide ou Déjà expiré'}, 400),
    );
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '123456');
    await _tap(tester, find.text('Vérifier'));
    await _settle(tester);

    expect(
      find.textContaining(
        'OTP Invalide ou Déjà expiré Renvoyez un nouveau code',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'register échoue après verify-otp : nouvel essai sans revérifier',
    (tester) async {
      var registerFails = true;
      final api = _flowApi(
        register: () => registerFails
            ? jsonResponse({'detail': 'Internal Server Error'}, 500)
            : jsonResponse(_user, 201),
      );
      await _pumpRegister(tester, api);
      await _toCodeStep(tester);

      await _enterCode(tester, '123456');
      await _tap(tester, find.text('Vérifier'));
      await _settle(tester);

      expect(api.to(_verify), hasLength(1));
      expect(bodyOf(api.to(_verify).single), {
        'phone_number': '+224621458807',
        'otp_type': 'register',
        'code': '123456',
      });
      expect(api.to(_register), hasLength(1));
      // Numéro vérifié mémorisé : plus de saisie de code, bouton de reprise.
      expect(find.textContaining('Numéro vérifié'), findsOneWidget);
      expect(find.byKey(const ValueKey('otp-code-field')), findsNothing);
      expect(find.text('Créer mon compte'), findsOneWidget);

      registerFails = false;
      await _tap(tester, find.text('Créer mon compte'));
      await _settle(tester);

      expect(api.to(_verify), hasLength(1), reason: 'pas de 2e verify-otp');
      expect(api.to(_register), hasLength(2));
      expect(bodyOf(api.to(_register).last), {
        'full_name': 'Mariama Diallo',
        'phone_number': '+224621458807',
        'country_iso2': 'GN',
        'password': 'secret1',
      });
      expect(api.to(_login), hasLength(1));
    },
  );

  testWidgets('409 : compte existant, propose d’aller à la connexion', (
    tester,
  ) async {
    final api = _flowApi(
      register: () => jsonResponse({
        'detail': 'Un compte avec ce numéro de téléphone existe déjà',
      }, 409),
    );
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '123456');
    await _tap(tester, find.text('Vérifier'));
    await _settle(tester);

    expect(
      find.text('Un compte avec ce numéro de téléphone existe déjà'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE CONNEXION'), findsOneWidget);
  });

  testWidgets('succès : register puis connexion automatique', (tester) async {
    final api = _flowApi();
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '654321');
    await _tap(tester, find.text('Vérifier'));
    await _settle(tester);

    expect(api.to(_verify), hasLength(1));
    expect(api.to(_register), hasLength(1));
    final login = api.to(_login).single;
    expect(login.bodyFields['username'], '+224621458807');
    expect(login.bodyFields['password'], 'secret1');
    // Pas de navigation manuelle : le routeur de l'app redirige.
    expect(find.text('PAGE CONNEXION'), findsNothing);
  });

  testWidgets('connexion automatique refusée : /login et toast explicatif', (
    tester,
  ) async {
    final api = _flowApi(login: () => jsonResponse({'detail': 'Erreur'}, 500));
    await _pumpRegister(tester, api);
    await _toCodeStep(tester);

    await _enterCode(tester, '654321');
    await _tap(tester, find.text('Vérifier'));
    await _settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('PAGE CONNEXION'), findsOneWidget);
    expect(find.textContaining('Compte créé'), findsOneWidget);

    // Laisse le toast se refermer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
