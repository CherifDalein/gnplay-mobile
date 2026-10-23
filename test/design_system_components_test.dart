import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';

Future<void> pumpApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GnBackButton / GnScreenHeader', () {
    testWidgets('affiche titre, sous-titre et actions', (tester) async {
      await pumpApp(
        tester,
        GnScreenHeader(
          title: 'Appareils connectés',
          subtitle: '2/3 appareils actifs',
          actions: const [Icon(Icons.more_vert, key: Key('action'))],
          onBack: () {},
        ),
      );

      expect(find.text('Appareils connectés'), findsOneWidget);
      expect(find.text('2/3 appareils actifs'), findsOneWidget);
      expect(find.byKey(const Key('action')), findsOneWidget);
      expect(find.byType(GnBackButton), findsOneWidget);
    });

    testWidgets('showBack: false masque le retour', (tester) async {
      await pumpApp(
        tester,
        const GnScreenHeader(title: 'Mon contenu', showBack: false),
      );
      expect(find.byType(GnBackButton), findsNothing);
    });

    testWidgets('le retour a une cible >= 44 px et le libellé Retour', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, GnScreenHeader(title: 'Profil', onBack: () {}));

      final size = tester.getSize(find.byType(GnBackButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Retour'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('onBack est appelé au toucher', (tester) async {
      var calls = 0;
      await pumpApp(
        tester,
        GnScreenHeader(title: 'Profil', onBack: () => calls++),
      );
      await tester.tap(find.byType(GnBackButton));
      expect(calls, 1);
    });

    testWidgets('par défaut, le retour fait Navigator.maybePop', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: GnScreenHeader(title: 'Détail')),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Détail'), findsOneWidget);

      await tester.tap(find.byType(GnBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Détail'), findsNothing);
      expect(find.text('Ouvrir'), findsOneWidget);
    });
  });

  group('showGnToast', () {
    Widget launcher(void Function(BuildContext) onTap) {
      return Builder(
        builder: (context) => TextButton(
          onPressed: () => onTap(context),
          child: const Text('Go'),
        ),
      );
    }

    testWidgets('affiche le message puis le masque', (tester) async {
      await pumpApp(
        tester,
        launcher(
          (c) => showGnToast(c, 'Vidéo publiée', tone: GnToastTone.success),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Vidéo publiée'), findsOneWidget);
      expect(find.byType(GnToast), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Vidéo publiée'), findsNothing);
    });

    testWidgets('un seul toast à la fois', (tester) async {
      var n = 0;
      await pumpApp(tester, launcher((c) => showGnToast(c, 'Message ${++n}')));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GnToast), findsOneWidget);
      expect(find.text('Message 1'), findsNothing);
      expect(find.text('Message 2'), findsOneWidget);

      hideGnToast();
      await tester.pump();
      expect(find.byType(GnToast), findsNothing);
    });

    testWidgets('le ton colore le point', (tester) async {
      expect(GnToast.dotColorFor(GnToastTone.success), AppColors.success);
      expect(GnToast.dotColorFor(GnToastTone.error), AppColors.danger);
      expect(GnToast.dotColorFor(GnToastTone.info), AppColors.info);
    });

    testWidgets('est placé au-dessus de la barre d\'onglets', (tester) async {
      await pumpApp(tester, launcher((c) => showGnToast(c, 'Position')));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rect = tester.getRect(find.byType(GnToast));
      final screenBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(screenBottom - rect.bottom, greaterThanOrEqualTo(100));

      hideGnToast();
      await tester.pump();
    });
  });

  group('showGnConfirmSheet', () {
    Future<void> openSheet(
      WidgetTester tester,
      void Function(bool) onResult, {
      bool destructive = false,
    }) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final ok = await showGnConfirmSheet(
                context,
                title: 'Supprimer cette vidéo ?',
                message: 'Elle disparaîtra du catalogue.',
                confirmLabel: 'Supprimer',
                destructive: destructive,
              );
              onResult(ok);
            },
            child: const Text('Ouvrir'),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('affiche titre, message et boutons', (tester) async {
      await openSheet(tester, (_) {});
      expect(find.text('Supprimer cette vidéo ?'), findsOneWidget);
      expect(find.text('Elle disparaîtra du catalogue.'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('renvoie true à la confirmation', (tester) async {
      bool? result;
      await openSheet(tester, (v) => result = v);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(GnConfirmSheet), findsNothing);
    });

    testWidgets('renvoie false sur Annuler', (tester) async {
      bool? result;
      await openSheet(tester, (v) => result = v);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('renvoie false si on ferme en touchant à côté', (tester) async {
      bool? result;
      await openSheet(tester, (v) => result = v);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.byType(GnConfirmSheet), findsNothing);
    });

    testWidgets('destructive utilise le bouton rouge plein', (tester) async {
      await openSheet(tester, (_) {}, destructive: true);
      final buttons = tester.widgetList<GnButton>(find.byType(GnButton));
      expect(
        buttons.map((b) => b.variant),
        contains(GnButtonVariant.dangerFilled),
      );
      expect(buttons.every((b) => b.height == 48), isTrue);
    });
  });

  group('GnSegmentedTabs', () {
    testWidgets('change de sélection au toucher', (tester) async {
      var value = 'videos';
      final changes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => GnSegmentedTabs<String>(
                tabs: const [
                  GnSegmentedTab(value: 'videos', label: 'Vidéos', count: 12),
                  GnSegmentedTab(value: 'series', label: 'Séries', count: 3),
                ],
                value: value,
                onChanged: (v) {
                  changes.add(v);
                  setState(() => value = v);
                },
              ),
            ),
          ),
        ),
      );

      Color? colorOf(String label) {
        final box = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (box.decoration as BoxDecoration?)?.color;
      }

      expect(find.text('12'), findsOneWidget);
      expect(colorOf('Vidéos'), AppColors.brand600);
      expect(colorOf('Séries'), Colors.transparent);

      await tester.tap(find.text('Séries'));
      await tester.pumpAndSettle();

      expect(changes, ['series']);
      expect(colorOf('Séries'), AppColors.brand600);
      expect(colorOf('Vidéos'), Colors.transparent);

      // Toucher l'onglet déjà actif ne déclenche rien.
      await tester.tap(find.text('Séries'));
      await tester.pumpAndSettle();
      expect(changes, ['series']);
    });

    testWidgets('chaque onglet a une cible de 44 px', (tester) async {
      await pumpApp(
        tester,
        GnSegmentedTabs<int>(
          tabs: const [
            GnSegmentedTab(value: 1, label: 'Achetées'),
            GnSegmentedTab(value: 2, label: 'En cours'),
            GnSegmentedTab(value: 3, label: 'Gratuites'),
          ],
          value: 1,
          onChanged: (_) {},
        ),
      );
      expect(
        tester.getSize(find.byType(GnSegmentedTabs<int>)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('GnChip / GnChipGroup', () {
    testWidgets('GnChip appelle onTap', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: GnChip(label: 'Publiées', onTap: () => taps++),
        ),
      );
      await tester.tap(find.text('Publiées'));
      expect(taps, 1);
    });

    testWidgets('GnChip désactivé ne réagit pas', (tester) async {
      await pumpApp(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: GnChip(label: 'Échecs'),
        ),
      );
      // Pas de callback : rien ne plante au toucher.
      await tester.tap(find.text('Échecs'));
      expect(find.text('Échecs'), findsOneWidget);
    });

    testWidgets('GnChip avec onDeleted affiche la croix', (tester) async {
      var removed = 0;
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: GnChip(label: 'Publiées', onDeleted: () => removed++),
        ),
      );
      expect(find.byType(GnLineIcon), findsOneWidget);
      await tester.tap(find.text('Publiées'));
      expect(removed, 1);
    });

    testWidgets('GnChipGroup change de sélection', (tester) async {
      var selected = 'all';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => GnChipGroup<String>(
                options: const [
                  GnChipOption(value: 'all', label: 'Toutes'),
                  GnChipOption(value: 'published', label: 'Publiées'),
                  GnChipOption(value: 'failed', label: 'Échecs'),
                ],
                selected: selected,
                onSelected: (v) => setState(() => selected = v),
              ),
            ),
          ),
        ),
      );

      bool isSelected(String label) =>
          tester.widget<GnChip>(find.widgetWithText(GnChip, label)).selected;

      expect(isSelected('Toutes'), isTrue);
      expect(isSelected('Publiées'), isFalse);

      await tester.tap(find.text('Publiées'));
      await tester.pump();

      expect(selected, 'published');
      expect(isSelected('Toutes'), isFalse);
      expect(isSelected('Publiées'), isTrue);
    });
  });

  group('GnSearchField', () {
    testWidgets('affiche l\'indication et efface le texte', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      var cleared = 0;

      await pumpApp(
        tester,
        GnSearchField(
          controller: controller,
          hintText: 'Rechercher une vidéo',
          onChanged: changes.add,
          onClear: () => cleared++,
        ),
      );

      expect(find.text('Rechercher une vidéo'), findsOneWidget);
      expect(find.bySemanticsLabel('Effacer la recherche'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nuits');
      await tester.pump();
      expect(changes, ['nuits']);
      expect(find.bySemanticsLabel('Effacer la recherche'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Effacer la recherche'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changes.last, '');
      expect(cleared, 1);
      expect(find.bySemanticsLabel('Effacer la recherche'), findsNothing);
      handle.dispose();
    });

    testWidgets('fonctionne sans contrôleur externe', (tester) async {
      String? submitted;
      await pumpApp(tester, GnSearchField(onSubmitted: (v) => submitted = v));
      await tester.enterText(find.byType(TextField), 'marché');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, 'marché');
    });
  });

  group('GnBanner', () {
    testWidgets('affiche titre, texte et action', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        GnBanner(
          tone: GnBannerTone.warning,
          title: 'Limite atteinte',
          message: 'Révoquez un appareil.',
          actionLabel: 'Gérer',
          onAction: () => taps++,
        ),
      );
      expect(find.text('Limite atteinte'), findsOneWidget);
      expect(find.text('Révoquez un appareil.'), findsOneWidget);
      await tester.tap(find.text('Gérer'));
      expect(taps, 1);
    });

    testWidgets('sans onAction, l\'action n\'est pas affichée', (tester) async {
      await pumpApp(
        tester,
        const GnBanner(message: 'Info', actionLabel: 'Gérer'),
      );
      expect(find.text('Gérer'), findsNothing);
    });

    testWidgets('chaque ton se rend avec son icône', (tester) async {
      for (final tone in GnBannerTone.values) {
        await pumpApp(tester, GnBanner(tone: tone, message: 'Texte $tone'));
        expect(find.text('Texte $tone'), findsOneWidget);
        expect(find.byType(GnLineIcon), findsOneWidget);
      }
    });

    testWidgets('accepte une icône personnalisée', (tester) async {
      await pumpApp(
        tester,
        const GnBanner(
          message: 'Info',
          icon: Icon(Icons.star, key: Key('i')),
        ),
      );
      expect(find.byKey(const Key('i')), findsOneWidget);
      expect(find.byType(GnLineIcon), findsNothing);
    });
  });

  group('GnNumericKeypad', () {
    Future<void> tapKeys(WidgetTester tester, List<String> labels) async {
      for (final label in labels) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
    }

    Widget host(Widget keypad) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 300, child: keypad),
    );

    testWidgets('saisit et efface dans le contrôleur', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(tester, host(GnNumericKeypad(controller: controller)));

      await tapKeys(tester, ['1', '5', '000']);
      expect(controller.text, '15000');

      await tester.tap(find.bySemanticsLabel('Effacer'));
      await tester.pump();
      expect(controller.text, '1500');
    });

    testWidgets('ignore les zéros initiaux par défaut', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(tester, host(GnNumericKeypad(controller: controller)));

      await tapKeys(tester, ['0', '000', '7']);
      expect(controller.text, '7');
    });

    testWidgets('allowLeadingZero accepte le zéro', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        host(GnNumericKeypad(controller: controller, allowLeadingZero: true)),
      );
      await tapKeys(tester, ['0', '5']);
      expect(controller.text, '05');
    });

    testWidgets('respecte maxLength', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        host(GnNumericKeypad(controller: controller, maxLength: 4)),
      );
      await tapKeys(tester, ['1', '2', '000']);
      expect(controller.text, '12');
      await tapKeys(tester, ['3', '4', '5']);
      expect(controller.text, '1234');
    });

    testWidgets('mode virgule : une seule virgule', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        host(
          GnNumericKeypad(
            controller: controller,
            extraKey: GnKeypadExtraKey.comma,
          ),
        ),
      );
      expect(find.text('000'), findsNothing);
      await tapKeys(tester, ['1', ',', '5', ',', '2']);
      expect(controller.text, '1,52');
    });

    testWidgets('sans touche supplémentaire', (tester) async {
      await pumpApp(
        tester,
        host(const GnNumericKeypad(extraKey: GnKeypadExtraKey.none)),
      );
      expect(find.text('000'), findsNothing);
      expect(find.text(','), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('appelle onDigit et onBackspace', (tester) async {
      final digits = <String>[];
      var backspaces = 0;
      await pumpApp(
        tester,
        host(
          GnNumericKeypad(onDigit: digits.add, onBackspace: () => backspaces++),
        ),
      );
      await tapKeys(tester, ['4', '000', '0']);
      await tester.tap(find.bySemanticsLabel('Effacer'));
      await tester.pump();
      expect(digits, ['4', '000', '0']);
      expect(backspaces, 1);
    });

    testWidgets('désactivé : aucune saisie', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final digits = <String>[];
      await pumpApp(
        tester,
        host(
          GnNumericKeypad(
            controller: controller,
            onDigit: digits.add,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.text('1'), warnIfMissed: false);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(digits, isEmpty);
    });

    testWidgets('appui long sur effacer vide le contrôleur', (tester) async {
      final controller = TextEditingController(text: '12345');
      addTearDown(controller.dispose);
      await pumpApp(tester, host(GnNumericKeypad(controller: controller)));
      await tester.longPress(find.bySemanticsLabel('Effacer'));
      await tester.pump();
      expect(controller.text, isEmpty);
    });
  });

  group('GnSwitch', () {
    testWidgets('bascule au toucher', (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => GnSwitch(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GnSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      await tester.tap(find.byType(GnSwitch));
      await tester.pumpAndSettle();
      expect(value, isFalse);
    });

    testWidgets('piste brand600 quand actif, border1 sinon', (tester) async {
      Color? track() {
        final box = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(GnSwitch),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (box.decoration as BoxDecoration).color;
      }

      await pumpApp(tester, GnSwitch(value: true, onChanged: (_) {}));
      expect(track(), AppColors.brand600);
      await pumpApp(tester, GnSwitch(value: false, onChanged: (_) {}));
      await tester.pumpAndSettle();
      expect(track(), AppColors.border1);
    });

    testWidgets('désactivé (onChanged null) ne réagit pas', (tester) async {
      await pumpApp(tester, const GnSwitch(value: false, onChanged: null));
      await tester.tap(find.byType(GnSwitch));
      await tester.pumpAndSettle();
      expect(find.byType(GnSwitch), findsOneWidget);
    });

    testWidgets('loading bloque le toucher', (tester) async {
      var calls = 0;
      await pumpApp(
        tester,
        GnSwitch(value: false, loading: true, onChanged: (_) => calls++),
      );
      await tester.tap(find.byType(GnSwitch));
      await tester.pump();
      expect(calls, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('cible >= 44 px, dimensions normale et compacte', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: GnSwitch(value: true, onChanged: (_) {}),
        ),
      );
      final size = tester.getSize(find.byType(GnSwitch));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      Size track() => tester.getSize(
        find.descendant(
          of: find.byType(GnSwitch),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(track(), const Size(46, 26));

      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: GnSwitch(value: true, compact: true, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(track(), const Size(44, 25));
    });

    testWidgets('expose l\'état à l\'accessibilité', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        GnSwitch(value: true, semanticLabel: 'Publiée', onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(GnSwitch)),
        matchesSemantics(
          label: 'Publiée',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('États uniformes', () {
    testWidgets('GnLoadingView affiche une roue et un message', (tester) async {
      await pumpApp(tester, const GnLoadingView(message: 'Chargement…'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement…'), findsOneWidget);
    });

    testWidgets('GnErrorView : message et bouton Réessayer', (tester) async {
      var retries = 0;
      await pumpApp(
        tester,
        GnErrorView(
          message: 'Vérifiez votre connexion.',
          onRetry: () => retries++,
        ),
      );
      expect(find.text('Impossible de charger le contenu'), findsOneWidget);
      expect(find.text('Vérifiez votre connexion.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });

    testWidgets('GnErrorView sans onRetry n\'a pas de bouton', (tester) async {
      await pumpApp(tester, const GnErrorView(title: 'Oups'));
      expect(find.byType(GnButton), findsNothing);
    });

    testWidgets('GnEmptyView : texte et action', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        GnEmptyView(
          title: 'Aucune vidéo',
          message: 'Publiez votre première vidéo.',
          actionLabel: 'Nouvelle vidéo',
          onAction: () => taps++,
        ),
      );
      expect(find.text('Aucune vidéo'), findsOneWidget);
      expect(find.text('Publiez votre première vidéo.'), findsOneWidget);
      await tester.tap(find.text('Nouvelle vidéo'));
      expect(taps, 1);
    });

    testWidgets('GnEmptyView sans action', (tester) async {
      await pumpApp(tester, const GnEmptyView(title: 'Rien ici'));
      expect(find.byType(GnButton), findsNothing);
    });

    testWidgets('compact ne prend pas tout l\'écran', (tester) async {
      await pumpApp(tester, const GnEmptyView(title: 'Rien ici'));
      final full = tester.getSize(find.byType(GnEmptyView)).height;

      await pumpApp(
        tester,
        const SingleChildScrollView(
          child: Column(
            children: [GnEmptyView(title: 'Rien ici', compact: true)],
          ),
        ),
      );
      final compact = tester.getSize(find.byType(GnEmptyView)).height;
      expect(compact, lessThan(full));

      await pumpApp(
        tester,
        const SingleChildScrollView(
          child: Column(
            children: [
              GnLoadingView(compact: true),
              GnErrorView(compact: true, title: 'Erreur'),
            ],
          ),
        ),
      );
      expect(find.byType(GnLoadingView), findsOneWidget);
      expect(find.byType(GnErrorView), findsOneWidget);
    });
  });
}
