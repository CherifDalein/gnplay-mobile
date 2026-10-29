import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/creator/presentation/providers/creator_content_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:gnplay/features/videos/presentation/widgets/video_edit_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/api_test_support.dart';
import 'videos_support.dart';

const _previewUrl = 'https://cdn.test/previews/v1.mp4';

VideosApi readyApi({String? preview, Map<String, Object?>? extra}) {
  final api = VideosApi(
    videos: [
      videoJson(
        'v1',
        'Marché Madina',
        description: 'Une promenade au marché',
        duration: 1448,
        preview: preview,
      ),
    ],
  );
  api.analytics['v1'] = analyticsJson('v1');
  return api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  Future<ValueNotifier<GoRouter?>> openDetail(
    WidgetTester tester,
    VideosApi api, {
    FakePlayers? players,
    String phone = '+224621458807',
    Duration previewTimeout = const Duration(minutes: 2),
    String id = 'v1',
    bool settle = true,
  }) async {
    final router = ValueNotifier<GoRouter?>(null);
    usePhoneScreen(tester);
    await tester.pumpWidget(
      videosApp(
        api,
        user: testUser(phone: phone),
        players: players ?? FakePlayers(),
        initialLocation: '/videos/$id',
        previewTimeout: previewTimeout,
        routerOut: router,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    return router;
  }

  group('informations', () {
    testWidgets('titre, statut, prix, date avec année, durée et description', (
      tester,
    ) async {
      await openDetail(tester, readyApi());

      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('En ligne · 1 000 GNF · 24 min 08 s'), findsOneWidget);
      expect(find.textContaining('Publiée le '), findsOneWidget);
      expect(find.textContaining('juin 2026'), findsOneWidget);
      expect(find.text('Une promenade au marché'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
    });

    testWidgets('statistiques : six tuiles, complétion, devise du compte', (
      tester,
    ) async {
      await openDetail(tester, readyApi(), phone: '+221771234567');

      for (final label in const [
        'Vues',
        'Spectateurs uniques',
        'Vues complétées',
        'Likes',
        'Achats',
        'Revenu net (XOF)',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('1 200'), findsOneWidget);
      expect(find.text('150 000'), findsOneWidget);
      expect(find.text('Taux de complétion moyen'), findsOneWidget);
      expect(find.text('68 %'), findsOneWidget);
      expect(find.textContaining('GNF'), findsNothing);
    });

    testWidgets('vidéo masquée : « Ajoutée le » et état Masquée', (
      tester,
    ) async {
      final api = readyApi();
      api.video('v1')['is_published'] = false;
      await openDetail(tester, api);

      expect(find.textContaining('Masquée · 1 000 GNF'), findsOneWidget);
      expect(find.textContaining('Ajoutée le '), findsOneWidget);
      expect(find.textContaining('Publiée le'), findsNothing);
      expect(find.text('Non visible dans le catalogue public'), findsOneWidget);
    });

    testWidgets('vidéo inconnue : « n\'existe plus »', (tester) async {
      await openDetail(tester, VideosApi(videos: []));

      expect(find.text('Cette vidéo n’existe plus'), findsOneWidget);
      await tester.tap(find.text('Retour à mes vidéos'));
      await tester.pumpAndSettle();
      expect(find.text('Mon contenu'), findsOneWidget);
    });

    testWidgets('erreur de chargement puis « Réessayer »', (tester) async {
      final api = readyApi()..failList = 1;
      await openDetail(tester, api);

      expect(find.byType(GnErrorView), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Marché Madina'), findsOneWidget);
    });

    testWidgets('statistiques en erreur : message et nouvelle tentative', (
      tester,
    ) async {
      final api = readyApi();
      var fail = true;
      api.overrides['GET /api/v1/videos/v1/analytics'] = (_) async {
        if (fail) return jsonResponse({'detail': 'Service indisponible'}, 503);
        return jsonResponse(analyticsJson('v1'));
      };
      await openDetail(tester, api);

      expect(find.text('Statistiques indisponibles'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Spectateurs uniques'), findsOneWidget);
    });

    testWidgets('tirer pour actualiser garde le contenu', (tester) async {
      final api = readyApi();
      await openDetail(tester, api);

      api.listGate = Completer<void>();
      api.video('v1')['title'] = 'Marché Madina (v2)';
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('Spectateurs uniques'), findsOneWidget);

      api.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Marché Madina (v2)'), findsOneWidget);
    });

    testWidgets('« Voir les statistiques détaillées » pousse la page stats', (
      tester,
    ) async {
      final router = await openDetail(tester, readyApi());

      await tester.scrollUntilVisible(
        find.text('Voir les statistiques détaillées'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Voir les statistiques détaillées'));
      await tester.pumpAndSettle();

      expect(find.text('Statistiques'), findsOneWidget);
      expect(router.value!.canPop(), isTrue);
    });
  });

  testWidgets('« Voir la vidéo complète » ouvre le lecteur et le ferme', (
    tester,
  ) async {
    final players = FakePlayers();
    final api = readyApi(preview: _previewUrl);
    api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async =>
        jsonResponse({
          'token': 'tok',
          'expires_at': '2099-01-01T00:00:00Z',
          'watermark': 'Mariama • •••8807',
        });
    await openDetail(tester, api, players: players);
    final preview = players.created.single;
    expect(preview.value.isPlaying, isTrue);

    await tester.scrollUntilVisible(
      find.text('Voir la vidéo complète'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Voir la vidéo complète'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Le lecteur complet est ouvert ; l'aperçu dessous est mis en pause.
    expect(players.created, hasLength(2));
    expect(players.urls.last.path, '/api/v1/stream/v1/master.m3u8');
    expect(preview.value.isPlaying, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('player-watermark')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Fermer').first);
    await tester.pumpAndSettle();
    expect(players.created[1].disposed, isTrue);
    expect(preview.value.isPlaying, isTrue);
  });

  group('aperçu', () {
    testWidgets(
      'sans aperçu : libellé clair, ni bouton de lecture ni « Aperçu 15 s »',
      (tester) async {
        final players = FakePlayers();
        await openDetail(tester, readyApi(), players: players);

        expect(find.text('Aperçu pas encore disponible'), findsOneWidget);
        expect(find.text('Aperçu 15 s'), findsNothing);
        expect(find.byKey(const Key('preview-toggle')), findsNothing);
        expect(find.byKey(const Key('preview-mute')), findsNothing);
        expect(players.created, isEmpty);
        // On peut quand même voir la vidéo complète.
        expect(find.text('Voir la vidéo complète'), findsOneWidget);
      },
    );

    testWidgets('avec aperçu : lecture muette en boucle et bouton son', (
      tester,
    ) async {
      final players = FakePlayers();
      await openDetail(
        tester,
        readyApi(preview: _previewUrl),
        players: players,
      );

      expect(find.text('Aperçu 15 s'), findsOneWidget);
      expect(find.text('Aperçu pas encore disponible'), findsNothing);
      expect(find.text('Générer l’aperçu'), findsNothing);
      expect(players.urls.single.toString(), _previewUrl);
      final player = players.last!;
      expect(player.looping, isTrue);
      expect(player.volumeValue, 0);
      expect(player.value.isPlaying, isTrue);

      await tester.tap(find.byKey(const Key('preview-mute')));
      await tester.pump();
      expect(player.volumeValue, 1);

      // Toucher l'aperçu le met en pause, un second toucher le relance.
      await tester.tap(find.byKey(const Key('preview-toggle')));
      await tester.pump();
      expect(player.value.isPlaying, isFalse);
      await tester.tap(find.byKey(const Key('preview-toggle')));
      await tester.pump();
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('le lecteur d\'aperçu survit à un rafraîchissement', (
      tester,
    ) async {
      final players = FakePlayers();
      final api = readyApi(preview: _previewUrl);
      await openDetail(tester, api, players: players);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomScrollView)),
      );
      container.invalidate(creatorVideosProvider);
      await tester.pumpAndSettle();

      expect(players.created, hasLength(1));
      expect(players.last!.disposed, isFalse);
    });

    testWidgets('erreur de lecture : message et « Réessayer »', (tester) async {
      final players = FakePlayers()
        ..build = () => FakeVideoController(failInitialize: true);
      await openDetail(
        tester,
        readyApi(preview: _previewUrl),
        players: players,
      );

      expect(find.text('Impossible de lire l’aperçu.'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      players.build = () => FakeVideoController();
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Impossible de lire l’aperçu.'), findsNothing);
      expect(players.created, hasLength(2));
      expect(players.created.first.disposed, isTrue);
      expect(players.last!.value.isPlaying, isTrue);
    });

    testWidgets('quitter l\'écran libère le contrôleur', (tester) async {
      final players = FakePlayers();
      final router = await openDetail(
        tester,
        readyApi(preview: _previewUrl),
        players: players,
      );

      router.value!.go('/publish');
      await tester.pumpAndSettle();
      expect(players.last!.disposed, isTrue);
    });

    testWidgets('quitter pendant l\'initialisation ne plante pas', (
      tester,
    ) async {
      final gate = Completer<void>();
      final players = FakePlayers()
        ..build = () => FakeVideoController()..initializeGate = gate;
      final router = await openDetail(
        tester,
        readyApi(preview: _previewUrl),
        players: players,
        settle: false,
      );
      expect(players.created, hasLength(1));

      router.value!.go('/publish');
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();

      expect(players.last!.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('génération de l\'aperçu', () {
    testWidgets('bouton réservé aux vidéos prêtes sans aperçu', (tester) async {
      await openDetail(tester, readyApi());
      expect(find.text('Générer l’aperçu'), findsOneWidget);
    });

    testWidgets('pas de bouton pour une vidéo en traitement ou en échec', (
      tester,
    ) async {
      for (final status in ['processing', 'failed', 'queued']) {
        final api = VideosApi(
          videos: [videoJson('v1', 'Clip', status: status, duration: 0)],
        );
        await openDetail(tester, api);
        expect(find.text('Générer l’aperçu'), findsNothing, reason: status);
        expect(
          find.text('Aperçu pas encore disponible'),
          findsOneWidget,
          reason: status,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('202 puis l\'aperçu apparaît au sondage suivant', (
      tester,
    ) async {
      final players = FakePlayers();
      final api = readyApi();
      api.overrides['POST /api/v1/videos/v1/preview'] = (_) async =>
          jsonResponse({'status': 'generating', 'preview_url': null}, 202);
      await openDetail(tester, api, players: players);
      final before = api.listCalls;

      await tester.tap(find.text('Générer l’aperçu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.count('POST /api/v1/videos/v1/preview'), 1);
      expect(find.text('Génération de l’aperçu…'), findsOneWidget);
      expect(find.text('Générer l’aperçu'), findsNothing);
      expect(players.created, isEmpty);

      // Le premier sondage ne voit rien de nouveau.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(api.listCalls, before + 1);
      expect(find.text('Génération de l’aperçu…'), findsOneWidget);

      // Le worker a fini : le sondage suivant affiche l'aperçu, muet.
      api.video('v1')['preview_url'] = _previewUrl;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Aperçu 15 s'), findsOneWidget);
      expect(find.text('Génération de l’aperçu…'), findsNothing);
      expect(players.urls.single.toString(), _previewUrl);
      expect(players.last!.volumeValue, 0);
      expect(players.last!.value.isPlaying, isTrue);

      // Le sondage s'arrête dès que l'aperçu est là.
      final after = api.listCalls;
      await tester.pump(const Duration(seconds: 30));
      expect(api.listCalls, after);
      // Un seul appel de génération.
      expect(api.count('POST /api/v1/videos/v1/preview'), 1);
    });

    testWidgets('200 : l\'aperçu s\'affiche directement', (tester) async {
      final players = FakePlayers();
      final api = readyApi();
      api.overrides['POST /api/v1/videos/v1/preview'] = (_) async =>
          jsonResponse({'status': 'ready', 'preview_url': _previewUrl});
      await openDetail(tester, api, players: players);

      await tester.tap(find.text('Générer l’aperçu'));
      await tester.pumpAndSettle();

      expect(find.text('Aperçu 15 s'), findsOneWidget);
      expect(players.urls.first.toString(), _previewUrl);
      expect(find.text('Génération de l’aperçu…'), findsNothing);
    });

    testWidgets('409 : message du serveur affiché, nouvel essai possible', (
      tester,
    ) async {
      final api = readyApi();
      api.overrides['POST /api/v1/videos/v1/preview'] = (_) async =>
          jsonResponse({
            'detail':
                "L'aperçu ne peut être créé qu'une fois le traitement de la "
                'vidéo terminé.',
          }, 409);
      await openDetail(tester, api);

      await tester.tap(find.text('Générer l’aperçu'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "L'aperçu ne peut être créé qu'une fois le traitement de la vidéo "
          'terminé.',
        ),
        findsOneWidget,
      );
      expect(find.text('Génération de l’aperçu…'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('délai dépassé : message et bouton de nouvel essai', (
      tester,
    ) async {
      final api = readyApi();
      api.overrides['POST /api/v1/videos/v1/preview'] = (_) async =>
          jsonResponse({'status': 'generating', 'preview_url': null}, 202);
      await openDetail(
        tester,
        api,
        previewTimeout: const Duration(seconds: 20),
      );

      await tester.tap(find.text('Générer l’aperçu'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();

      expect(
        find.text('L’aperçu n’a pas pu être créé. Réessayez plus tard.'),
        findsOneWidget,
      );
      expect(find.text('Génération de l’aperçu…'), findsNothing);
      // Le sondage est arrêté.
      final after = api.listCalls;
      await tester.pump(const Duration(seconds: 30));
      expect(api.listCalls, after);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(api.count('POST /api/v1/videos/v1/preview'), 2);
      expect(find.text('Génération de l’aperçu…'), findsOneWidget);
      // Laisse le délai de la seconde tentative s'écouler.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
    });
  });

  group('traitement', () {
    testWidgets('en traitement : bandeau et relecture automatique', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [
          videoJson('v1', 'Mix en cours', status: 'processing', duration: 0),
        ],
      );
      await openDetail(tester, api);

      expect(find.text('Traitement en cours'), findsOneWidget);
      expect(find.textContaining('se met à jour toute seule'), findsOneWidget);
      // Pas de statistiques tant que la vidéo n'est pas prête.
      expect(find.text('Spectateurs uniques'), findsNothing);
      final start = api.listCalls;

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(api.listCalls, start + 1);

      api.video('v1')
        ..['status'] = 'ready'
        ..['duration'] = 90;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Traitement en cours'), findsNothing);
      expect(find.text('Spectateurs uniques'), findsOneWidget);

      final after = api.listCalls;
      await tester.pump(const Duration(seconds: 30));
      expect(api.listCalls, after, reason: 'sondage arrêté');
    });

    testWidgets('« Voir la vidéo complète » désactivé pendant le traitement', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [videoJson('v1', 'Mix', status: 'processing', duration: 0)],
      );
      await openDetail(tester, api);

      final button = tester.widget<GnButton>(
        find.widgetWithText(GnButton, 'Voir la vidéo complète'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('échec : bandeau, relance réussie et toast', (tester) async {
      final api = VideosApi(
        videos: [videoJson('v1', 'Clip raté', status: 'failed', duration: 0)],
      );
      await openDetail(tester, api);

      expect(find.text('Le traitement de la vidéo a échoué'), findsOneWidget);
      final before = api.listCalls;
      await tester.tap(find.text('Relancer le traitement'));
      await tester.pumpAndSettle();

      expect(api.count('POST /api/v1/internal/videos/v1/retry-transcode'), 1);
      expect(api.listCalls, before + 1);
      expect(find.textContaining('Traitement relancé'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('échec : 409 et 503 affichés en toast', (tester) async {
      final api = VideosApi(
        videos: [videoJson('v1', 'Clip raté', status: 'failed', duration: 0)],
      );
      api.overrides['POST /api/v1/internal/videos/v1/retry-transcode'] =
          (_) async => jsonResponse({
            'detail': 'Video processing queue is not available',
          }, 503);
      await openDetail(tester, api);

      await tester.tap(find.text('Relancer le traitement'));
      await tester.pumpAndSettle();
      expect(
        find.text('Le traitement des vidéos est momentanément indisponible.'),
        findsOneWidget,
      );
      await settleToast(tester);
    });
  });

  group('publication', () {
    testWidgets('masquer puis publier', (tester) async {
      final api = readyApi();
      await openDetail(tester, api);
      expect(find.text('Visible dans le catalogue public'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(GnSwitch),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(GnSwitch));
      await tester.pumpAndSettle();
      expect(api.patchBodies.last, {'is_published': false});
      expect(find.text('Masquée'), findsWidgets);
      expect(find.text('Vidéo masquée.'), findsOneWidget);
      await settleToast(tester);

      await tester.tap(find.byType(GnSwitch));
      await tester.pumpAndSettle();
      expect(api.patchBodies.last, {'is_published': true});
      await settleToast(tester);
    });

    testWidgets('interrupteur désactivé tant que la vidéo n\'est pas prête', (
      tester,
    ) async {
      final api = VideosApi(
        videos: [videoJson('v1', 'Clip raté', status: 'failed', duration: 0)],
      );
      await openDetail(tester, api);

      await tester.scrollUntilVisible(
        find.byType(GnSwitch),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final toggle = tester.widget<GnSwitch>(find.byType(GnSwitch));
      expect(toggle.onChanged, isNull);
      expect(find.text('Publication indisponible'), findsOneWidget);
    });
  });

  group('édition', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
    }

    testWidgets('champs préremplis, pas de champ miniature', (tester) async {
      await openDetail(tester, readyApi());
      await openSheet(tester);

      expect(find.text('Modifier la vidéo'), findsOneWidget);
      expect(find.text('Marché Madina'), findsWidgets);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('Prix (GNF)'), findsOneWidget);
      expect(find.textContaining('Miniature'), findsNothing);
    });

    testWidgets('validation locale : titre vide, aucun appel', (tester) async {
      final api = readyApi();
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Le titre est obligatoire.'), findsOneWidget);
      expect(api.patchBodies, isEmpty);
      expect(find.byType(VideoEditSheet), findsOneWidget);
    });

    testWidgets('prix vide : demande de choisir un prix ou « Gratuite »', (
      tester,
    ) async {
      final api = readyApi();
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Indiquez un prix en GNF ou choisissez « Gratuite ».'),
        findsOneWidget,
      );
      expect(api.patchBodies, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(2), '0');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('supérieur à 0'), findsOneWidget);
      expect(api.patchBodies, isEmpty);
    });

    testWidgets('gratuit explicite : prix envoyé à 0', (tester) async {
      final api = readyApi();
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(VideoEditSheet),
          matching: find.byType(GnSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prix (GNF)'), findsNothing);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.patchBodies, [
        {'price': 0},
      ]);
      expect(find.text('Gratuite · 24 min 08 s'), findsNothing);
      expect(find.textContaining('Gratuite'), findsWidgets);
      await settleToast(tester);
    });

    testWidgets('succès : seuls les champs modifiés sont envoyés', (
      tester,
    ) async {
      final api = readyApi();
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        ' Nouveau titre ',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '2500');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.patchBodies, [
        {'title': 'Nouveau titre', 'price': 2500},
      ]);
      expect(find.byType(VideoEditSheet), findsNothing);
      expect(find.text('Modifications enregistrées.'), findsOneWidget);
      expect(find.text('Nouveau titre'), findsOneWidget);
      expect(find.textContaining('2 500 GNF'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('rien de modifié : la feuille se ferme sans appel', (
      tester,
    ) async {
      final api = readyApi();
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.patchBodies, isEmpty);
      expect(find.byType(VideoEditSheet), findsNothing);
    });

    testWidgets('erreur du serveur affichée DANS la feuille', (tester) async {
      final api = readyApi();
      api.overrides['PATCH /api/v1/videos/v1'] = (_) async => jsonResponse({
        'detail': 'Vous n’avez pas les permissions nécessaires.',
      }, 403);
      await openDetail(tester, api);
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Autre titre');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.byType(VideoEditSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VideoEditSheet),
          matching: find.text('Vous n’avez pas les permissions nécessaires.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Enregistrement impossible'), findsOneWidget);
      // La feuille reste utilisable : on peut corriger et réessayer.
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('clavier ouvert sur petit écran : aucun débordement', (
      tester,
    ) async {
      await openDetail(tester, readyApi());
      tester.view.physicalSize = const Size(320, 560);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField).at(1), 'x\ny\nz\nw');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });

  group('suppression', () {
    Future<ValueNotifier<GoRouter?>> openFromList(
      WidgetTester tester,
      VideosApi api,
    ) async {
      final router = ValueNotifier<GoRouter?>(null);
      usePhoneScreen(tester);
      await tester.pumpWidget(
        videosApp(api, players: FakePlayers(), routerOut: router),
      );
      await tester.pumpAndSettle();
      router.value!.push('/videos/v1');
      await tester.pumpAndSettle();
      return router;
    }

    Future<void> askDelete(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Supprimer la vidéo'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Supprimer la vidéo'));
      await tester.pumpAndSettle();
    }

    testWidgets('la feuille explique ce qui arrive aux acheteurs', (
      tester,
    ) async {
      await openFromList(tester, readyApi());
      await askDelete(tester);

      expect(find.text('Supprimer cette vidéo ?'), findsOneWidget);
      expect(find.textContaining('déjà achetée'), findsOneWidget);
      expect(find.textContaining('supprimée définitivement'), findsOneWidget);
    });

    testWidgets('annulée : aucun appel', (tester) async {
      final api = readyApi();
      await openFromList(tester, api);
      await askDelete(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.count('DELETE /api/v1/videos/v1'), 0);
      expect(find.text('Supprimer cette vidéo ?'), findsNothing);
      expect(find.text('Supprimer la vidéo'), findsOneWidget);
    });

    testWidgets('confirmée : DELETE, retour à la liste et toast', (
      tester,
    ) async {
      final api = readyApi();
      await openFromList(tester, api);
      await askDelete(tester);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(api.count('DELETE /api/v1/videos/v1'), 1);
      // Retour sur la liste, qui ne contient plus la vidéo.
      expect(find.text('Mon contenu'), findsOneWidget);
      expect(find.text('Marché Madina'), findsNothing);
      expect(find.text('Vidéo supprimée.'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('échec du serveur : on reste sur le détail avec un toast', (
      tester,
    ) async {
      final api = readyApi();
      api.overrides['DELETE /api/v1/videos/v1'] = (_) async =>
          jsonResponse({'detail': 'Failed to delete video: boom'}, 500);
      await openFromList(tester, api);
      await askDelete(tester);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer la vidéo'), findsOneWidget);
      expect(
        find.text(
          'Le serveur a rencontré un problème. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );
      await settleToast(tester);
    });
  });
}
