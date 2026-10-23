import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_back_button.dart';

/// En-tête d'écran : retour optionnel, titre (Sora 700 17), sous-titre
/// optionnel et actions à droite.
///
/// ```dart
/// GnScreenHeader(
///   title: 'Appareils connectés',
///   subtitle: '2/3 appareils actifs',
///   actions: [IconButton(...)],
/// )
/// ```
class GnScreenHeader extends StatelessWidget {
  const GnScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.padding = EdgeInsets.zero,
  });

  /// Titre de l'écran (une ligne, tronqué au besoin).
  final String title;

  /// Sous-titre discret sous le titre.
  final String? subtitle;

  /// Affiche le bouton retour (par défaut oui).
  final bool showBack;

  /// Action du bouton retour ; par défaut `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Widgets alignés à droite (boutons d'action).
  final List<Widget> actions;

  /// Marge intérieure de l'en-tête.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GnBackButton.hitSize),
        child: Row(
          children: [
            if (showBack) ...[
              GnBackButton(onPressed: onBack, alignment: Alignment.centerLeft),
              const SizedBox(width: AppSpacing.x1),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.appBarTitle.copyWith(
                        color: AppColors.text1,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.x2),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}
