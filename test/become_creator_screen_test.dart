import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/router/app_router.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/creator/presentation/screens/become_creator_screen.dart';
import 'package:gnplay/features/profile/presentation/providers/current_user_provider.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'creator_dashboard_support.dart';
import 'support/api_test_support.dart';

const _becomeCreator = '/api/v1/users/me/become-creator';

final _confirmButton = find.descendant(
  of: find.byType(GnConfirmSheet),
  matching: find.text('Devenir créateur'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  group('écran seul', () {
    late List<String> calls;
    late Future<http.Response> Function(http.Request) onBecomeCreator;

    Future<void> open(WidgetTester tester) async {
      calls = [];
      usePhoneScreen(tester, height: 1000);
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == _becomeCreator) {
          return onBecomeCreator(request);
        }
        return jsonResponse(userJson(role: 'creator'));
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BecomeCreatorScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Text('page /settings')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            httpClientProvider.overrideWithValue(client),
            currentUserProvider.overrideWith((ref) async => testUser()),
          ],
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('confirmation annulée : aucun appel', (tester) async {
      onBecomeCreator = (_) async => jsonResponse(userJson());
      await open(tester);

      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      expect(find.byType(GnConfirmSheet), findsOneWidget);
      expect(find.text('Devenir créateur ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(GnConfirmSheet), findsNothing);
      expect(calls, isNot(contains('POST $_becomeCreator')));
    });

    testWidgets('fermer la feuille sans choisir : aucun appel', (tester) async {
      onBecomeCreator = (_) async => jsonResponse(userJson());
      await open(tester);

      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      expect(find.byType(GnConfirmSheet), findsNothing);
      expect(calls, isNot(contains('POST $_becomeCreator')));
    });

    testWidgets('confirmée : un seul POST puis toast de bienvenue', (
      tester,
    ) async {
      onBecomeCreator = (_) async => jsonResponse(userJson(role: 'creator'));
      await open(tester);

      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      await tester.tap(_confirmButton);
      await tester.pump();
      await tester.pump();

      expect(calls.where((c) => c == 'POST $_becomeCreator'), hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      // Pas de chargement inutile du tableau de bord pour un spectateur.
      expect(calls.where((c) => c.contains('analytics')), isEmpty);
      expect(
        find.text('Vous êtes créateur. Publiez votre première vidéo !'),
        findsOneWidget,
      );
      expect(find.byType(GnBanner), findsNothing);

      // Laisse le toast se retirer (plus de minuterie en attente).
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('erreur du serveur : affichée dans un bandeau', (tester) async {
      onBecomeCreator = (_) async =>
          jsonResponse({'detail': 'Impossible de changer de rôle'}, 400);
      await open(tester);

      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();

      expect(find.byType(GnBanner), findsOneWidget);
      expect(find.text('Activation impossible'), findsOneWidget);
      expect(find.text('Impossible de changer de rôle'), findsOneWidget);
      expect(
        find.text('Vous êtes créateur. Publiez votre première vidéo !'),
        findsNothing,
      );
      // L'utilisateur peut réessayer.
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('panne réseau : message en français, jamais l\'exception', (
      tester,
    ) async {
      onBecomeCreator = (_) async => throw const SocketException('offline');
      await open(tester);

      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();

      expect(find.byType(GnBanner), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('ClientException'), findsNothing);
    });

    testWidgets('« Réglages » ouvre /settings', (tester) async {
      onBecomeCreator = (_) async => jsonResponse(userJson());
      await open(tester);

      await tester.tap(find.bySemanticsLabel('Réglages'));
      await tester.pumpAndSettle();

      expect(find.text('page /settings'), findsOneWidget);
    }, semanticsEnabled: true);
  });

  group('avec le vrai routeur', () {
    var role = 'viewer';
    late List<String> calls;

    MockClient api() => MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      switch (request.url.path) {
        case '/api/v1/auth/refresh-token':
          return jsonResponse({
            'access_token': 'a2',
            'refresh_token': 'r2',
            'token_type': 'bearer',
          });
        case '/api/v1/users/me':
          return jsonResponse(userJson(role: role));
        case _becomeCreator:
          role = 'creator';
          return jsonResponse(userJson(role: role));
        case '/api/v1/auth/logout':
          return jsonResponse({'message': 'ok'});
      }
      return jsonResponse({'detail': 'Not Found'}, 404);
    });

    Future<ProviderContainer> boot(WidgetTester tester) async {
      role = 'viewer';
      calls = [];
      usePhoneScreen(tester, height: 1000);
      final container = ProviderContainer(
        overrides: [httpClientProvider.overrideWithValue(api())],
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
      return container;
    }

    testWidgets(
      'invalider le compte suffit : le routeur envoie le nouveau créateur '
      'sur l\'accueil',
      (tester) async {
        final container = await boot(tester);
        expect(container.read(routerProvider).location, '/become-creator');

        await tester.tap(find.text('Devenir créateur'));
        await tester.pumpAndSettle();
        await tester.tap(_confirmButton);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(calls, contains('POST $_becomeCreator'));
        expect(container.read(routerProvider).location, '/home');
        expect(
          find.text('Vous êtes créateur. Publiez votre première vidéo !'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets('un spectateur peut se déconnecter depuis cet écran', (
      tester,
    ) async {
      final container = await boot(tester);

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(GnConfirmSheet),
          matching: find.text('Se déconnecter'),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(calls, contains('POST /api/v1/auth/logout'));
      expect(container.read(routerProvider).location, '/login');
    });
  });
}
