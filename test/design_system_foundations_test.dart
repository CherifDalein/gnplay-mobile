import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';
import 'package:gnplay/shared/widgets/design_system/gn_svg_path.dart';

Future<void> pumpApp(WidgetTester tester, Widget child, {EdgeInsets? padding}) {
  Widget app = MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );
  if (padding != null) {
    app = MediaQuery(
      data: MediaQueryData(padding: padding),
      child: app,
    );
  }
  return tester.pumpWidget(app);
}

void main() {
  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Tokens', () {
    test('rayons manquants de la maquette', () {
      expect(AppRadii.xs, 8);
      expect(AppRadii.r10, 10);
      expect(AppRadii.r11, 11);
      expect(AppRadii.r13, 13);
      expect(AppRadii.r14, 14);
      expect(AppRadii.r18, 18);
      expect(AppRadii.sheet, 22);
      // Les rayons existants ne bougent pas.
      expect(AppRadii.sm, 9);
      expect(AppRadii.md, 12);
      expect(AppRadii.lg, 16);
      expect(AppRadii.xl, 20);
    });

    test('ombres card et fab', () {
      expect(AppShadows.card.single.blurRadius, 30);
      expect(AppShadows.card.single.offset, const Offset(0, 12));
      expect(AppShadows.fab.single.blurRadius, 20);
      expect(AppShadows.fab.single.offset, const Offset(0, 8));
    });

    test('couleurs en dur promues en tokens', () {
      expect(AppColors.surfaceNeutral, const Color(0xFF22222A));
      expect(AppColors.thumbStripeB, const Color(0xFF1A0C12));
      expect(AppColors.fgMuted, const Color(0xFF8B8B95));
    });

    test('dégradé brand : fin à 130 % ramenée à 100 %', () {
      expect(AppGradients.brand.colors.first, AppColors.brand900);
      expect(AppGradients.brand.colors.last, const Color(0xFF9D1639));
      // Contrôle : lerp(brand800, brand500, 0.625) == #9D1639.
      final lerped = Color.lerp(AppColors.brand800, AppColors.brand500, 0.625)!;
      expect(lerped.toARGB32(), 0xFF9D1639);
    });

    testWidgets('polices : helpers Sora / Inter via google_fonts', (
      tester,
    ) async {
      final display = AppTextStyles.display(
        size: 17,
        weight: FontWeight.w700,
        color: Colors.white,
      );
      expect(display.fontFamily, startsWith('Sora'));
      expect(display.fontSize, 17);
      expect(display.color, Colors.white);

      final body = AppTextStyles.bodyText(size: 12);
      expect(body.fontFamily, startsWith('Inter'));
      expect(body.fontSize, 12);

      expect(AppTextStyles.screenTitle.fontSize, 22);
      expect(AppTextStyles.appBarTitle.fontSize, 17);
      expect(AppTextStyles.authTitle.fontSize, 24);
      expect(AppTextStyles.buttonLabel.fontFamily, startsWith('Sora'));
    });

    testWidgets('AppFonts reste disponible (compatibilité)', (tester) async {
      expect(AppFonts.display, 'Sora');
      expect(AppFonts.body, 'Inter');
    });
  });

  group('Chemins SVG', () {
    test('lignes et fermeture', () {
      final path = parseSvgPath('M2 3L10 3 10 9z');
      expect(path.getBounds(), const Rect.fromLTRB(2, 3, 10, 9));
    });

    test('commandes relatives H / V', () {
      final path = parseSvgPath('M1 1h4v5H1z');
      expect(path.getBounds(), const Rect.fromLTRB(1, 1, 5, 6));
    });

    test('nombres collés et signes (.6-.1)', () {
      final path = parseSvgPath('M1 1l.5.5.6-.1');
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(1, 1e-6));
      expect(bounds.right, closeTo(2.1, 1e-6));
    });

    test('arc : un cercle complet', () {
      final path = parseSvgPath('M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16z');
      final b = path.getBounds();
      expect(b.left, closeTo(4, 0.05));
      expect(b.right, closeTo(20, 0.05));
      expect(b.top, closeTo(4, 0.05));
      expect(b.bottom, closeTo(20, 0.05));
    });

    test('courbes cubiques et quadratiques', () {
      expect(
        () => parseSvgPath('M0 0c1 0 2 1 2 2s1 2 2 2q1 0 1 1t1 1'),
        returnsNormally,
      );
    });

    test('chemin invalide', () {
      expect(() => parseSvgPath('M1'), throwsFormatException);
      expect(() => parseSvgPath('X1 2'), throwsFormatException);
    });
  });

  group('GnLineIcon', () {
    testWidgets('toutes les icônes se dessinent sans erreur', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final icon in GnLineIconData.values)
                GnLineIcon(icon, size: 24, color: Colors.white),
              for (final icon in GnLineIconData.values)
                GnLineIcon(icon, size: 24, filled: true),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(GnLineIcon),
        findsNWidgets(GnLineIconData.values.length * 2),
      );
    });

    test('les icônes demandées existent', () {
      const expected = [
        'back',
        'chevronLeft',
        'close',
        'search',
        'filter',
        'edit',
        'trash',
        'play',
        'pause',
        'volume',
        'volumeOff',
        'refresh',
        'check',
        'checkCircle',
        'alert',
        'error',
        'upload',
        'image',
        'lock',
        'logout',
        'settings',
        'phone',
        'device',
        'monitor',
        'shield',
        'clock',
        'copy',
        'externalLink',
        'moreVertical',
        'star',
        'download',
        'calendar',
        'chart',
        'percent',
        'moon',
        'document',
      ];
      final names = GnLineIconData.values.map((e) => e.name).toSet();
      expect(names, containsAll(expected));
    });

    test('toutes les icônes hors les 12 historiques ont un tracé SVG', () {
      const legacy = {
        GnLineIconData.home,
        GnLineIconData.video,
        GnLineIconData.plus,
        GnLineIconData.wallet,
        GnLineIconData.user,
        GnLineIconData.bell,
        GnLineIconData.eye,
        GnLineIconData.group,
        GnLineIconData.chevronRight,
        GnLineIconData.arrowUp,
        GnLineIconData.arrowDown,
        GnLineIconData.info,
      };
      for (final icon in GnLineIconData.values) {
        if (legacy.contains(icon)) continue;
        expect(gnLineIconHasSvgPath(icon), isTrue, reason: icon.name);
      }
    });

    testWidgets('semanticLabel est exposé', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GnLineIcon(GnLineIconData.lock, semanticLabel: 'Verrouillé'),
        ),
      );
      expect(find.bySemanticsLabel('Verrouillé'), findsOneWidget);
      handle.dispose();
    });
  });

  group('GnButton', () {
    testWidgets('le libellé utilise Sora via google_fonts', (tester) async {
      await pumpApp(tester, GnButton(label: 'Continuer', onPressed: () {}));
      final text = tester.widget<Text>(find.text('Continuer'));
      expect(text.style?.fontFamily, startsWith('Sora'));
      expect(text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('appelle onPressed, désactivé sans callback', (tester) async {
      var taps = 0;
      await pumpApp(tester, GnButton(label: 'Ok', onPressed: () => taps++));
      await tester.tap(find.text('Ok'));
      expect(taps, 1);

      await pumpApp(tester, const GnButton(label: 'Ok', onPressed: null));
      await tester.tap(find.text('Ok'));
      expect(taps, 1);
    });

    testWidgets('chargement : spinner et pas de callback', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        GnButton(label: 'Ok', isLoading: true, onPressed: () => taps++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(GnButton));
      expect(taps, 0);
    });

    testWidgets('dangerFilled et hauteur personnalisée', (tester) async {
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: GnButton(
            label: 'Supprimer',
            onPressed: () {},
            variant: GnButtonVariant.dangerFilled,
            height: 48,
          ),
        ),
      );
      expect(tester.getSize(find.byType(GnButton)).height, 48);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(GnButton),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, AppColors.danger);
    });

    testWidgets('primaire : accent600 pendant l\'appui', (tester) async {
      await pumpApp(tester, GnButton(label: 'Ok', onPressed: () {}));
      Color? background() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(GnButton),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color;
      }

      expect(background(), AppColors.accent500);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GnButton)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(background(), AppColors.accent600);
      await gesture.up();
      await tester.pump();
      expect(background(), AppColors.accent500);
    });
  });

  group('GnBottomNav', () {
    GnBottomNav nav({ValueChanged<int>? onTap, int current = 0}) {
      return GnBottomNav(
        currentIndex: current,
        onTap: onTap ?? (_) {},
        items: const [
          GnBottomNavItem(
            label: 'Accueil',
            icon: GnLineIcon(GnLineIconData.home),
          ),
          GnBottomNavItem(
            label: 'Publier',
            icon: GnLineIcon(GnLineIconData.plus, size: 24),
            isFab: true,
          ),
          GnBottomNavItem(
            label: 'Profil',
            icon: GnLineIcon(GnLineIconData.user),
          ),
        ],
      );
    }

    testWidgets('hauteur 86, flou d\'arrière-plan, icônes 22 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: const SizedBox(), bottomNavigationBar: nav()),
        ),
      );
      expect(tester.getSize(find.byType(GnBottomNav)).height, 86);
      expect(find.byType(BackdropFilter), findsOneWidget);

      for (final icon in tester.widgetList<GnLineIcon>(
        find.byType(GnLineIcon),
      )) {
        // L'icône est mise à l'échelle par un FittedBox dans une boîte de 22 px.
        final box = tester.getSize(
          find
              .ancestor(
                of: find.byWidget(icon),
                matching: find.byType(FittedBox),
              )
              .first,
        );
        expect(box.width, closeTo(22, 0.01), reason: '${icon.icon}');
      }
    });

    testWidgets('la zone système basse est comptée dans la hauteur', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(body: const SizedBox(), bottomNavigationBar: nav()),
          ),
        ),
      );
      // 62 de contenu + 34 de zone système = 96 (et non 86 + 34 = 120).
      expect(tester.getSize(find.byType(GnBottomNav)).height, 96);
    });

    testWidgets('appelle onTap avec l\'index', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: nav(onTap: taps.add),
          ),
        ),
      );
      await tester.tap(find.text('Profil'));
      await tester.tap(find.text('Accueil'));
      expect(taps, [2, 0]);
    });

    testWidgets('l\'onglet actif est annoncé comme sélectionné', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: nav(current: 2),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Profil')),
        matchesSemantics(
          label: 'Profil',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
