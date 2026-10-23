import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:gnplay/features/auth/presentation/screens/login_screen.dart';
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

const _token = {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'token_type': 'bearer',
};

Future<void> _pumpLogin(WidgetTester tester, _Api api) async {
  // Petit écran (360×640) : vérifie aussi l'absence de débordement.
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('PAGE INSCRIPTION')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const Scaffold(body: Text('PAGE OUBLI')),
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
  await tester.pump(const Duration(milliseconds: 50));
}

String _text(WidgetTester tester, int fieldIndex) => tester
    .widget<TextFormField>(find.byType(TextFormField).at(fieldIndex))
    .controller!
    .text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'champs vides ou numéro invalide : erreurs locales, aucun appel',
    (tester) async {
      final api = _Api((_) async => jsonResponse(_token));
      await _pumpLogin(tester, api);

      await _tap(tester, find.text('Se connecter'));
      expect(find.text('Le numéro de téléphone est requis.'), findsOneWidget);
      expect(find.text('Le mot de passe est requis.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '12345');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await _tap(tester, find.text('Se connecter'));
      expect(find.textContaining('Numéro invalide'), findsOneWidget);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('envoie le numéro en E.164 dans le formulaire de connexion', (
    tester,
  ) async {
    final api = _Api((request) async {
      if (request.url.path == '/api/v1/auth/login') return jsonResponse(_token);
      return jsonResponse({}, 200);
    });
    await _pumpLogin(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), '621 45 88 07');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await _tap(tester, find.text('Se connecter'));
    await _settle(tester);

    final login = api.to('/api/v1/auth/login');
    expect(login, hasLength(1));
    expect(login.single.headers['content-type'], contains('urlencoded'));
    expect(login.single.bodyFields['username'], '+224621458807');
    expect(login.single.bodyFields['password'], 'secret1');
  });

  testWidgets('un numéro collé avec un autre indicatif change le pays', (
    tester,
  ) async {
    final api = _Api((_) async => jsonResponse(_token));
    await _pumpLogin(tester, api);
    expect(find.text('+224'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '+221 77 123 45 67',
    );
    await tester.pump();
    expect(find.text('+221'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await _tap(tester, find.text('Se connecter'));
    await _settle(tester);
    expect(
      api.to('/api/v1/auth/login').single.bodyFields['username'],
      '+221771234567',
    );
  });

  testWidgets('401 : bandeau d’erreur, champs conservés, bouton réutilisable', (
    tester,
  ) async {
    final api = _Api(
      (_) async => jsonResponse({
        'detail': 'Numéro de téléphone ou Mot de passe incorrect',
      }, 401),
    );
    await _pumpLogin(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), '621458807');
    await tester.enterText(find.byType(TextFormField).at(1), 'mauvais');
    await _tap(tester, find.text('Se connecter'));
    await _settle(tester);

    expect(
      find.text('Numéro de téléphone ou mot de passe incorrect.'),
      findsOneWidget,
    );
    expect(_text(tester, 0), '621458807');
    expect(_text(tester, 1), 'mauvais');

    // Le bouton n'est plus désactivé : un second essai part.
    await _tap(tester, find.text('Se connecter'));
    await _settle(tester);
    expect(api.to('/api/v1/auth/login'), hasLength(2));
  });

  testWidgets('bouton désactivé pendant la connexion', (tester) async {
    final api = _Api((request) async {
      if (request.url.path != '/api/v1/auth/login') return jsonResponse({});
      await Future<void>.delayed(const Duration(seconds: 2));
      return jsonResponse(_token);
    });
    await _pumpLogin(tester, api);

    await tester.enterText(find.byType(TextFormField).at(0), '621458807');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await _tap(tester, find.text('Se connecter'));

    // En cours : spinner à la place du libellé, un seul appel malgré un 2e appui.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(GnButton).first);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(api.to('/api/v1/auth/login'), hasLength(1));
  });

  testWidgets('afficher / masquer le mot de passe', (tester) async {
    await _pumpLogin(tester, _Api((_) async => jsonResponse(_token)));

    await _tap(tester, find.text('Afficher'));
    expect(find.text('Masquer'), findsOneWidget);
    await _tap(tester, find.text('Masquer'));
    expect(find.text('Afficher'), findsOneWidget);
  });

  testWidgets('liens vers « Mot de passe oublié » et « Créer un compte »', (
    tester,
  ) async {
    await _pumpLogin(tester, _Api((_) async => jsonResponse(_token)));

    await _tap(tester, find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE OUBLI'), findsOneWidget);

    final context = tester.element(find.text('PAGE OUBLI'));
    GoRouter.of(context).pop();
    await tester.pumpAndSettle();
    // Retour avec le formulaire intact.
    await _tap(tester, find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE INSCRIPTION'), findsOneWidget);
  });
}
