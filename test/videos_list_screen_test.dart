import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/creator/presentation/providers/creator_content_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:gnplay/features/videos/presentation/widgets/video_card.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/api_test_support.dart';
import 'videos_support.dart';

VideosApi mixedApi() => VideosApi(
  videos: [
    videoJson('v1', 'Marché Madina', views: 1240, revenue: 8500),
    videoJson(
      'v2',
      'Éclat de Kaloum',
      published: false,
      price: 0,
      description: 'Une promenade nocturne',
    ),
    videoJson('v3', 'Mix en cours', status: 'processing', duration: 0),
    videoJson('v4', 'Clip raté', status: 'failed', duration: 0),
  ],
);

VideosApi failedApi() => VideosApi(
  videos: [videoJson('v4', 'Clip raté', status: 'failed', duration: 0)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  Future<VideosApi> open(
    WidgetTester tester, {
    VideosApi? api,
    String phone = '+224621458807',
    ValueNotifier<GoRouter?>? router,
    Widget Function(Widget list)? wrapList,
    Widget Function(String id)? detailBuilder,
    Duration minRefreshInterval = Duration.zero,
  }) async {
    final fake = api ?? mixedApi();
    usePhoneScreen(tester);
    await tester.pumpWidget(
      videosApp(
        fake,
        user: testUser(phone: phone),
        routerOut: router,
        wrapList: wrapList,
        minRefreshInterval: minRefreshInterval,
        detailBuilder:
            detailBuilder ?? (id) => Scaffold(body: Text('détail $id')),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  group('cartes', () {
    testWidgets('titre, statut, prix, vues, revenu et durée', (tester) async {
      await open(tester);

      expect(find.text('Mon contenu'), findsOneWidget);
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('En ligne'), findsOneWidget);
      expect(find.text('1 000 GNF · 1 240 vues · 8 500 GNF'), findsOneWidget);
      // Durée de 120 s en badge sur la miniature.
      expect(find.text('2:00'), findsWidgets);
      expect(find.text('Gratuite · 90 vues · 4 000 GNF'), findsOneWidget);
      expect(find.text('Masquée'), findsOneWidget);
      expect(find.text('Masquée du catalogue'), findsOneWidget);
      expect(find.text('Visible dans le catalogue'), findsOneWidget);
    });

    testWidgets('durée inconnue : ni « 0 min » ni badge', (tester) async {
      final api = VideosApi(
        videos: [
          videoJson('v3', 'Mix en cours', status: 'processing', duration: 0),
        ],
      );
      await open(tester, api: api);

      expect(find.text('Mix en cours'), findsOneWidget);
      expect(find.text('En traitement'), findsOneWidget);
      expect(find.textContaining('0 min'), findsNothing);
      expect(find.text('0:00'), findsNothing);
      // Pas de statistiques pour une vidéo qui n'est pas en ligne.
      expect(find.text('1 000 GNF'), findsOneWidget);
      expect(find.textContaining('vue'), findsNothing);
    });

    testWidgets('devise XOF pour un numéro +221', (tester) async {
      await open(tester, phone: '+221771234567');

      expect(find.text('1 000 XOF · 1 240 vues · 8 500 XOF'), findsOneWidget);
      expect(find.textContaining('GNF'), findsNothing);
    });

    testWidgets('titre long et grands nombres : aucun débordement à 360 px', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [
          videoJson(
            'v1',
            'Un titre de vidéo vraiment très long qui devra passer à la '
                'ligne sans jamais déborder de la carte',
            views: 987654321,
            revenue: 987654321,
            price: 99999999,
          ),
        ],
      );
      await open(tester, api: api);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('liste paresseuse : seules les cartes visibles sont bâties', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [for (var i = 0; i < 80; i++) videoJson('v$i', 'Vidéo $i')],
      );
      await open(tester, api: api);

      expect(find.byType(VideoCard), findsWidgets);
      expect(find.byType(VideoCard).evaluate().length, lessThan(15));
      expect(find.text('80 vidéos'), findsOneWidget);
    });
  });

  group('filtres et recherche', () {
    testWidgets('puces avec compteurs, seulement celles qui servent', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Toutes (4)'), findsOneWidget);
      expect(find.text('En ligne (1)'), findsOneWidget);
      expect(find.text('Masquées (1)'), findsOneWidget);
      expect(find.text('En traitement (1)'), findsOneWidget);
      expect(find.text('Échecs (1)'), findsOneWidget);
      // Aucune vidéo bloquée ou à l'envoi incomplet : pas de puce inutile.
      expect(find.textContaining('Bloquées'), findsNothing);
      expect(find.textContaining('Envoi incomplet ('), findsNothing);
      expect(find.text('4 vidéos'), findsOneWidget);
    });

    testWidgets('une catégorie à la fois', (tester) async {
      await open(tester);

      await tester.tap(find.text('Masquées (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Éclat de Kaloum'), findsOneWidget);
      expect(find.text('Marché Madina'), findsNothing);
      expect(find.text('1 vidéo'), findsOneWidget);

      await tester.tap(find.text('Échecs (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Clip raté'), findsOneWidget);
      expect(find.text('Éclat de Kaloum'), findsNothing);

      await tester.tap(find.text('Toutes (4)'));
      await tester.pumpAndSettle();
      expect(find.text('4 vidéos'), findsOneWidget);
    });

    testWidgets('pas de puces quand il n\'y a qu\'une catégorie', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [videoJson('v1', 'Une'), videoJson('v2', 'Deux')],
      );
      await open(tester, api: api);

      expect(find.byType(GnChip), findsNothing);
      expect(find.text('2 vidéos'), findsOneWidget);
    });

    testWidgets('recherche sans casse ni accents, titre ou description', (
      tester,
    ) async {
      await open(tester);

      await tester.enterText(find.byType(TextField), 'eclat');
      await tester.pumpAndSettle();
      expect(find.text('Éclat de Kaloum'), findsOneWidget);
      expect(find.text('Marché Madina'), findsNothing);

      await tester.enterText(find.byType(TextField), 'NOCTURNE');
      await tester.pumpAndSettle();
      expect(find.text('Éclat de Kaloum'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);
      expect(find.text('0 vidéo'), findsOneWidget);

      await tester.tap(find.text('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('4 vidéos'), findsOneWidget);
    });

    testWidgets('la recherche s\'applique au filtre choisi', (tester) async {
      await open(tester);

      await tester.tap(find.text('En ligne (1)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kaloum');
      await tester.pumpAndSettle();

      expect(find.text('Éclat de Kaloum'), findsNothing);
      expect(find.text('Aucun résultat'), findsOneWidget);
    });
  });

  group('états', () {
    testWidgets('aucune vidéo : invite à publier', (tester) async {
      await open(tester, api: VideosApi(videos: []));

      expect(find.text('Publiez votre première vidéo'), findsOneWidget);
      await tester.tap(find.text('Publier une vidéo'));
      await tester.pumpAndSettle();
      expect(find.text('page /publish'), findsOneWidget);
    });

    testWidgets('« Nouvelle vidéo » mène à /publish', (tester) async {
      await open(tester);

      await tester.tap(find.text('Nouvelle vidéo'));
      await tester.pumpAndSettle();
      expect(find.text('page /publish'), findsOneWidget);
    });

    testWidgets('premier chargement puis erreur et « Réessayer »', (
      tester,
    ) async {
      final api = mixedApi()
        ..listGate = Completer<void>()
        ..failList = 1;
      usePhoneScreen(tester);
      await tester.pumpWidget(videosApp(api));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GnLoadingView), findsOneWidget);

      api.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GnErrorView), findsOneWidget);
      expect(find.text('Service indisponible'), findsOneWidget);
      expect(find.text('Marché Madina'), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byType(GnErrorView), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
    });

    testWidgets('toucher une carte pousse le détail et le retour revient', (
      tester,
    ) async {
      final router = ValueNotifier<GoRouter?>(null);
      await open(tester, router: router);

      await tester.tap(find.text('Marché Madina'));
      await tester.pumpAndSettle();

      expect(find.text('détail v1'), findsOneWidget);
      expect(router.value!.canPop(), isTrue);
      router.value!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Marché Madina'), findsOneWidget);
    });
  });

  group('rafraîchissement', () {
    testWidgets('tirer pour actualiser garde le contenu', (tester) async {
      final api = await open(tester);
      final before = api.listCalls;

      api.listGate = Completer<void>();
      api.videos = [videoJson('v9', 'Tout juste mise en ligne'), ...api.videos];
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(api.listCalls, before + 1);
      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('Tout juste mise en ligne'), findsNothing);

      api.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Tout juste mise en ligne'), findsOneWidget);
      expect(find.text('5 vidéos'), findsOneWidget);
    });

    testWidgets('actualisation automatique : fin trait, sans plein écran', (
      tester,
    ) async {
      final api = await open(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomScrollView)),
      );

      api.listGate = Completer<void>();
      container.invalidate(creatorVideosProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Marché Madina'), findsOneWidget);

      api.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('échec d\'une actualisation : liste gardée et bandeau', (
      tester,
    ) async {
      final api = await open(tester);
      api.failList = 1;

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('Actualisation impossible'), findsOneWidget);
      expect(find.byType(GnErrorView), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Actualisation impossible'), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
    });
  });

  group('sondage du traitement', () {
    testWidgets('actif tant qu\'une vidéo est en traitement, puis arrêté', (
      tester,
    ) async {
      final api = await open(tester);
      final start = api.listCalls;

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(api.listCalls, start + 1);

      // La vidéo est prête : le prochain tour le constate, puis plus rien.
      api.video('v3')
        ..['status'] = 'ready'
        ..['is_published'] = false
        ..['duration'] = 300;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(api.listCalls, start + 2);
      expect(find.text('Mix en cours'), findsOneWidget);
      expect(find.text('En traitement'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      expect(api.listCalls, start + 2);
    });

    testWidgets('aucun sondage sans vidéo en traitement', (tester) async {
      final api = await open(tester, api: VideosApi());
      final start = api.listCalls;

      await tester.pump(const Duration(seconds: 60));
      expect(api.listCalls, start);
    });

    testWidgets('arrêté quand l\'onglet est masqué, repris au retour', (
      tester,
    ) async {
      final visible = ValueNotifier<bool>(true);
      final api = await open(
        tester,
        wrapList: (list) => ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, active, _) => TickerMode(enabled: active, child: list),
        ),
      );
      final start = api.listCalls;

      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(api.listCalls, start, reason: 'onglet masqué : pas de sondage');

      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      // Retour sur l'onglet : une actualisation, sans effacer le contenu.
      expect(api.listCalls, start + 1);
      expect(find.text('Marché Madina'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(api.listCalls, start + 2, reason: 'sondage repris');
    });
  });

  group('relance du traitement', () {
    testWidgets('succès : appel, toast et liste rechargée', (tester) async {
      final api = await open(tester, api: failedApi());
      final before = api.listCalls;

      await tester.tap(find.text('Relancer le traitement'));
      await tester.pumpAndSettle();

      expect(api.count('POST /api/v1/internal/videos/v4/retry-transcode'), 1);
      expect(find.textContaining('Traitement relancé'), findsOneWidget);
      expect(api.listCalls, before + 1);
      await settleToast(tester);
    });

    testWidgets('état de chargement pendant l\'appel', (tester) async {
      final api = failedApi();
      final gate = Completer<void>();
      api.overrides['POST /api/v1/internal/videos/v4/retry-transcode'] =
          (_) async {
            await gate.future;
            return jsonResponse({'status': 'queued'});
          };
      await open(tester, api: api);

      await tester.tap(find.text('Relancer le traitement'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Le bouton passe en chargement : il ne se déclenche plus deux fois.
      expect(find.text('Relancer le traitement'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(api.count('POST /api/v1/internal/videos/v4/retry-transcode'), 1);
      await settleToast(tester);
    });

    testWidgets('409 : message du serveur et liste rechargée', (tester) async {
      final api = failedApi();
      api.overrides['POST /api/v1/internal/videos/v4/retry-transcode'] =
          (_) async => jsonResponse({
            'detail':
                'Seule une vidéo dont le traitement a échoué peut être '
                'relancée.',
          }, 409);
      await open(tester, api: api);
      final before = api.listCalls;

      await tester.tap(find.text('Relancer le traitement'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Seule une vidéo dont le traitement a échoué peut être relancée.',
        ),
        findsOneWidget,
      );
      expect(api.listCalls, before + 1);
      await settleToast(tester);
    });

    testWidgets('503 : message clair, la vidéo reste en échec', (tester) async {
      final api = failedApi();
      api.overrides['POST /api/v1/internal/videos/v4/retry-transcode'] =
          (_) async => jsonResponse({
            'detail': 'Video processing queue is not available',
          }, 503);
      await open(tester, api: api);

      await tester.tap(find.text('Relancer le traitement'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le traitement des vidéos est momentanément indisponible.'),
        findsOneWidget,
      );
      expect(find.text('Échec'), findsOneWidget);
      expect(find.text('Relancer le traitement'), findsOneWidget);
      await settleToast(tester);
    });
  });

  group('publication', () {
    testWidgets('masquer une vidéo en ligne', (tester) async {
      final api = await open(tester);

      await tester.tap(find.byType(GnSwitch).first);
      await tester.pumpAndSettle();

      expect(api.patchBodies, [
        {'is_published': false},
      ]);
      expect(find.text('Vidéo masquée.'), findsOneWidget);
      // La liste rechargée reflète le changement.
      expect(find.text('Masquées (2)'), findsOneWidget);
      expect(find.text('En ligne (1)'), findsNothing);
      await settleToast(tester);
    });

    testWidgets('publier une vidéo masquée', (tester) async {
      final api = await open(tester);

      await tester.tap(find.byType(GnSwitch).last);
      await tester.pumpAndSettle();

      expect(api.patchBodies, [
        {'is_published': true},
      ]);
      expect(find.text('Vidéo publiée dans le catalogue.'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('pas d\'interrupteur tant que la vidéo n\'est pas prête', (
      tester,
    ) async {
      await open(tester);

      // Quatre vidéos, dont deux seulement peuvent être publiées/masquées.
      expect(find.byType(GnSwitch), findsNWidgets(2));
    });

    testWidgets('échec du serveur : toast d\'erreur, état inchangé', (
      tester,
    ) async {
      final api = mixedApi();
      api.overrides['PATCH /api/v1/videos/v1'] = (_) async => jsonResponse({
        'detail': 'Failed to update video metadata: boom',
      }, 500);
      await open(tester, api: api);

      await tester.tap(find.byType(GnSwitch).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Le serveur a rencontré un problème. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );
      expect(find.text('En ligne (1)'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('toucher l\'interrupteur n\'ouvre pas le détail', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.byType(GnSwitch).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('détail'), findsNothing);
      await settleToast(tester);
    });
  });
}
