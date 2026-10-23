import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const bgApp = Color(0xFF0B0B0D);
  static const surface1 = Color(0xFF16161A);
  static const surface2 = Color(0xFF111116);
  static const surface3 = Color(0xFF1F1F25);
  static const border1 = Color(0xFF2C2C33);
  static const border2 = Color(0xFF202026);

  static const brand950 = Color(0xFF1A0712);
  static const brand900 = Color(0xFF2A0E1F);
  static const brand800 = Color(0xFF5C1330);
  static const brand700 = Color(0xFF8A1436);
  static const brand600 = Color(0xFFA8123B);
  static const brand500 = Color(0xFFC4183F);

  static const accent500 = Color(0xFFF5A623);
  static const accent600 = Color(0xFFD98A0E);
  static const accent300 = Color(0xFFFFCB6B);

  static const text1 = Color(0xFFFFFFFF);
  static const text2 = Color(0xFFB6B6C0);
  static const text3 = Color(0xFF6E6E78);
  static const text4 = Color(0xFF4A4A52);
  static const textInverse = Color(0xFF1A0712);

  static const success = Color(0xFF2FAE60);
  static const warning = Color(0xFFE8B23D);
  static const danger = Color(0xFFFF5A5F);
  static const info = Color(0xFF3B82F6);

  static const successBg = Color(0x242FAE60);
  static const warningBg = Color(0x1AE8B23D);
  static const dangerBg = Color(0x1AFF5A5F);
  static const infoBg = Color(0x243B82F6);

  // Fond semi-transparent propre à la barre de navigation basse (pas un
  // simple renommage d'un token existant, donc pas un alias "legacy").
  static const navBg = Color(0xEB0B0B0D);
  static const navBorder = surface1;

  // --- Nuances issues de la maquette (tokens/colors.css + valeurs en ligne) ---

  /// Fond des pastilles neutres / compteurs inactifs (#22222A). La maquette
  /// le distingue de `surface3` (#1F1F25) : ne pas les fusionner.
  static const surfaceNeutral = Color(0xFF22222A);

  /// Survol / appui sur une surface `surface1` (touches du pavé, cartes).
  static const surfaceHover = Color(0xFF1E1E24);

  /// Texte « discret » des onglets segmentés inactifs (#8B8B95).
  static const fgMuted = Color(0xFF8B8B95);

  /// Rayures des miniatures par défaut (115° #241019 / #1A0C12).
  static const thumbStripeA = Color(0xFF241019);
  static const thumbStripeB = Color(0xFF1A0C12);

  /// Voile derrière un bottom sheet (rgba(5,5,7,.72)).
  static const scrim = Color(0xB8050507);

  /// Voiles noirs posés sur les images (badges « Aperçu 15 s »).
  static const overlay55 = Color(0x8C000000);
  static const overlay60 = Color(0x99000000);

  /// Teintes translucides de `brand600` (rgba(168,18,59,α)).
  static const brandTint18 = Color(0x2EA8123B);
  static const brandTint20 = Color(0x33A8123B);
  static const brandTint22 = Color(0x38A8123B);

  /// Teintes translucides de l'or (pill « Nouvelle vidéo », rgba(245,166,35,α)).
  static const accentTint12 = Color(0x1FF5A623);
  static const accentTint20 = Color(0x33F5A623);
  static const accentBorder35 = Color(0x59F5A623);

  /// Bordures translucides des bandeaux et boutons dangereux.
  static const successBorder = Color(0x4D2FAE60);
  static const warningBorder = Color(0x59E8B23D);
  static const dangerBorder = Color(0x59FF5A5F);
  static const infoBorder = Color(0x4D3B82F6);

  /// Fond du bandeau d'information (rgba(59,130,246,.09)).
  static const infoBannerBg = Color(0x173B82F6);
}

class AppSpacing {
  const AppSpacing._();

  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x7 = 32.0;
  static const x8 = 40.0;
}

class AppRadii {
  const AppRadii._();

  static const sm = 9.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
  static const phone = 46.0;

  // Rayons réellement utilisés par la maquette, absents de l'échelle 9/12/16/20.
  /// Tuile d'icône (StatTile, 26x26).
  static const xs = 8.0;

  /// Boutons secondaires, miniatures, bandeaux compacts.
  static const r10 = 10.0;

  /// Touches du pavé numérique, tuiles de ledger, boutons translucides.
  static const r11 = 11.0;

  /// Tuiles de métriques, cartes de liste.
  static const r13 = 13.0;

  /// Cartes secondaires, toast.
  static const r14 = 14.0;

  /// Carte solde, zone de dépôt.
  static const r18 = 18.0;

  /// Angles hauts d'un bottom sheet.
  static const sheet = 22.0;
}

/// Ombres de la maquette (`--shadow-*`). `shadow-phone` n'a pas de sens sur
/// mobile et n'est donc pas repris.
class AppShadows {
  const AppShadows._();

  /// `0 12px 30px rgba(0,0,0,.5)` : toast, éléments flottants.
  static const card = [
    BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12)),
  ];

  /// `0 8px 20px rgba(196,24,63,.45)` : bouton central « Publier ».
  static const fab = [
    BoxShadow(color: Color(0x73C4183F), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

class AppGradients {
  const AppGradients._();

  static const appBackground = RadialGradient(
    center: Alignment(-0.6, -1.05),
    radius: 1.65,
    colors: [AppColors.brand950, AppColors.bgApp],
    stops: [0, 0.6],
  );

  /// `linear-gradient(135deg,#2A0E1F 0%,#5C1330 50%,#C4183F 130%)`.
  ///
  /// Flutter ne sait pas dépasser 100 % : la couleur finale est donc la valeur
  /// de la maquette à 100 % (interpolation brand800 -> brand500 à 62,5 %,
  /// soit #9D1639), et non brand500 pur qui serait plus saturé dans le coin.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand900, AppColors.brand800, Color(0xFF9D1639)],
    stops: [0, 0.5, 1],
  );

  /// Avatar à initiales : `#5C1330 -> #C4183F`.
  static const avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand800, AppColors.brand500],
  );

  static const brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand900, AppColors.brand700],
  );

  static const cta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.brand600, AppColors.accent500],
  );

  /// Bouton central « Publier » : `linear-gradient(140deg,#C4183F,#F5A623)`.
  /// Les extrémités (±0.906, ±1.079) reproduisent la ligne de dégradé CSS à
  /// 140° pour une boîte carrée.
  static const ctaFab = LinearGradient(
    begin: Alignment(-0.906, -1.079),
    end: Alignment(0.906, 1.079),
    colors: [AppColors.brand500, AppColors.accent500],
  );
}

/// Noms de familles de polices.
///
/// ATTENTION : `TextStyle(fontFamily: AppFonts.display)` (ou `'Sora'` brut) NE
/// FONCTIONNE PAS. Le package `google_fonts` enregistre ses familles sous des
/// noms internes (`Sora_700`, `Inter_regular`...) et `pubspec.yaml` ne déclare
/// aucune police embarquée : Flutter retombe silencieusement sur la police
/// système. Utiliser à la place `AppTextStyles.display(...)`,
/// `AppTextStyles.bodyText(...)` ou l'un des styles prédéfinis (`title`,
/// `heading`, `body`...), qui passent par `GoogleFonts.sora` / `GoogleFonts.inter`.
/// Ces constantes restent exposées uniquement pour compatibilité (les écrans
/// existants seront migrés plus tard) ; seule `mono` est utilisable telle quelle.
class AppFonts {
  const AppFonts._();

  /// Ne pas utiliser dans `TextStyle.fontFamily` (voir ci-dessus).
  static const display = 'Sora';

  /// Ne pas utiliser dans `TextStyle.fontFamily` (voir ci-dessus).
  static const body = 'Inter';
  static const mono = 'monospace';
}

class AppTextStyles {
  const AppTextStyles._();

  /// Style Sora (titres, montants, libellés de boutons) résolu par
  /// `google_fonts`. Préférer ceci à `fontFamily: AppFonts.display`.
  static TextStyle display({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.sora(
      fontSize: size ?? 16,
      fontWeight: weight ?? FontWeight.w700,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? 0,
    );
  }

  /// Style Inter (texte courant) résolu par `google_fonts`.
  static TextStyle bodyText({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size ?? 14,
      fontWeight: weight ?? FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? 0,
    );
  }

  static TextStyle displayLg = GoogleFonts.sora(
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static TextStyle displayMd = GoogleFonts.sora(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static TextStyle title = GoogleFonts.sora(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle heading = GoogleFonts.sora(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle label = GoogleFonts.inter(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle micro = GoogleFonts.inter(
    fontSize: 10,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // --- Tailles récurrentes de la maquette, hors échelle de base ---

  /// Titre d'écran principal (Mon contenu, Portefeuille, Profil) : Sora 700 22.
  static TextStyle screenTitle = GoogleFonts.sora(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Titre de sous-écran / d'en-tête avec retour : Sora 700 17.
  static TextStyle appBarTitle = GoogleFonts.sora(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Titre des écrans d'authentification : Sora 700 24/32.
  static TextStyle authTitle = GoogleFonts.sora(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Titre de feuille / modale : Sora 700 18.
  static TextStyle sheetTitle = GoogleFonts.sora(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Libellé de bouton : Sora 700 15.
  static TextStyle buttonLabel = GoogleFonts.sora(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Valeur d'une tuile de statistique : Sora 800 22.
  static TextStyle statValue = GoogleFonts.sora(
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// Montant mis en avant (solde, retrait) : Sora 800 30.
  static TextStyle amountXl = GoogleFonts.sora(
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// Pourcentage d'upload géant : Sora 800 44.
  static TextStyle amountDisplay = GoogleFonts.sora(
    fontSize: 44,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// Texte courant compact : Inter 400 12.5.
  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 12.5,
    height: 19 / 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Libellé de champ : Inter 500 11.
  static TextStyle fieldLabel = GoogleFonts.inter(
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  /// Étiquette de section en capitales : Inter 600 10.5, interlettrage .08em.
  static TextStyle sectionLabel = GoogleFonts.inter(
    fontSize: 10.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.84,
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgApp,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent500,
        secondary: AppColors.brand500,
        surface: AppColors.surface1,
        error: AppColors.danger,
        onPrimary: AppColors.textInverse,
        onSecondary: AppColors.text1,
        onSurface: AppColors.text1,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.displayLg.copyWith(color: AppColors.text1),
        displayMedium: AppTextStyles.displayMd.copyWith(color: AppColors.text1),
        titleLarge: AppTextStyles.title.copyWith(color: AppColors.text1),
        titleMedium: AppTextStyles.heading.copyWith(color: AppColors.text1),
        bodyLarge: AppTextStyles.body.copyWith(color: AppColors.text1),
        bodyMedium: AppTextStyles.body.copyWith(color: AppColors.text2),
        labelLarge: AppTextStyles.label.copyWith(color: AppColors.text1),
        labelSmall: AppTextStyles.micro.copyWith(color: AppColors.text3),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent500,
        selectionColor: Color(0x4DF5A623),
        selectionHandleColor: AppColors.accent500,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface3,
        contentTextStyle: AppTextStyles.bodyText(
          size: 12.5,
          color: AppColors.text1,
          height: 17 / 12.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.r14),
          side: const BorderSide(color: AppColors.border1),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1,
        modalBackgroundColor: AppColors.surface1,
        modalBarrierColor: AppColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border1,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
