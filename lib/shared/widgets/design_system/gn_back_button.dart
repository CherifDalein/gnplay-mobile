import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_line_icon.dart';

/// Bouton retour partagé (flèche de la maquette, trait 2, `text2`).
///
/// Zone tactile de 44x44 px minimum, annoncée « Retour » aux lecteurs d'écran.
/// Sans [onPressed], revient à l'écran précédent (`Navigator.maybePop`).
class GnBackButton extends StatelessWidget {
  const GnBackButton({
    super.key,
    this.onPressed,
    this.color = AppColors.text2,
    this.semanticLabel = 'Retour',
    this.alignment = Alignment.center,
  });

  /// Taille de la zone tactile.
  static const double hitSize = 44;

  /// Action au toucher ; par défaut `Navigator.maybePop(context)`.
  final VoidCallback? onPressed;

  /// Couleur de la flèche.
  final Color color;

  /// Libellé d'accessibilité.
  final String semanticLabel;

  /// Position de la flèche dans la zone tactile (`centerLeft` pour l'aligner
  /// au bord gauche du contenu, comme dans la maquette).
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: () => _handleTap(context),
      child: InkResponse(
        onTap: () => _handleTap(context),
        radius: hitSize / 2,
        child: SizedBox(
          width: hitSize,
          height: hitSize,
          child: Align(
            alignment: alignment,
            child: GnLineIcon(
              GnLineIconData.back,
              size: 20,
              color: color,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final callback = onPressed;
    if (callback != null) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }
}
