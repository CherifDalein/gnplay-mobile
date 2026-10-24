import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gnplay/features/creator/presentation/providers/creator_dashboard_provider.dart';
import 'package:gnplay/features/creator/presentation/widgets/creator_avatar.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:google_fonts/google_fonts.dart';

import 'creator_dashboard_support.dart';
import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    seedSession();
  });

  Future<DashboardApi> open(
    WidgetTester tester, {
    DashboardApi? api,
    String phone = '+224621458807',
    String name = 'Mariama Diallo',
    String? avatar,
    ValueNotifier<GoRouter?>? router,
  }) async {
    final fake = api ?? DashboardApi();
    usePhoneScreen(tester);
    await tester.pumpWidget(
      dashboardApp(
        fake,
        user: testUser(phone: phone, name: name, avatar: avatar),
        routerOut: router,
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  group('données', () {
    testWidgets('affiche les vraies données du compte, en GNF pour +224', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Mariama Diallo'), findsOneWidget);
      expect(find.text('CRÉATEUR'), findsOneWidget);
      expect(find.text('SOLDE RETIRABLE'), findsOneWidget);
      expect(find.text('4 000'), findsOneWidget);
      expect(find.text('GNF'), findsOneWidget);
      expect(
        find.textContaining('Solde du portefeuille : 6 000 GNF'),
        findsOneWidget,
      );
      expect(find.textContaining('+1 000 GNF ce mois-ci'), findsOneWidget);
      // Grille de statistiques : `total_videos` compte toutes les vidéos.
      expect(find.text('Vidéos'), findsOneWidget);
      expect(find.text('Vidéos publiées'), findsNothing);
      expect(find.text('Vues totales'), findsOneWidget);
      expect(find.text('Abonnés'), findsOneWidget);
      expect(find.text('Revenu du mois'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      // Top des vidéos : revenu et miniature viennent de /videos/mine.
      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.textContaining('90 vues · 4 000 GNF'), findsOneWidget);
      expect(find.text('XOF'), findsNothing);
    });

    testWidgets('affiche la devise XOF pour un numéro +221', (tester) async {
      await open(tester, phone: '+221771234567');

      expect(find.text('XOF'), findsOneWidget);
      expect(
        find.textContaining('Solde du portefeuille : 6 000 XOF'),
        findsOneWidget,
      );
      expect(find.textContaining('90 vues · 4 000 XOF'), findsOneWidget);
      expect(find.textContaining('GNF'), findsNothing);
    });

    testWidgets('une vidéo supprimée n\'apparaît pas dans le top', (
      tester,
    ) async {
      final api = DashboardApi();
      api.analytics = {
        ...api.analytics,
        'top_videos': [
          {
            'video_id': 'gone',
            'title': 'Vidéo supprimée',
            'view_count': 500,
            'likes_count': 0,
          },
          {
            'video_id': 'v1',
            'title': 'Marché Madina',
            'view_count': 90,
            'likes_count': 5,
          },
        ],
      };
      await open(tester, api: api);

      expect(find.text('Vidéo supprimée'), findsNothing);
      expect(find.text('Marché Madina'), findsOneWidget);
    });

    testWidgets('avatar : repli sur les initiales si la photo ne charge pas', (
      tester,
    ) async {
      await open(tester, avatar: 'https://cdn.test/inconnue.jpg');

      expect(find.byType(CreatorAvatar), findsOneWidget);
      expect(find.text('MD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('miniature du top : repli si l\'image ne charge pas', (
      tester,
    ) async {
      final api = DashboardApi()
        ..videos = [
          videoJson('v1', 'Marché Madina', thumbnail: 'https://cdn.test/x.jpg'),
        ];
      await open(tester, api: api);

      expect(find.text('Marché Madina'), findsOneWidget);
      expect(find.text('miniature'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('cloche de notifications', () {
    testWidgets('badge du nombre de non lues et sémantique', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);

      expect(find.text('3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Notifications, 3 non lues'),
        findsOneWidget,
      );
      final size = tester.getSize(find.bySemanticsLabel(RegExp('^Notif')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      handle.dispose();
    });

    testWidgets('sans non lue : pas de badge', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, api: DashboardApi()..unread = 0);

      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('plafonne l\'affichage à 99+', (tester) async {
      await open(tester, api: DashboardApi()..unread = 250);

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('la cloche pousse /notifications', (tester) async {
      final router = ValueNotifier<GoRouter?>(null);
      await open(tester, router: router);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(find.text('page /notifications'), findsOneWidget);
      expect(router.value!.canPop(), isTrue);
      router.value!.pop();
      await tester.pumpAndSettle();
      expect(find.text('SOLDE RETIRABLE'), findsOneWidget);
    });

    testWidgets('« Retirer mes gains » pousse /payout', (tester) async {
      final router = ValueNotifier<GoRouter?>(null);
      await open(tester, router: router);

      await tester.tap(find.text('Retirer mes gains'));
      await tester.pumpAndSettle();

      expect(find.text('page /payout'), findsOneWidget);
      expect(router.value!.canPop(), isTrue);
    });

    testWidgets('une vidéo du top pousse /videos/<id> et le retour revient', (
      tester,
    ) async {
      final router = ValueNotifier<GoRouter?>(null);
      await open(tester, router: router);

      await tester.tap(find.text('Marché Madina'));
      await tester.pumpAndSettle();

      expect(find.text('page /videos/v1'), findsOneWidget);
      expect(router.value!.canPop(), isTrue);
      router.value!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Marché Madina'), findsOneWidget);
    });

    testWidgets('« Tout voir » mène à /videos', (tester) async {
      await open(tester);

      await tester.tap(find.text('Tout voir'));
      await tester.pumpAndSettle();

      expect(find.text('page /videos'), findsOneWidget);
    });
  });

  group('état vide', () {
    testWidgets('invite à publier la première vidéo', (tester) async {
      final api = DashboardApi()
        ..analytics = {
          'total_videos': 0,
          'total_views': 0,
          'total_followers': 0,
          'revenue_total': 0,
          'revenue_this_month': 0,
          'top_videos': <Object>[],
        }
        ..videos = <Object>[];
      await open(tester, api: api);

      expect(find.text('Publiez votre première vidéo'), findsOneWidget);
      expect(find.text('Vos vidéos les plus vues'), findsNothing);

      await tester.tap(find.text('Publier une vidéo'));
      await tester.pumpAndSettle();
      expect(find.text('page /publish'), findsOneWidget);
    });
  });

  group('chargement et erreurs', () {
    testWidgets('premier chargement : vue de chargement plein écran', (
      tester,
    ) async {
      final api = DashboardApi()..analyticsGate = Completer<void>();
      usePhoneScreen(tester);
      await tester.pumpWidget(dashboardApp(api));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GnLoadingView), findsOneWidget);
      expect(find.text('SOLDE RETIRABLE'), findsNothing);

      api.analyticsGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('SOLDE RETIRABLE'), findsOneWidget);
    });

    testWidgets('erreur puis « Réessayer »', (tester) async {
      final api = DashboardApi()..failAnalytics = 1;
      await open(tester, api: api);

      expect(find.byType(GnErrorView), findsOneWidget);
      expect(find.text('Service indisponible'), findsOneWidget);
      expect(find.text('SOLDE RETIRABLE'), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.byType(GnErrorView), findsNothing);
      expect(find.text('SOLDE RETIRABLE'), findsOneWidget);
      expect(find.text('Mariama Diallo'), findsOneWidget);
    });

    testWidgets('403 : état propre, pas d\'erreur réseau', (tester) async {
      // Le serveur refuse les statistiques à un compte non créateur.
      final api = DashboardApi()..forbidAnalytics = true;
      usePhoneScreen(tester);
      await tester.pumpWidget(dashboardApp(api));
      await tester.pumpAndSettle();

      expect(find.text('Espace réservé aux créateurs'), findsOneWidget);
      expect(find.byType(GnErrorView), findsNothing);
      await tester.tap(find.text('Devenir créateur'));
      await tester.pumpAndSettle();
      expect(find.text('page /become-creator'), findsOneWidget);
    });
  });

  group('rafraîchissement', () {
    testWidgets('tirer pour actualiser garde le contenu et met à jour', (
      tester,
    ) async {
      final api = await open(tester);
      expect(find.text('3'), findsOneWidget);
      final before = api.analyticsCalls;

      // Les nouvelles valeurs n'arrivent qu'après la levée de la porte.
      api.analyticsGate = Completer<void>();
      api.unread = 5;
      api.balance = {...api.balance, 'withdrawable_balance': 9000};
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Pendant l'attente, l'ancien contenu est toujours là.
      expect(api.analyticsCalls, before + 1);
      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.text('Mariama Diallo'), findsOneWidget);
      expect(find.text('4 000'), findsOneWidget);

      api.analyticsGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('9 000'), findsOneWidget);
      // Le compteur de notifications est rafraîchi aussi.
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('actualisation automatique : fin trait, sans plein écran', (
      tester,
    ) async {
      final api = await open(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomScrollView)),
      );

      api.analyticsGate = Completer<void>();
      container.invalidate(creatorDashboardProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GnLoadingView), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Marché Madina'), findsOneWidget);

      api.analyticsGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('échec d\'une actualisation : données gardées et bandeau', (
      tester,
    ) async {
      final api = await open(tester);
      api.failAnalytics = 1;

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

    testWidgets('retour sur l\'onglet : actualise sans effacer le contenu', (
      tester,
    ) async {
      final visible = ValueNotifier<bool>(true);
      final api = DashboardApi();
      usePhoneScreen(tester);
      await tester.pumpWidget(
        dashboardApp(
          api,
          wrap: (dashboard) => ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, active, _) =>
                TickerMode(enabled: active, child: dashboard),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = api.analyticsCalls;

      visible.value = false;
      await tester.pump();
      expect(api.analyticsCalls, before);

      api.unread = 7;
      visible.value = true;
      await tester.pump();
      await tester.pump();
      expect(find.text('Marché Madina'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(api.analyticsCalls, before + 1);
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('mise en page à 360 px', () {
    testWidgets('grands nombres et nom long : aucun débordement', (
      tester,
    ) async {
      final api = DashboardApi()
        ..analytics = {
          'total_videos': 1234,
          'total_views': 987654321,
          'total_followers': 1234567,
          'revenue_total': 999999999,
          'revenue_this_month': 987654321,
          'top_videos': [
            {
              'video_id': 'v1',
              'title':
                  'Un titre de vidéo vraiment très long qui devra passer à '
                  'la ligne sans déborder de la ligne',
              'view_count': 987654321,
              'likes_count': 5,
            },
          ],
        }
        ..videos = [
          videoJson(
            'v1',
            'Un titre de vidéo vraiment très long qui devra passer à '
                'la ligne sans déborder de la ligne',
            views: 987654321,
            revenue: 987654321,
          ),
        ]
        ..balance = {
          'withdrawable_balance': 987654321,
          'wallet_balance': 987654321,
        };
      await open(
        tester,
        api: api,
        name: 'Aminata Mariama Kadiatou Diallo Bah Camara',
      );
      // Police du système agrandie : rien ne doit se couper non plus.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Vues totales'), findsOneWidget);
      expect(find.text('Revenu du mois'), findsOneWidget);
    });
  });
}
