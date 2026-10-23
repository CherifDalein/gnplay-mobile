import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';

/// Coque commune des écrans d'authentification : fond, colonne de 430 px au
/// plus, défilement (clavier ouvert, petits écrans) et fermeture du clavier
/// au glissement.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.centered = false,
    this.topPadding = 12,
  });

  final List<Widget> children;

  /// Centre le contenu verticalement quand il est plus court que l'écran.
  final bool centered;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: GnAppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vertical = topPadding + 32;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(26, topPadding, 26, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - vertical,
                  ),
                  child: Align(
                    alignment: centered
                        ? Alignment.center
                        : Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: children,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Titre (Sora 24) et sous-titre d'un écran d'authentification.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, this.subtitle});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTextStyles.authTitle.copyWith(color: AppColors.text1),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: AppTextStyles.label.copyWith(
              color: AppColors.text3,
              fontWeight: FontWeight.w400,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}

/// Lien-texte d'au moins 44 px de haut.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.text2,
    this.alignment = Alignment.center,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: AppColors.text4,
        minimumSize: const Size(44, 44),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.label.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
