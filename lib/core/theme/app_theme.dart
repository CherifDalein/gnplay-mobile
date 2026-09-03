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
}

class AppGradients {
  const AppGradients._();

  static const appBackground = RadialGradient(
    center: Alignment(-0.6, -1.05),
    radius: 1.65,
    colors: [AppColors.brand950, AppColors.bgApp],
    stops: [0, 0.6],
  );

  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand900, AppColors.brand800, AppColors.brand500],
    stops: [0, 0.5, 1],
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
}

class AppFonts {
  const AppFonts._();

  static const display = 'Sora';
  static const body = 'Inter';
  static const mono = 'monospace';
}

class AppTextStyles {
  const AppTextStyles._();

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
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
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
      dividerTheme: const DividerThemeData(
        color: AppColors.border1,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
