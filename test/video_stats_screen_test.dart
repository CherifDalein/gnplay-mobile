import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/api_test_support.dart';
import 'videos_support.dart';

VideosApi twoVideos() {
  final api = VideosApi(
    videos: [
      videoJson('v1', 'Marché Madina'),
      videoJson('v2', 'Éclat de Kaloum', published: false),
      videoJson('v3', 'Clip raté', status: 'failed', duration: 0),
    ],
  );
  api.analytics['v1'] = analyticsJson('v1');
  api.analytics['v2'] = analyticsJson(
    'v2',
    views: 77,
    unique: 50,
    completed: 20,
    rate: 0.25,
    likes: 3,
    purchases: 2,
    revenue: 9000,
  );
  return api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  Future<ValueNotifier<GoRouter?>> open(
    WidgetTester tester,
    VideosApi api, {
    String phone = '+224621458807',
    String id = 'v1',
  }) async {
    final router = ValueNotifier<GoRouter?>(null);
    usePhoneScreen(tester);
    await tester.pumpWidget(
      videosApp(
        api,
        user: testUser(phone: phone),
        initialLocation: '/videos/$id/stats',
        routerOut: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('affichage', () {
    testWidgets('anneau, tableau et note, en GNF', (tester) async {
      await open(tester, twoVideos());

      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      for (final label in const [
        'Vues totales',
        'Spectateurs uniques',
        'Vues complétées',
        'Likes',
        'Nombre d’achats',
        'Revenu net (part créateur)',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('1 200'), findsOneWidget);
      expect(find.text('800'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('150 000 GNF'), findsOneWidget);
      expect(
        find.textContaining(
          'Les vues comptent les lectures de vos spectateurs',
        ),
        findsOneWidget,
      );
    });

    testWidgets('devise XOF pour un compte +221', (tester) async {
      await open(tester, twoVideos(), phone: '+221771234567');

      expect(find.text('150 000 XOF'), findsOneWidget);
      expect(find.textContaining('GNF'), findsNothing);
    });

    testWidgets('taux de complétion reçu en pourcentage ou en fraction', (
      tester,
    ) async {
      final api = twoVideos();
      api.analytics['v1'] = analyticsJson('v1', rate: 72);
      await open(tester, api);

      expect(find.text('72%'), findsOneWidget);
    });

    testWidgets('aucune activité : note explicative, zéros affichés', (
      tester,
    ) async {
      final api = twoVideos();
      api.analytics['v1'] = analyticsJson(
        'v1',
        views: 0,
        unique: 0,
        completed: 0,
        rate: 0,
        likes: 0,
        purchases: 0,
        revenue: 0,
      );
      await open(tester, api);

      expect(find.textContaining('Pas encore de statistiques'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 GNF'), findsOneWidget);
    });
  });

  group('changer de vidéo', () {
    testWidgets('la feuille liste les vidéos et affiche celle choisie', (
      tester,
    ) async {
      final api = twoVideos();
      await open(tester, api);
      expect(find.text('Changer'), findsOneWidget);

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      expect(find.text('Choisir une vidéo'), findsOneWidget);
      expect(find.text('Éclat de Kaloum'), findsOneWidget);
      expect(find.text('Clip raté'), findsOneWidget);

      await tester.tap(find.text('Éclat de Kaloum'));
      await tester.pumpAndSettle();

      expect(find.text('Choisir une vidéo'), findsNothing);
      expect(api.count('GET /api/v1/videos/v2/analytics'), 1);
      expect(find.text('Éclat de Kaloum'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('77'), findsOneWidget);
      expect(find.text('9 000 GNF'), findsOneWidget);
      // Toujours sur la même page : aucun retour par la liste.
      expect(find.text('Mon contenu'), findsNothing);
    });

    testWidgets('choisir la vidéo déjà affichée ne recharge rien', (
      tester,
    ) async {
      final api = twoVideos();
      await open(tester, api);
      final before = api.count('GET /api/v1/videos/v1/analytics');

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Marché Madina'),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.count('GET /api/v1/videos/v1/analytics'), before);
    });

    testWidgets('une seule vidéo : pas de « Changer »', (tester) async {
      final api = VideosApi(videos: [videoJson('v1', 'Marché Madina')]);
      await open(tester, api);

      expect(find.text('Changer'), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
    });
  });

  group('états', () {
    testWidgets('chargement des statistiques puis données', (tester) async {
      final api = twoVideos();
      final gate = Completer<void>();
      api.overrides['GET /api/v1/videos/v1/analytics'] = (_) async {
        await gate.future;
        return jsonResponse(analyticsJson('v1'));
      };
      usePhoneScreen(tester);
      await tester.pumpWidget(
        videosApp(api, initialLocation: '/videos/v1/stats'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GnLoadingView), findsOneWidget);
      expect(find.text('Marché Madina'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('68%'), findsOneWidget);
    });

    testWidgets('erreur des statistiques : message et « Réessayer »', (
      tester,
    ) async {
      final api = twoVideos();
      var fail = true;
      api.overrides['GET /api/v1/videos/v1/analytics'] = (_) async {
        if (fail) return jsonResponse({'detail': 'Service indisponible'}, 503);
        return jsonResponse(analyticsJson('v1'));
      };
      await open(tester, api);

      expect(find.byType(GnErrorView), findsOneWidget);
      expect(find.text('Service indisponible'), findsOneWidget);
      // Le sélecteur reste utilisable pour changer de vidéo.
      expect(find.text('Changer'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byType(GnErrorView), findsNothing);
      expect(find.text('68%'), findsOneWidget);
    });

    testWidgets('liste des vidéos en erreur : message et « Réessayer »', (
      tester,
    ) async {
      final api = twoVideos()..failList = 1;
      await open(tester, api);

      expect(find.byType(GnErrorView), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('68%'), findsOneWidget);
    });

    testWidgets('vidéo supprimée entre-temps', (tester) async {
      await open(tester, twoVideos(), id: 'disparue');

      expect(find.text('Cette vidéo n’existe plus'), findsOneWidget);
      await tester.tap(find.text('Voir mes vidéos'));
      await tester.pumpAndSettle();
      expect(find.text('Mon contenu'), findsOneWidget);
    });

    testWidgets('aucune vidéo : invite à publier', (tester) async {
      await open(tester, VideosApi(videos: []));

      expect(find.text('Aucune vidéo pour le moment'), findsOneWidget);
      await tester.tap(find.text('Publier une vidéo'));
      await tester.pumpAndSettle();
      expect(find.text('page /publish'), findsOneWidget);
    });

    testWidgets('tirer pour actualiser garde les chiffres affichés', (
      tester,
    ) async {
      final api = twoVideos();
      await open(tester, api);

      final gate = Completer<void>();
      api.overrides['GET /api/v1/videos/v1/analytics'] = (_) async {
        await gate.future;
        return jsonResponse(analyticsJson('v1', views: 5000));
      };
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('1 200'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('5 000'), findsOneWidget);
    });

    testWidgets('échec d\'une actualisation : chiffres gardés et bandeau', (
      tester,
    ) async {
      final api = twoVideos();
      await open(tester, api);
      api.overrides['GET /api/v1/videos/v1/analytics'] = (_) async =>
          jsonResponse({'detail': 'Service indisponible'}, 503);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('1 200'), findsOneWidget);
      expect(find.text('Actualisation impossible'), findsOneWidget);
    });

    testWidgets('le bouton retour revient à l\'écran précédent', (
      tester,
    ) async {
      final router = await open(tester, twoVideos());
      expect(router.value!.canPop(), isTrue);

      await tester.tap(find.byType(GnBackButton));
      await tester.pumpAndSettle();
      // On retrouve le détail de la vidéo, d'où l'on venait.
      expect(find.text('Statistiques'), findsNothing);
      expect(find.text('Supprimer la vidéo'), findsOneWidget);
    });

    testWidgets('360 px, police agrandie : aucun débordement', (tester) async {
      final api = twoVideos();
      api.analytics['v1'] = analyticsJson(
        'v1',
        views: 987654321,
        revenue: 987654321,
      );
      await open(tester, api);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
