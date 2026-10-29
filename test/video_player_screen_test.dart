import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/videos/presentation/providers/video_player_factory_provider.dart';
import 'package:gnplay/features/videos/presentation/screens/full_video_player_screen.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'support/api_test_support.dart';
import 'videos_support.dart';

const _watermark = 'Mariama Diallo • •••8807';

http.Response _session(
  String token, {
  Duration validFor = const Duration(hours: 2),
}) => jsonResponse({
  'token': token,
  'expires_at': DateTime.now().add(validFor).toUtc().toIso8601String(),
  'watermark': _watermark,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  late VideosApi api;
  late FakePlayers players;
  var tokenCount = 0;

  Future<void> open(
    WidgetTester tester, {
    Duration validFor = const Duration(hours: 2),
    Duration renewMargin = const Duration(minutes: 1),
    Size size = const Size(360, 640),
  }) async {
    tokenCount = 0;
    api.overrides.putIfAbsent(
      'POST /api/v1/videos/v1/playback-session',
      () =>
          (_) async => _session('tok-${++tokenCount}', validFor: validFor),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(api.client),
          videoControllerFactoryProvider.overrideWithValue(players.factory),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: FullVideoPlayerScreen(
            videoId: 'v1',
            title: 'Marché Madina',
            renewMargin: renewMargin,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() {
    api = VideosApi();
    players = FakePlayers()
      ..build = () => FakeVideoController(length: const Duration(seconds: 60));
  });

  double controlsOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const Key('player-controls')))
      .opacity;

  group('lecture', () {
    testWidgets('session créée, flux HLS jeton compris, titre et filigrane', (
      tester,
    ) async {
      await open(tester);

      expect(api.count('POST /api/v1/videos/v1/playback-session'), 1);
      expect(players.urls.single.path, '/api/v1/stream/v1/master.m3u8');
      expect(players.urls.single.queryParameters['token'], 'tok-1');
      expect(players.last!.value.isPlaying, isTrue);
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.byKey(const Key('player-watermark')), findsOneWidget);
      expect(find.text(_watermark), findsOneWidget);
      expect(find.byKey(const Key('player-elapsed')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('player-total'))).data,
        '1:00',
      );
    });

    testWidgets('sans filigrane quand le serveur n\'en donne pas', (
      tester,
    ) async {
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async =>
          jsonResponse({'token': 'tok', 'expires_at': null, 'watermark': null});
      await open(tester);

      expect(find.byKey(const Key('player-watermark')), findsNothing);
      expect(players.created, hasLength(1));
    });

    testWidgets(
      'jamais de watch-progress : les vues du créateur ne gonflent pas',
      (tester) async {
        await open(tester);
        players.last!.emit(position: const Duration(seconds: 59));
        await tester.pump(const Duration(seconds: 10));

        expect(api.calls.where((c) => c.contains('watch-progress')), isEmpty);
      },
    );

    testWidgets('temps écoulé et barre de progression suivent la lecture', (
      tester,
    ) async {
      await open(tester);

      players.last!.emit(position: const Duration(seconds: 30));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('player-elapsed'))).data,
        '0:30',
      );
      final slider = tester.widget<Slider>(
        find.byKey(const Key('player-seek')),
      );
      expect(slider.value, 30000);
      expect(slider.max, 60000);
    });

    testWidgets('la barre est déplaçable et la lecture saute à la position', (
      tester,
    ) async {
      await open(tester);

      await tester.drag(
        find.byKey(const Key('player-seek')),
        const Offset(120, 0),
      );
      await tester.pump();

      expect(players.last!.seeks, isNotEmpty);
      expect(players.last!.seeks.last, greaterThan(const Duration(seconds: 5)));
    });

    testWidgets('mise en mémoire tampon visible', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('player-buffering')), findsNothing);

      players.last!.emit(isBuffering: true);
      await tester.pump();
      expect(find.byKey(const Key('player-buffering')), findsOneWidget);

      players.last!.emit(isBuffering: false);
      await tester.pump();
      expect(find.byKey(const Key('player-buffering')), findsNothing);
    });
  });

  group('contrôles', () {
    testWidgets('se masquent après quelques secondes, reviennent au toucher', (
      tester,
    ) async {
      await open(tester);
      expect(controlsOpacity(tester), 1);

      await tester.pump(const Duration(seconds: 3, milliseconds: 500));
      expect(controlsOpacity(tester), 0);

      await tester.tap(find.byKey(const Key('player-surface')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controlsOpacity(tester), 1);

      // Un toucher hors des boutons, pendant qu'ils sont affichés, les masque.
      await tester.tapAt(const Offset(40, 320));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controlsOpacity(tester), 0);
    });

    testWidgets('lecture / pause, contrôles gardés en pause', (tester) async {
      await open(tester);
      final player = players.last!;

      await tester.tap(find.byKey(const Key('player-play-pause')));
      await tester.pump();
      expect(player.value.isPlaying, isFalse);

      await tester.pump(const Duration(seconds: 10));
      expect(controlsOpacity(tester), 1, reason: 'jamais masqués en pause');

      await tester.tap(find.byKey(const Key('player-play-pause')));
      await tester.pump();
      expect(player.value.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 4));
      expect(controlsOpacity(tester), 0);
    });

    testWidgets('paysage : mise en page sans débordement', (tester) async {
      await open(tester, size: const Size(800, 360));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('player-seek')), findsOneWidget);
    });
  });

  group('erreurs', () {
    testWidgets('session refusée : message en français et « Réessayer »', (
      tester,
    ) async {
      var allow = false;
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async {
        if (allow) return _session('tok-ok');
        return jsonResponse({
          'detail': 'Playback is restricted to registered active devices',
        }, 403);
      };
      api.overrides['POST /api/v1/devices/register'] = (_) async =>
          jsonResponse({'device_id': 'd1', 'is_active': true});
      await open(tester);

      expect(find.byType(GnErrorView), findsOneWidget);
      expect(
        find.text('Cet appareil n’est pas autorisé à lire des vidéos.'),
        findsOneWidget,
      );
      // Plus aucune mention d'une limite de trois appareils.
      expect(find.textContaining('limite'), findsNothing);
      expect(find.textContaining('3 appareils'), findsNothing);
      expect(players.created, isEmpty);

      allow = true;
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GnErrorView), findsNothing);
      expect(players.created, hasLength(1));
      expect(players.last!.value.isPlaying, isTrue);
    });

    testWidgets('l\'appareil est enregistré puis la lecture est retentée', (
      tester,
    ) async {
      var first = true;
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async {
        if (first) {
          first = false;
          return jsonResponse({
            'detail': 'Playback is restricted to registered active devices',
          }, 403);
        }
        return _session('tok-2');
      };
      api.overrides['POST /api/v1/devices/register'] = (_) async =>
          jsonResponse({'device_id': 'd1', 'is_active': true});
      await open(tester);

      expect(api.count('POST /api/v1/devices/register'), 1);
      expect(api.count('POST /api/v1/videos/v1/playback-session'), 2);
      expect(players.created, hasLength(1));
    });

    testWidgets('réseau coupé : message clair, pas d\'exception brute', (
      tester,
    ) async {
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async =>
          throw http.ClientException('Connection refused');
      await open(tester);

      expect(find.byType(GnErrorView), findsOneWidget);
      expect(
        find.text('Connexion impossible. Vérifiez votre accès à Internet.'),
        findsOneWidget,
      );
      expect(find.textContaining('ClientException'), findsNothing);
    });

    testWidgets('vidéo pas prête (400) : message traduit', (tester) async {
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async =>
          jsonResponse({'detail': 'Video is not ready for streaming'}, 400);
      await open(tester);

      expect(
        find.text('La vidéo est encore en cours de traitement.'),
        findsOneWidget,
      );
    });

    testWidgets('échec d\'initialisation du lecteur : « Réessayer »', (
      tester,
    ) async {
      players.build = () => FakeVideoController(failInitialize: true);
      await open(tester);

      expect(find.text('La lecture a échoué'), findsOneWidget);

      players.build = () => FakeVideoController();
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('La lecture a échoué'), findsNothing);
      expect(api.count('POST /api/v1/videos/v1/playback-session'), 2);
      expect(players.created, hasLength(2));
      expect(players.created.first.disposed, isTrue);
    });

    testWidgets('erreur en cours de lecture : reprise à la même position', (
      tester,
    ) async {
      await open(tester);
      final first = players.last!;
      first.emit(position: const Duration(seconds: 20));
      await tester.pump();
      first.value = first.value.copyWith(isPlaying: false);
      first.emit(error: 'segment refusé');
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('La lecture a échoué'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.count('POST /api/v1/videos/v1/playback-session'), 2);
      expect(players.created, hasLength(2));
      expect(players.last!.seeks, [const Duration(seconds: 20)]);
      expect(players.last!.value.isPlaying, isTrue);
      expect(first.disposed, isTrue);
    });

    testWidgets(
      'une erreur passagère suivie d\'une reprise n\'interrompt pas',
      (tester) async {
        await open(tester);
        final player = players.last!;
        player.value = player.value.copyWith(isPlaying: false);
        player.emit(error: 'décodage matériel');
        await tester.pump(const Duration(milliseconds: 500));
        // La lecture repart d'elle-même (repli logiciel).
        player.value = player.value.copyWith(
          isPlaying: true,
          errorDescription: null,
        );
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('La lecture a échoué'), findsNothing);
      },
    );
  });

  group('expiration de la session', () {
    testWidgets('renouvelée avant l\'échéance, lecture reprise sur place', (
      tester,
    ) async {
      await open(tester, validFor: const Duration(seconds: 90));
      final first = players.last!;
      first.emit(position: const Duration(seconds: 42));
      await tester.pump();
      expect(api.count('POST /api/v1/videos/v1/playback-session'), 1);

      // 90 s - 60 s de marge = renouvellement après 30 s.
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.count('POST /api/v1/videos/v1/playback-session'), 2);
      expect(players.created, hasLength(2));
      expect(players.urls.last.queryParameters['token'], 'tok-2');
      expect(players.last!.seeks, [const Duration(seconds: 42)]);
      expect(players.last!.value.isPlaying, isTrue);
      expect(first.disposed, isTrue);
    });

    testWidgets('renouvellement refusé : erreur puis « Réessayer »', (
      tester,
    ) async {
      var calls = 0;
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async {
        calls++;
        if (calls == 2) {
          return jsonResponse({'detail': 'Service indisponible'}, 503);
        }
        return _session('tok-$calls', validFor: const Duration(seconds: 90));
      };
      await open(tester);
      players.last!.emit(position: const Duration(seconds: 10));
      await tester.pump();

      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(GnErrorView), findsOneWidget);
      expect(find.text('Service indisponible'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(GnErrorView), findsNothing);
      expect(players.last!.seeks, [const Duration(seconds: 10)]);
    });
  });

  group('libération', () {
    testWidgets('fermer l\'écran libère le contrôleur et les minuteries', (
      tester,
    ) async {
      await open(tester);
      final player = players.last!;

      await tester.pumpWidget(const SizedBox());
      expect(player.disposed, isTrue);
      // Aucune minuterie (filigrane, masquage, renouvellement) ne subsiste.
      await tester.pump(const Duration(minutes: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fermer pendant le chargement de la session', (tester) async {
      final gate = Completer<void>();
      api.overrides['POST /api/v1/videos/v1/playback-session'] = (_) async {
        await gate.future;
        return _session('tok');
      };
      await open(tester);
      expect(find.text('Préparation de la lecture…'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump(const Duration(milliseconds: 200));

      expect(players.created, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
